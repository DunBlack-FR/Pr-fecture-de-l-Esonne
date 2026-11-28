-- Supabase schema for the roleplay application. Apply in a new/test Supabase project first.
-- This is roleplay data only; no public-service identity or employment is verified.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
do $$ begin create type public.dossier_status as enum ('draft','active'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'viewer' check (role in ('viewer','admin')),
  account_type text not null default 'citizen' check (account_type in ('citizen','professional','justice_professional','state_service','company','service_hr')),
  first_name text, last_name text, birth_date text, discord_handle text,
  state_service text, declared_identifier text, justice_profession text,
  professional_department text, company_name text, company_position text, company_number text, company_sector text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists account_type text not null default 'citizen';
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists birth_date text;
alter table public.profiles add column if not exists discord_handle text;
alter table public.profiles add column if not exists state_service text;
alter table public.profiles add column if not exists declared_identifier text;
alter table public.profiles add column if not exists justice_profession text;
alter table public.profiles add column if not exists professional_department text;
alter table public.profiles add column if not exists company_name text;
alter table public.profiles add column if not exists company_position text;
alter table public.profiles add column if not exists company_number text;
alter table public.profiles add column if not exists company_sector text;

alter table public.profiles drop constraint if exists profiles_account_type_check;
alter table public.profiles add constraint profiles_account_type_check check (account_type in ('citizen','professional','justice_professional','state_service','company','service_hr'));

create table if not exists public.services (
  id text primary key check (id in ('gendarmerie','police_nationale','sapeurs_pompiers','samu')),
  label text not null unique
);
-- Normalize service keys to lowercase; service labels describe fictional roleplay areas.
insert into public.services(id,label) values
 ('gendarmerie','Gendarmerie'),('police_nationale','Police Nationale'),
 ('sapeurs_pompiers','Sapeurs-Pompiers'),('samu','SAMU')
on conflict(id) do update set label=excluded.label;
-- Correct the mixed-case legacy check expression above for all supported rows.
alter table public.services drop constraint if exists services_id_check;
alter table public.services add constraint services_id_check check (id in ('gendarmerie','police_nationale','sapeurs_pompiers','samu'));

create table if not exists public.service_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  service_id text not null references public.services(id) on delete cascade,
  role_key text not null check (role_key in ('service_member','service_hr_manager','service_admin')),
  created_at timestamptz not null default now(),
  granted_by uuid references auth.users(id) on delete set null,
  primary key(user_id,service_id,role_key)
);
create index if not exists service_roles_user_idx on public.service_roles(user_id);

-- One-time invitation credentials are stored only as SHA-256 hashes.
create table if not exists public.service_invites (
  token_hash bytea primary key,
  service_id text not null references public.services(id) on delete cascade,
  role_key text not null check (role_key='service_hr_manager'),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

create table if not exists public.personnel_members (
  id uuid primary key default gen_random_uuid(),
  service_id text not null references public.services(id),
  first_name text not null check (char_length(trim(first_name)) between 1 and 100),
  last_name text not null check (char_length(trim(last_name)) between 1 and 100),
  joined_on date not null,
  rank_name text not null check (char_length(trim(rank_name)) between 1 and 120),
  identifier text not null check (char_length(trim(identifier)) between 1 and 120),
  contact_email text not null,
  linked_user_id uuid unique references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(service_id,identifier)
);
create unique index if not exists personnel_members_email_lower_uq on public.personnel_members(lower(contact_email));
create index if not exists personnel_members_service_idx on public.personnel_members(service_id);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(), name text not null unique check (char_length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now(), created_by uuid references auth.users(id) on delete set null
);
create table if not exists public.dossiers (
  id uuid primary key default gen_random_uuid(), title text not null check (char_length(trim(title)) between 1 and 180),
  description text, category_id uuid references public.categories(id) on delete restrict,
  status public.dossier_status not null default 'draft', archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(), dossier_id uuid not null references public.dossiers(id) on delete cascade,
  file_name text not null check (char_length(file_name) between 1 and 255), storage_path text not null unique,
  mime_type text, size_bytes bigint not null default 0 check (size_bytes>=0), archived_at timestamptz,
  uploaded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create index if not exists dossiers_category_idx on public.dossiers(category_id);
create index if not exists dossiers_updated_idx on public.dossiers(updated_at desc);
create index if not exists documents_dossier_idx on public.documents(dossier_id);

create or replace function public.touch_updated_at() returns trigger language plpgsql set search_path=public as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists dossiers_touch_updated_at on public.dossiers;
create trigger dossiers_touch_updated_at before update on public.dossiers for each row execute function public.touch_updated_at();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')
$$;
create or replace function public.has_service_role(p_service text,p_role text) returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select exists(select 1 from public.service_roles r where r.user_id=(select auth.uid()) and r.service_id=p_service and r.role_key=p_role)
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.has_service_role(text,text) from public;
grant execute on function public.has_service_role(text,text) to authenticated;

-- Auth metadata is user-submitted declaration only. Privileged roles never come from it.
create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare m jsonb:=coalesce(new.raw_user_meta_data,'{}'::jsonb); v_service text;
begin
  v_service:=nullif(m->>'state_service','');
  if not exists(select 1 from public.services where id=v_service) then v_service:=null; end if;
  insert into public.profiles(id,email,role,account_type,first_name,last_name,birth_date,discord_handle,state_service,declared_identifier,justice_profession,professional_department,company_name,company_position,company_number,company_sector)
  values(new.id,new.email,'viewer',
    case when m->>'account_type' in ('citizen','professional','justice_professional','state_service','company','service_hr') then m->>'account_type' else 'citizen' end,
    nullif(left(trim(m->>'first_name'),100),''),nullif(left(trim(m->>'last_name'),100),''),
    case when coalesce(m->>'birth_date','') ~ '^\d{4}-\d{2}-\d{2}$' then m->>'birth_date' else null end,
    nullif(left(trim(m->>'discord_handle'),100),''),v_service,
    nullif(left(trim(m->>'declared_identifier'),120),''),nullif(left(trim(m->>'justice_profession'),80),''),
    case when m->>'account_type'='professional' and m->>'professional_department'='prefecture' then 'prefecture' else null end,
    nullif(left(trim(m->>'company_name'),160),''),nullif(left(trim(m->>'company_position'),120),''),
    nullif(left(trim(m->>'company_number'),80),''),nullif(left(trim(m->>'company_sector'),160),''))
  on conflict(id) do update set email=excluded.email;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.on_auth_user_created();

-- Redeem a one-time invitation after email confirmation/sign-in. The client may submit a token,
-- but the server matches its hash, expiry, and one-time state before assigning scoped RH access.
create or replace function public.redeem_service_invite(p_token text) returns text
language plpgsql security definer set search_path=public,extensions,auth,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_email text; v_profile public.profiles%rowtype; v_inv public.service_invites%rowtype;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if p_token is null or length(p_token)<24 or length(p_token)>256 then raise exception 'Invalid invitation'; end if;
 select email into v_email from auth.users where id=v_uid and email_confirmed_at is not null;
 if v_email is null then raise exception 'Confirmed email required'; end if;
 select * into v_profile from public.profiles where id=v_uid;
 if v_profile.account_type is distinct from 'service_hr' or v_profile.state_service is null then raise exception 'RH account declaration required'; end if;
 select * into v_inv from public.service_invites where token_hash=digest(p_token,'sha256') for update;
 if not found or v_inv.used_at is not null or v_inv.expires_at<=now() or v_inv.service_id<>v_profile.state_service then raise exception 'Invitation invalid or expired'; end if;
 update public.service_invites set used_at=now() where token_hash=v_inv.token_hash;
 insert into public.service_roles(user_id,service_id,role_key,granted_by) values(v_uid,v_inv.service_id,v_inv.role_key,null) on conflict do nothing;
 return v_inv.service_id;
end $$;
revoke all on function public.redeem_service_invite(text) from public;
grant execute on function public.redeem_service_invite(text) to authenticated;
alter function public.redeem_service_invite(text) owner to postgres;

-- HR can create a roster record only for its own service; insertions happen through this RPC.
create or replace function public.create_service_member(p_service text,p_first text,p_last text,p_joined date,p_rank text,p_identifier text,p_email text) returns uuid
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare v_id uuid; v_email text:=lower(trim(p_email));
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not public.is_admin() and not (public.has_service_role(p_service,'service_hr_manager') or public.has_service_role(p_service,'service_admin')) then raise exception 'Service permission denied'; end if;
 if p_service not in ('gendarmerie','police_nationale','sapeurs_pompiers','samu') then raise exception 'Unknown service'; end if;
 if nullif(trim(p_first),'') is null or nullif(trim(p_last),'') is null or nullif(trim(p_rank),'') is null or nullif(trim(p_identifier),'') is null then raise exception 'Required roster fields missing'; end if;
 if p_joined is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Invalid date or email'; end if;
 insert into public.personnel_members(service_id,first_name,last_name,joined_on,rank_name,identifier,contact_email,created_by)
 values(p_service,left(trim(p_first),100),left(trim(p_last),100),p_joined,left(trim(p_rank),120),left(trim(p_identifier),120),v_email,auth.uid()) returning id into v_id;
 -- Link immediately only when the matching account email is already confirmed.
 update public.personnel_members pm set linked_user_id=u.id
 from auth.users u where pm.id=v_id and lower(u.email)=v_email and u.email_confirmed_at is not null and pm.linked_user_id is null;
 if exists(select 1 from public.personnel_members where id=v_id and linked_user_id is not null) then
   insert into public.service_roles(user_id,service_id,role_key,granted_by)
   select linked_user_id,service_id,'service_member',auth.uid() from public.personnel_members where id=v_id on conflict do nothing;
 end if;
 return v_id;
end $$;
revoke all on function public.create_service_member(text,text,text,date,text,text,text) from public;
grant execute on function public.create_service_member(text,text,text,date,text,text,text) to authenticated;
alter function public.create_service_member(text,text,text,date,text,text,text) owner to postgres;

-- Link an existing roster entry when the person later confirms the matching email.
create or replace function public.link_confirmed_member() returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare r record;
begin
 if new.email_confirmed_at is null then return new; end if;
 if tg_op='UPDATE' then
   if old.email_confirmed_at is not null and old.email_confirmed_at=new.email_confirmed_at then return new; end if;
 end if;
 for r in select id,service_id from public.personnel_members where lower(contact_email)=lower(new.email) and linked_user_id is null order by created_at limit 1 for update loop
   update public.personnel_members set linked_user_id=new.id where id=r.id and linked_user_id is null;
   if found then insert into public.service_roles(user_id,service_id,role_key) values(new.id,r.service_id,'service_member') on conflict do nothing; end if;
 end loop;
 return new;
end $$;
drop trigger if exists auth_user_email_confirmed_link on auth.users;
create trigger auth_user_email_confirmed_link after update of email_confirmed_at on auth.users for each row execute function public.link_confirmed_member();
drop trigger if exists auth_user_created_link_member on auth.users;
create trigger auth_user_created_link_member after insert on auth.users for each row execute function public.link_confirmed_member();
revoke all on function public.link_confirmed_member() from public,anon,authenticated;

alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.service_roles enable row level security;
alter table public.service_invites enable row level security;
alter table public.personnel_members enable row level security;
alter table public.categories enable row level security;
alter table public.dossiers enable row level security;
alter table public.documents enable row level security;

drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated using (id=(select auth.uid()) or (select public.is_admin()));
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists services_read_authenticated on public.services;
create policy services_read_authenticated on public.services for select to authenticated using (true);
drop policy if exists service_roles_read_self_or_admin on public.service_roles;
create policy service_roles_read_self_or_admin on public.service_roles for select to authenticated using (user_id=(select auth.uid()) or (select public.is_admin()));
drop policy if exists members_read_scoped on public.personnel_members;
create policy members_read_scoped on public.personnel_members for select to authenticated using ((select public.is_admin()) or (select public.has_service_role(service_id,'service_hr_manager')) or (select public.has_service_role(service_id,'service_admin')) or linked_user_id=(select auth.uid()));
drop policy if exists categories_admin_all on public.categories;
create policy categories_admin_all on public.categories for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists dossiers_admin_all on public.dossiers;
create policy dossiers_admin_all on public.dossiers for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists documents_admin_all on public.documents;
create policy documents_admin_all on public.documents for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

revoke all on public.profiles,public.services,public.service_roles,public.service_invites,public.personnel_members from anon,authenticated;
grant select on public.profiles,public.services,public.service_roles,public.personnel_members to authenticated;
grant update on public.profiles to authenticated;
grant select,insert,update,delete on public.categories,public.dossiers,public.documents to authenticated;
-- Private bucket; Storage operations remain restricted to global administrators.
insert into storage.buckets(id,name,public,file_size_limit) values('documentation','documentation',false,26214400)
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit;
drop policy if exists documentation_admin_select on storage.objects;
create policy documentation_admin_select on storage.objects for select to authenticated using (bucket_id='documentation' and (select public.is_admin()));
drop policy if exists documentation_admin_insert on storage.objects;
create policy documentation_admin_insert on storage.objects for insert to authenticated with check (bucket_id='documentation' and (select public.is_admin()));
drop policy if exists documentation_admin_update on storage.objects;
create policy documentation_admin_update on storage.objects for update to authenticated using (bucket_id='documentation' and (select public.is_admin())) with check (bucket_id='documentation' and (select public.is_admin()));
drop policy if exists documentation_admin_delete on storage.objects;
create policy documentation_admin_delete on storage.objects for delete to authenticated using (bucket_id='documentation' and (select public.is_admin()));
commit;

-- TRUSTED INITIALIZATION (run as project owner after choosing a one-time token of at least 24 random chars):
-- insert into public.service_invites(token_hash,service_id,role_key,expires_at)
-- values(digest('REPLACE_WITH_RANDOM_ONE_TIME_TOKEN','sha256'),'gendarmerie','service_hr_manager',now()+interval '7 days');
-- Give global admin only through a trusted SQL session, never through signup metadata/client input:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='admin@example.test');
-- Do not use real-world records: this application is for roleplay only.

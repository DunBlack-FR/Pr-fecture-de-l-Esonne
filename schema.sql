-- Tribunal de Paris — schéma privé dossiers/documentation pour Supabase
-- Exécuter dans Supabase SQL Editor après création du projet.
begin;
create extension if not exists pgcrypto;
do $$ begin create type public.dossier_status as enum ('draft','active'); exception when duplicate_object then null; end $$;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'viewer' check (role in ('viewer','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
create table if not exists public.dossiers (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 180),
  description text,
  category_id uuid references public.categories(id) on delete restrict,
  status public.dossier_status not null default 'draft',
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  dossier_id uuid not null references public.dossiers(id) on delete cascade,
  file_name text not null check (char_length(file_name) between 1 and 255),
  storage_path text not null unique,
  mime_type text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  archived_at timestamptz,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists dossiers_category_idx on public.dossiers(category_id);
create index if not exists dossiers_updated_idx on public.dossiers(updated_at desc);
create index if not exists documents_dossier_idx on public.documents(dossier_id);
create or replace function public.touch_updated_at() returns trigger language plpgsql set search_path=public as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists dossiers_touch_updated_at on public.dossiers;
create trigger dossiers_touch_updated_at before update on public.dossiers for each row execute function public.touch_updated_at();
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public,auth as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin') $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path=public,auth as $$ begin insert into public.profiles(id,email,role) values(new.id,new.email,'viewer') on conflict(id) do update set email=excluded.email; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.on_auth_user_created();
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.dossiers enable row level security;
alter table public.documents enable row level security;
drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated using (id=(select auth.uid()) or (select public.is_admin()));
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists categories_admin_all on public.categories;
create policy categories_admin_all on public.categories for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists dossiers_admin_all on public.dossiers;
create policy dossiers_admin_all on public.dossiers for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists documents_admin_all on public.documents;
create policy documents_admin_all on public.documents for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.categories,public.dossiers,public.documents to authenticated;
-- Bucket privé; limite de taille réglée à 25 Mo. Adapter les MIME autorisés à la politique documentaire.
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
-- Promotion de l'administrateur initial, à exécuter une fois après création de son utilisateur Auth :
-- update public.profiles set role='admin' where id=(select id from auth.users where email='votre.adresse@exemple.fr');

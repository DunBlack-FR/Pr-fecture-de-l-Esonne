# Déploiement — application statique de jeu de rôle avec Supabase

## Périmètre et limites

Cette application est un site de **jeu de rôle**, sans lien d’authentification ou de vérification avec les services publics. Nom, date, service, identifiant, grade et RH sont des déclarations destinées au jeu : aucune identité, fonction, matricule ou appartenance réelle n’est validée. N’intégrez pas de vraies données personnelles, dossiers, procédures, secrets opérationnels ni documents réels. Le dépôt statique n’est pas adapté aux données judiciaires ou RH réelles.

La page `connexion.html` propose les types Citoyen, Professionnel (Préfecture), Services de l’État (Gendarmerie, Police Nationale, Sapeurs-Pompiers, SAMU) et Entreprise. Elle crée un compte Supabase Auth et transmet les champs de profil déclaratifs dans les user metadata. Le code `PREFECTURE-RP` est un contrôle de démonstration hardcodé côté navigateur, public et contournable : il n’est jamais persisté et ne donne aucun rôle, privilège ni preuve; ne le traitez pas comme un mécanisme d’accès. Un trigger SQL les copie à `public.profiles`; le rôle global est toujours forcé à `viewer`. Les profils déclarés RH n’obtiennent aucun droit d’office. La promotion RH est un jeton d’invitation unique, expirant et vérifié par la fonction SQL `redeem_service_invite`; seul son hash est conservé. Les RH sont limités à un service. Un responsable autorisé peut créer un effectif via RPC, qui lie automatiquement un compte déjà confirmé avec la même adresse courriel; si le compte est créé ou confirmé plus tard, le trigger SQL le lie automatiquement. Les identifiants déclarés ne sont jamais utilisés comme preuve d’identité ou comme clé de liaison.

## Installation de Supabase

1. Créez un projet Supabase (test d’abord). Activez l’authentification Email, configurez l’expéditeur, les confirmations, les exigences de mot de passe et les URL Site URL / Redirect URLs, notamment l’URL GitHub Pages et son chemin de dépôt se terminant par `connexion.html`.
2. Dans SQL Editor, appliquez intégralement `schema.sql` avec le rôle propriétaire du projet. Il crée/complète `profiles`, la liste normalisée `services`, les rôles par service, invitations à usage unique, roster `personnel_members`, RPCs, triggers, RLS et le bucket privé existant.
3. Configurez `supabase-config.js` avec Project URL et clé publique `anon`/publishable **du même projet**. Ces valeurs sont destinées au navigateur. N’y mettez jamais `service_role`, `sb_secret`, ou tout autre secret.
4. Créez un compte d’administrateur global puis attribuez `role='admin'` uniquement en SQL Editor fiable, selon le commentaire en bas de `schema.sql`. Cette attribution n’est jamais une action de la page Web.
5. Pour l’accès RH initial d’un service, générez hors ligne un jeton aléatoire long (au moins 24 caractères aléatoires, 32+ recommandés). Fournissez-le directement et de manière confidentielle à la personne choisie. En SQL Editor propriétaire, ajoutez une invitation en remplaçant le jeton et service dans le modèle commenté de `schema.sql`; utilisez une durée courte. Le serveur conserve `SHA-256(token)`, jamais le jeton clair. N’ajoutez pas ce jeton au site, dépôt, tickets ou URL.
6. La personne crée un compte avec type `RH d’un service`, déclare exactement le service de l’invitation, confirme son adresse, se connecte et saisit le jeton dans l’espace connecté. Une invitation n’est valable qu’une fois, jusqu’à expiration, et uniquement pour un compte email confirmé déclarant le service prévu. Il s’agit d’une autorisation de jeu de rôle, pas d’une validation officielle.
7. Publiez tous les fichiers du site statique sur GitHub Pages en HTTPS. Le module Supabase JS est chargé depuis `esm.sh`; ce CDN et le réseau doivent être disponibles. Conservez le chemin `supabase-config.js` attendu à la racine du site.

## Fonctionnalités

- Connexion, inscription, confirmation courriel, récupération et changement de mot de passe via Supabase Auth.
- Champs profil persistés dans `profiles`: prénom, nom, date de naissance, identifiant Discord, type de compte déclaré; service et identifiant déclarés (NIGEND/matricule uniquement à titre fictif), rubrique professionnelle Préfecture et entreprise/poste selon le choix. Le code de démonstration Préfecture est exclu des métadonnées et du profil. `profiles` permet à l’utilisateur de lire son propre profil; l’update direct est réservé au rôle administrateur global.
- `redeem_service_invite(text)` vérifie côté SQL le jeton haché, l’expiration, l’usage unique, la session, la confirmation email et la correspondance entre service déclaré et invitation avant de créer le rôle `service_hr_manager` scoped.
- `create_service_member(...)` contrôle côté serveur une permission `service_hr_manager` / `service_admin` du service visé (ou admin global), crée les données et lie un compte Auth confirmé par courriel si présent. Une confirmation ultérieure déclenche aussi le lien. La vue de roster est limitée à ses RH de service, admin global, et le membre lié.
- La page montre la partie RH seulement si la table `service_roles` confirme le rôle et le service. C’est une commodité d’interface; RPC et RLS sont l’autorité réelle.
- Interface admin existante, catégories/dossiers/documents et bucket Storage demeurent réservés au rôle global `admin` via RLS. RH de service n’obtient pas l’accès aux dossiers globaux.

## Vérifications avant mise en ligne

- Appliquer le SQL sur un projet de test et traiter toute erreur de migration avant production.
- Tester signup des quatre types de compte avec confirmation email activée et désactivée, champs persistés et profil `viewer`; vérifier que le code RP `PREFECTURE-RP` est seulement un garde-fou d’interface, qu’un code erroné est refusé dans la page, qu’un appel Auth direct n’acquiert aucun privilège, et que ce code n’est présent ni dans user metadata ni dans `profiles`; refus d’un `account_type=service_hr` sans jeton, invitation invalide/expirée/déjà utilisée/service différent, invitation valide, impossibilité de lire un autre service, et refus d’appel RPC sans rôle adéquat.
- Vérifier liens automatiques roster avec compte confirmé existant puis avec inscription ultérieure et confirmation après inscription; s’assurer qu’un email différent ne lie rien.
- Tester séparément le rôle global admin et le refus d’accès à l’interface globale par un viewer/RH.
- Configurer les limites Supabase Auth, quotas email, sauvegarde et surveillance. Les contrôles locaux ne remplacent pas un test du projet distant.

## Hypothèses / limitations fonctionnelles

- Liste initiale des services de jeu : Gendarmerie, Police Nationale, Sapeurs-Pompiers, SAMU, identifiants normalisés en `gendarmerie`, `police_nationale`, `sapeurs_pompiers`, `samu`.
- Un compte est lié par correspondance exacte insensible à la casse de l’adresse email confirmée que le RH a saisie au roster. L’adresse email n’est pas une preuve d’identité réelle. En cas d’adresse modifiée après liaison, aucune reliaison automatique n’est faite.
- L’UI RH fournie couvre le roster (lecture/création), pas le workflow de grades/promotion complet de l’ancien prototype, ni l’administration de jetons. Les jetons et changements de rôle passent par le canal SQL propriétaire.
- Aucune migration distante, configuration de projet, invitation réelle, mail ou test navigateur distant n’a été effectué dans ce travail. La clé Supabase du dépôt demeure fictive jusqu’à configuration.

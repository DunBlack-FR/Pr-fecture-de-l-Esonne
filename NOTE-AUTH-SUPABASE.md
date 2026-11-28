# Correctif comptes et habilitations Supabase

`connexion.html` transmet les champs déclaratifs saisis à l’inscription; `schema.sql` crée/actualise le profil et force tout nouveau compte au rôle global `viewer`. Sélectionner RH dans l’interface ne confère donc rien.

Les rôles RH sont accordés uniquement par `redeem_service_invite()` côté SQL. Le jeton est à usage unique, expirant, conservé sous forme hashée, réservé à une adresse email confirmée dont le profil RH déclare le service correspondant. Le roster RH est limité à ce service; les créations passent par une RPC validant l’habilitation. Une correspondance d’email confirmé lie automatiquement un compte présent ou futur à la fiche roster. Le détail de déploiement, les modèles SQL de provisionnement et les limites sont dans `SETUP.md`.

Aucun projet distant n’était configuré ou accessible ici. La clé publique dans `supabase-config.js` reste un placeholder; l’intégration devient active après application de `schema.sql` et configuration des valeurs publiques. Aucun secret/service_role ne doit être publié. Le site est réservé au jeu de rôle et ne vérifie pas d’identité ni de qualité officielle; n’utilisez pas de données réelles.


Inscription : les catégories et champs sont déclaratifs. Le code Préfecture `PREFECTURE-RP` est un simple garde-fou de démonstration côté navigateur, public et contournable; il n’est ni transmis à Supabase ni utilisé pour attribuer des droits. Aucun statut officiel ou identité n’est vérifié.

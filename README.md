# Tribunal de Paris — publication GitHub Pages

Ce dossier est publiable comme site statique. **`index.html` est à la racine** et les ressources attendues sont dans `assets/`.

## Publier

1. Dans le dépôt, la branche et le dossier réellement publiés (ou le dossier source/artifact utilisé par le workflow Pages), placez le contenu complet de ce dossier à la racine voulue, en conservant exactement les noms et la casse. Ne vous fiez pas à une autre copie locale ou au prototype HTML autonome.
2. Avant publication, modifiez le `supabase-config.js` à la racine publiée, au même niveau que `index.html` et `app.js`. Remplacez ses deux valeurs fictives par l’URL du projet Supabase et sa clé publique `anon` ou `publishable` correspondante. Ne mettez jamais de clé `service_role` ou secret dans un fichier web; ne partagez pas la clé publique non plus.
3. Faites un commit et un push vers la branche attendue. Dans **Settings → Pages**, confirmez la source (branche et dossier, ou workflow). Attendez **Actions/Deployments** et vérifiez que le workflow du dernier commit est réussi avant d’ouvrir l’URL affichée par GitHub.
4. Dans les outils développeur, onglet **Network/Réseau**, cochez **Disable cache**, rechargez sans cache et contrôlez les réponses de `index.html`, `app.js`, `supabase-config.js` et les assets. Inspectez localement la réponse de configuration sans en partager les valeurs. Pour un dépôt de projet, l’URL inclut le nom du dépôt; les chemins relatifs du site sont prévus pour ce préfixe.
5. Si vous choisissez plutôt `/docs`, il faut placer **tout le site** dans `/docs` et choisir ce dossier dans Pages. Ne publiez pas seulement le HTML sans CSS, scripts et `assets/`.

## À propos du 404

Dans l’état local vérifié, le point d’entrée existe bien sous le nom exact `index.html` à la racine. Les images étaient en revanche référencées sous `assets/` alors qu’elles étaient auparavant à la racine; elles ont été copiées dans `assets/` pour satisfaire ces références. Ce défaut aurait cassé les images, mais **n’explique pas à lui seul un 404 sur la page d’accueil**. Un 404 à l’URL Pages est donc plus probablement lié au dépôt/à la branche ou au répertoire de publication Pages, à l’absence de déploiement réussi, ou à une URL d’accès erronée. Je n’ai pas accès aux réglages distants du dépôt et ne peux pas les corriger ni confirmer la cause distante.

## Sécurité et limites

`supabase-config.js` dans le dossier publié contient actuellement des valeurs fictives. `app.js` importe ce fichier à la racine; les paramètres présents dans un ancien prototype HTML autonome ne s’appliquent pas à cette version. La page propose désormais création de compte, confirmation email, connexion, récupération, session et déconnexion. Remplacez dans CE fichier les deux valeurs par l’URL exacte du projet et sa clé publique anon/publishable correspondante, configurez Auth/URL autorisées et recréez l’archive avant publication. L’inscription publique doit être activée pour accepter les inscriptions; elle peut être désactivée si les comptes sont attribués uniquement par un administrateur. Les nouveaux profils reçoivent le rôle viewer, pas admin. L’authentification et l’administration ne fonctionneront pas avant une configuration valide et la préparation/validation serveur décrite dans `SETUP.md`. N’ajoutez jamais de clé `service_role` ni aucun secret au dépôt ou au navigateur. Cette maquette n’est pas un service officiel ou sécurisé : **n’y saisissez et n’y stockez aucune donnée judiciaire réelle** sans validation formelle de sécurité, protection des données, autorisations et procédures opérationnelles. GitHub Pages ne fournit que l’hébergement statique.

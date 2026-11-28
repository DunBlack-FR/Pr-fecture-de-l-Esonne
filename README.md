# Tribunal de Paris — publication GitHub Pages

Ce dossier est publiable comme site statique. **`index.html` est à la racine** et les ressources attendues sont dans `assets/`.

## Publier

1. Dans le dépôt, la branche et le dossier réellement publiés (ou le dossier source/artifact utilisé par le workflow Pages), placez le contenu complet de ce dossier à la racine voulue, en conservant exactement les noms et la casse. Ne vous fiez pas à une autre copie locale ou au prototype HTML autonome.
2. Avant publication, modifiez le `supabase-config.js` à la racine publiée, au même niveau que `index.html` et `app.js`. Remplacez ses deux valeurs fictives par l’URL du projet Supabase et sa clé publique `anon` ou `publishable` correspondante. N’incluez jamais de clé `service_role` ni aucun secret serveur dans un fichier web. La clé `anon`/`publishable` est publique par conception; utilisez celle du bon projet et fondez la protection sur Auth, RLS et les politiques Storage — jamais sur la confidentialité de cette clé.
3. Faites un commit et un push vers la branche attendue. Dans **Settings → Pages**, confirmez la source (branche et dossier, ou workflow). Attendez **Actions/Deployments** et vérifiez que le workflow du dernier commit est réussi avant d’ouvrir l’URL affichée par GitHub.
4. Dans les outils développeur, onglet **Network/Réseau**, cochez **Disable cache**, rechargez sans cache et contrôlez les réponses de `index.html`, `app.js`, `supabase-config.js` et les assets. Inspectez localement la réponse de configuration sans en partager les valeurs. Pour un dépôt de projet, l’URL inclut le nom du dépôt; les chemins relatifs du site sont prévus pour ce préfixe.
5. Si vous choisissez plutôt `/docs`, il faut placer **tout le site** dans `/docs` et choisir ce dossier dans Pages. Ne publiez pas seulement le HTML sans CSS, scripts et `assets/`.

## À propos du 404

Dans l’état local vérifié, le point d’entrée existe bien sous le nom exact `index.html` à la racine. Les images étaient en revanche référencées sous `assets/` alors qu’elles étaient auparavant à la racine; elles ont été copiées dans `assets/` pour satisfaire ces références. Ce défaut aurait cassé les images, mais **n’explique pas à lui seul un 404 sur la page d’accueil**. Un 404 à l’URL Pages est donc plus probablement lié au dépôt/à la branche ou au répertoire de publication Pages, à l’absence de déploiement réussi, ou à une URL d’accès erronée. Je n’ai pas accès aux réglages distants du dépôt et ne peux pas les corriger ni confirmer la cause distante.

## Comptes, autorisations et limites

Le flux d’inscription dans `connexion.html` distingue Citoyen, Professionnel (Préfecture), Services de l’État et Entreprise. Le code générique `PREFECTURE-RP` est explicitement une démo publique contrôlée dans le navigateur : il est contournable, non persisté et n’accorde aucun privilège. Les profils déclaratifs sont gérés dans `schema.sql`. Les demandes RH n’accordent pas de rôle automatiquement : une invitation à usage unique, expirante et stockée hashée doit être validée côté Supabase; les habilitations RH sont limitées par service. Les étapes précises, l’activation initiale de l’administrateur, le rapprochement automatique roster/email et les tests requis sont dans `SETUP.md`. Avant d’activer toute auth, configurez les valeurs publiques valides dans `supabase-config.js` et appliquez/révisez `schema.sql` (notamment avant d’utiliser le parcours `connexion.html`).

Le site est strictement une application de jeu de rôle : aucun statut officiel ou identité n’est vérifié. GitHub Pages n’est qu’un hébergement statique. Ne publiez jamais de clé service_role ou secret et ne saisissez aucune donnée réelle de tribunal, d’agent ou de dossier. Aucun projet distant n’a été configuré ni testé depuis cette copie.

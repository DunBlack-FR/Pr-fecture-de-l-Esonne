# Correctif authentification — note de publication

## Changements

- Ajout d’une inscription Supabase Auth avec validation de courriel/mot de passe, confirmation des deux saisies et possibilité de renvoyer le courriel de vérification.
- Connexion Supabase, état de session persistant/rafraîchi, lien de confirmation et récupération du mot de passe vers `index.html`, puis redirection de la connexion réussie vers `admin.html`.
- Affichage de messages d’erreur lisibles, gestion de la session ouverte et déconnexion. Les URL sont résolues relativement au répertoire de la page, y compris un site GitHub Pages dans un sous-répertoire.
- Le `supabase-config.js` existant a été conservé sans exposer ni remplacer ses valeurs. Il contient actuellement des valeurs fictives : elles ne permettent pas d’authentifier.

## Configuration Supabase requise

1. Dans `supabase-config.js`, renseigner l’URL HTTPS exacte du projet et sa clé publique `anon`/`publishable` correspondante. Aucun secret serveur ni `service_role` ne doit être publié.
2. Activer le fournisseur Auth par courriel et l’inscription si les comptes doivent pouvoir être créés depuis le site. Configurer le service d’envoi de courriels et les URL **Site URL / Redirect URLs** pour la racine du site publié (y compris le chemin du dépôt GitHub Pages) et l’environnement de test.
3. Appliquer `schema.sql`. Son déclencheur de création de profil donne le rôle `viewer` aux nouveaux comptes; seuls les profils auxquels un responsable attribue explicitement `admin` sont autorisés dans l’interface d’administration/RLS. L’inscription publique n’accorde pas de privilèges.
4. La page applique une longueur minimale de mot de passe de 8 caractères. Vérifier que les exigences Auth du projet ne sont pas plus strictes.

## Limites et tests

- Aucune valeur de configuration valide n’est disponible dans la copie locale vérifiée; aucune clé ou URL n’a été inventée, et aucun service/projet distant n’a été contacté ou modifié. L’inscription, la connexion, les courriels et le retour après confirmation ne peuvent donc pas être essayés contre Supabase.
- Contrôles locaux à effectuer avant publication : syntaxe JavaScript; intégrité et contenu de l’archive; structure des chemins de publication et recherche automatique de motifs de clés secrètes. Ces vérifications statiques ne remplacent pas un test navigateur de bout en bout.
- Tester en préproduction un compte nouvellement inscrit (confirmation activée), connexion après confirmation, réinitialisation, reconnexion persistante, déconnexion, refus du rôle `viewer` dans `admin.html`, puis accès autorisé à un compte explicitement `admin`.
- Le site est une application statique. Ne pas y saisir de données judiciaires réelles avant validation sécurité, confidentialité, politiques RLS et processus opérationnels.

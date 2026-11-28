# Mise en place — espace sécurisé Tribunal de Paris

## Livrables

- `index.html` + `site.css` + `app.js` : page d’accueil publique, visuelle et autonome. Elle réutilise le visuel du palais (`assets/palais-de-justice.webp`) ainsi que le logo fourni.
- `admin.html` + `admin.css` + `admin.js` : interface de gestion interne des catégories, dossiers et documents, dont l’archivage et le téléchargement temporaire.
- `schema.sql` : tables, bucket privé et politiques RLS Supabase.
- `supabase-config.js` : valeurs factices à remplacer avant d’activer le SDK. Ne contient aucun secret réel.
- `connexion.html` : redirection de compatibilité vers l’accueil; elle remplace l’ancien prototype à authentification locale. Aucun stockage local ne sert de contrôle d’accès.

## Prérequis Supabase (à effectuer avant usage)

1. Créez un projet Supabase de test/prod et activez **Authentication → Email**. Configurez les URL de redirection autorisées et le fournisseur d’envoi courriel selon vos règles. La page d’accueil expose maintenant une inscription par courriel si Supabase Auth l’autorise. Désactivez « Allow new users to sign up » dans Auth si vous ne souhaitez que des comptes créés par un administrateur. L’inscription publique attribue le rôle viewer par défaut et ne donne aucun droit admin.
2. Ouvrez le SQL Editor, appliquez `schema.sql`. Le schéma configure les tables et un bucket Storage **privé** `documentation`; RLS n’accorde lecture/écriture qu’aux profils admin.
3. Créez le premier utilisateur dans Supabase Auth. Dans SQL Editor, appliquez ensuite manuellement la dernière requête commentée du schéma, en remplaçant l’adresse de courriel. Vérifiez le rôle dans `public.profiles`. Les nouveaux utilisateurs reçoivent par défaut `viewer`, non admin.
4. Dans le `supabase-config.js` situé à la racine de CE site, remplacez les deux valeurs fictives par l’URL exacte du projet et sa **clé publique anon/publishable** correspondante. La page `index.html` charge `app.js`, qui importe précisément `./supabase-config.js` : des paramètres présents dans l’ancien prototype HTML autonome ne configurent pas ce build. Assurez-vous que l’URL et la clé correspondent au même projet. Après modification, republiez le dossier/ZIP modifié (ne réutilisez pas une archive qui contient encore les valeurs fictives). Ces valeurs client sont publiques par conception; la protection repose sur Auth et RLS. **N’insérez jamais de clé `service_role` ni aucun secret dans un fichier web, dépôt ou navigateur.**
5. Servez le répertoire avec un serveur HTTP(S) statique (pas `file://`). Par exemple `python3 -m http.server 8000`, puis utilisez `http://localhost:8000/`. En production, HTTPS est requis. Le CDN ESM `esm.sh` doit être joignable pour charger le client JS Supabase.
6. Testez la connexion admin, le refus d’un compte viewer, création/archivage d’un dossier, envoi/téléchargement de fichier et refus d’accès sans session. Contrôlez les journaux Supabase et les politiques Storage.

## Fonctionnalités / limites

- La fenêtre de l’accueil prend en charge l’inscription et la confirmation d’adresse par courriel (selon le paramétrage Auth), la connexion `signInWithPassword`, la réinitialisation/mise à jour du mot de passe et la déconnexion Supabase. La connexion réussie ouvre l’interface admin, qui vérifie séparément le rôle en base. L’espace d’administration vérifie le rôle dans `profiles`; les requêtes données/Storage sont de nouveau restreintes côté serveur par RLS.
- Tant que les paramètres restent fictifs, l’interface affiche une configuration manquante et ne prétend pas authentifier. Un site statique et le rôle UI ne sont pas une frontière de sécurité; le SQL/RLS est indispensable.
- Les documents sont stockés dans le bucket privé; téléchargement via URL signée courte. Limite UI et bucket: 25 Mo. Ajustez type MIME, limites et gestion du cycle de vie aux règles internes.
- L’archivage est logique : les dossiers restent en base, cachés dans la vue active; l’archivage documentaire masque le document sans effacer le fichier. Suppression d’un dossier supprime ses lignes et tente de supprimer son contenu Storage. Les sauvegardes, rétention, journaux d’audit et procédures d’effacement restent à définir pour déploiement.
- La page d’accueil conserve des liens externes officiels. Les actualités dynamiques et horaires sont volontairement omis ou renvoyés au site officiel afin de ne pas figer des informations possiblement obsolètes.
- `site.css` charge les polices Google Fonts en option; en cas d’indisponibilité, replis serif/sans-serif locaux. La page utilise des images locales issues des pièces de référence.

## Sécurité / mise en production

Aucun accès à un projet Supabase n’était fourni; aucune migration distante ni test d’authentification serveur n’a été exécuté. Faites relire `schema.sql` par le responsable sécurité/données et adaptez la politique au modèle d’accès réel avant d’y placer un dossier ou un document confidentiel. Les profils admin doivent être attribués par un canal de confiance; les fichiers et le contenu de dossiers peuvent relever de données sensibles, minimisez-les et définissez rétention, sauvegarde, journalisation et incidents. La configuration de démonstration n’est pas un service en production.

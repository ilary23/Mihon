# Installer le lecteur sur un iPhone depuis Windows

## La méthode

**GitHub Actions compile → fichier IPA non signé → Sideloadly signe → installation sur l’iPhone.**

Aucun Mac n’est nécessaire pour cette méthode : la compilation utilise un runner macOS GitHub. La signature reste effectuée avec ton compte Apple sur ton PC. Aucun jailbreak n’est requis selon la documentation de Sideloadly.

## 1. Récupérer le fichier IPA

1. Ouvre https://github.com/ilary23/Mihon/actions.
2. Ouvre une exécution réussie de **Build iPhone app** (coche verte).
3. En bas, télécharge l’artifact `MihonReader-build-…` ; connecte-toi à GitHub si nécessaire.
4. Décompresse le ZIP téléchargé.
5. Utilise **`MihonReader-UNSIGNED.ipa`**. Le ZIP simulateur ne peut pas fonctionner sur ton téléphone.

Les artifacts sont conservés 14 jours. Tu peux relancer le workflow avec **Run workflow**. Le fichier SHA-256 permet de vérifier le téléchargement : dans PowerShell, utilise `Get-FileHash .\MihonReader-UNSIGNED.ipa -Algorithm SHA256` puis compare avec le fichier `.sha256`.

## 2. Préparer Windows

Télécharge Sideloadly uniquement depuis son site officiel : **https://sideloadly.io/**.

La documentation officielle demande les versions web d’iTunes et d’iCloud pour Windows, pas les versions Microsoft Store. Suis les liens de la rubrique **Before you install** du site officiel pour obtenir les pilotes appropriés. Installe les composants nécessaires, puis redémarre le PC si demandé.

## 3. Signer et installer

1. Branche l’iPhone en USB, déverrouille-le et accepte **Faire confiance à cet ordinateur**.
2. Lance Sideloadly et vérifie que ton iPhone apparaît.
3. Glisse **`MihonReader-UNSIGNED.ipa`** dans la zone IPA.
4. Saisis ton identifiant Apple personnel et lance **Start**.
5. Si demandé, authentifie-toi et valide le code Apple dans Sideloadly. **Ne partage jamais ce mot de passe ou ce code dans une conversation ou un dépôt GitHub.** Sideloadly est un outil tiers : n’utilise que son téléchargement officiel et décide toi-même si tu souhaites lui confier l’authentification.
6. Suis les indications affichées par iOS pour faire confiance au profil développeur. Il peut apparaître dans **Réglages > Général > VPN et gestion de l’appareil**.
7. Si demandé, active **Réglages > Confidentialité et sécurité > Mode développeur** et redémarre l’iPhone.
8. Ouvre **Mihon Reader**. Appuie sur **+** pour importer tes fichiers PDF ou images.

## 4. Renouveler la signature

Avec un compte Apple gratuit, Sideloadly indique que la signature est valable **7 jours**. Configure son mécanisme de rafraîchissement ou renouvelle depuis le PC avant expiration.

Pour les mises à jour, conserve le même compte et le même identifiant d’application. Ne supprime pas l’app pour la renouveler : la suppression efface sa bibliothèque locale. Conserve toujours les PDF et images originaux.

## Limites à connaître

- L’IPA fourni n’est pas signé. Le télécharger dans Safari ne l’installe pas.
- Aucune signature enterprise ou service de certificats douteux n’est proposé.
- Le site de Sideloadly annonce iOS **7 à 26+**. Cette documentation ne garantit pas à elle seule que l’outil fonctionne sur ta version précise d’**iOS 27** ; l’installation sur ton appareil reste à tester.
- Le projet cible iOS 17 minimum et le build iPhone contient du code arm64. La réussite de compilation n’est pas un test de lancement sur iPhone 12.
- Cette application locale indépendante ne contient pas les extensions APK de Mihon ni ses sources en ligne.

## Si l’installation échoue

- iPhone absent : vérifier USB, confiance et pilotes Apple.
- Signature refusée : consulter le message Sideloadly, l’authentification Apple et les restrictions du compte.
- App non approuvée : vérifier le profil développeur et le mode développeur sur l’iPhone.
- App expirée : renouveler sa signature depuis Windows.
- Autre erreur : transmettre seulement le message d’erreur ou un journal **expurgé des identifiants, mots de passe, codes de connexion et données privées**.

## Source

Documentation officielle Sideloadly consultée le 13 octobre 2026 : https://sideloadly.io/index.html.

# Mihon Reader pour iPhone — prototype natif indépendant

Première version SwiftUI inspirée des usages de Mihon, créée à partir de l’analyse du dépôt Android. **Ce n’est ni un port complet ni une version officielle de Mihon.** Il s’agit d’une nouvelle application locale : aucun code d’extension Android n’est exécuté.

## Ce qui fonctionne dans le code livré

- Bibliothèque avec couvertures tirées de la première page.
- Import depuis l’application Fichiers : chaque PDF devient un titre ; les images sélectionnées ensemble deviennent un titre avec des pages triées par nom (tri naturel).
- Copie privée des fichiers importés, permettant la lecture hors ligne après import.
- Recherche, filtres de catégories, favoris, changement de titre et de catégorie.
- Lecteur paginé gauche-droite ou droite-gauche.
- Mode vertical / webtoon.
- Zoom par pincement et double-tap en mode paginé.
- Progression enregistrée à chaque changement de page, historique récent, marque-page par titre.
- Suppression d’un titre et de ses fichiers importés.
- Interface française sombre, composants SwiftUI natifs, prise en charge iPhone et iPad.
- Aucun service en ligne, compte, SDK de publicité ou télémétrie ajouté.

## Installation sur ton iPhone 12

### Prérequis

- Un **Mac avec Xcode** : les outils Apple ne sont pas disponibles dans le sandbox Linux utilisé pour créer ce projet.
- iOS **17 ou supérieur** pour cette implémentation. L’iPhone 12 peut utiliser iOS 17 ; **la compatibilité avec ta version précise d’iOS 27 n’a pas été testée**. Utilise un Xcode qui prend en charge le système installé sur ton iPhone.
- Un compte Apple pour signer l’app. Une Personal Team permet généralement le test personnel avec des limitations et une signature temporaire ; la distribution TestFlight nécessite le programme Apple Developer.

### Étapes

1. Décompresse `Mihon-iOS.zip` sur ton Mac.
2. Ouvre **`MihonReader.xcodeproj`** avec Xcode.
3. Dans les réglages Xcode, connecte ton compte Apple.
4. Sélectionne le projet, la cible `MihonReader`, puis **Signing & Capabilities**.
5. Laisse **Automatically manage signing** activé et choisis ta **Team**.
6. Remplace `org.local.mihonreader` par un identifiant unique, par exemple `com.tonnom.mangalocal`.
7. Connecte et déverrouille ton iPhone. Accepte la confiance et active le **mode développeur** si Xcode/iOS te le demande.
8. Choisis ton iPhone comme destination et lance **Run** (⌘R).
9. Si iOS demande de faire confiance au profil développeur, suis les indications dans Réglages > Général > VPN et gestion de l’appareil.
10. Dans l’app, touche **+**, puis sélectionne un PDF ou des images depuis Fichiers.

Avec une signature personnelle gratuite, un renouvellement périodique peut être nécessaire. Un ZIP de projet Xcode n’est pas un IPA : il ne peut pas être installé en le touchant simplement sur l’iPhone.

## Organisation du projet

```text
MihonReader.xcodeproj/        Projet et schéma Xcode partagés
MihonReader/
  MihonReaderApp.swift        Point d’entrée, onglets, réglages
  LibraryStore.swift         Modèles, import, stockage, cache d’images
  LibraryView.swift          Bibliothèque, fiche de titre, historique
  ReaderView.swift           Lecteur paginé/vertical, chargement, zoom
  PrivacyInfo.xcprivacy      Déclaration des API UserDefaults utilisées
TESTS-MANUELS.md              Plan de vérification sur simulateur/iPhone
```

Le projet ne requiert aucun paquet externe. PDFKit, ImageIO et SwiftUI font partie des SDK Apple. Le code utilise le mode de langage Swift 5 et une cible iOS 17.

## Stockage et précautions

Les fichiers sont copiés dans `Documents/Library/<UUID>/`. La bibliothèque est enregistrée dans `Documents/Library/library.json`, avec une écriture atomique. Les réglages du lecteur sont stockés dans UserDefaults.

- **Supprimer l’application efface sa bibliothèque. Conserve les fichiers originaux.**
- Il n’y a pas encore de fonction de sauvegarde/export utilisateur ni de restauration de bibliothèque.
- Le stockage n’est pas chiffré par une couche spécifique ajoutée dans ce projet ; il bénéficie des protections du système iOS.
- La sélection d’un fichier iCloud peut déclencher son téléchargement par iOS.
- Les PDF protégés ou vides sont refusés.
- L’import tourne hors du thread principal ; les vignettes utilisent un cache mémoire borné à environ 48 Mio. Ce n’est pas un benchmark de consommation totale.
- Les pages sont rasterisées pour affichage ; le zoom maximal est limité, sans rendu PDF vectoriel continu.

## Fonctions non incluses

Cette version **ne prend pas en charge** :

- les extensions `.apk` de Mihon ou ses dépôts ;
- les sources en ligne et le téléchargement de chapitres sur des sites ;
- les archives CBZ/CBR/7Z ;
- les sauvegardes `.tachibk` ;
- les trackers AniList/MyAnimeList et autres ;
- la synchronisation iCloud de la bibliothèque ;
- la planification des mises à jour ;
- le verrouillage biométrique ;
- les chapitres multiples au sein d’un titre : chaque import correspond à un titre/document.

Pour conserver l’écosystème d’extensions Android, une architecture serveur compatible (par exemple un serveur de lecture séparé et un client iOS) serait un projet distinct. Aucun serveur n’est fourni ou configuré ici.

## État des vérifications

Effectué dans le sandbox :

- parsing syntaxique des quatre fichiers Swift avec tree-sitter-swift ;
- parsing du projet `project.pbxproj` ;
- validation XML du schéma Xcode et du manifeste de confidentialité ;
- vérification des références de fichiers du projet.

**Compilation confirmée sur GitHub Actions** : le run [38431921205](https://github.com/ilary23/Mihon/actions/runs/38431921205) a terminé avec succès les builds simulateur et iPhone. Le code a donc été compilé avec le SDK iOS et vérifié par le compilateur Swift.

**Non effectué :** lancement sur simulateur/iPhone, profilage mémoire ou signature Apple. La réussite du build ne remplace pas les tests sur appareil.

Sur Mac, pour vérifier une compilation simulateur sans signature :

```bash
xcodebuild -project MihonReader.xcodeproj \
  -scheme MihonReader \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Pour une publication App Store/TestFlight, il faut notamment effectuer les tests sur appareil, ajouter les visuels de distribution, vérifier les déclarations de confidentialité, choisir un nom distinct et configurer la signature de distribution. Ce projet est un point de départ pour usage personnel, pas une application annoncée prête pour l’App Store.

## Compilation automatique GitHub Actions

Le workflow `.github/workflows/ios-build.yml` se lance à chaque push sur `main`, pour les pull requests et manuellement depuis **Actions > Build iPhone app > Run workflow**.

Sur un runner macOS, il compile :

1. une application pour le simulateur iOS ;
2. une application native iPhone **non signée**, empaquetée dans `MihonReader-UNSIGNED.ipa`.

L’IPA, le ZIP simulateur et les journaux sont conservés pendant 14 jours dans les artifacts de l’exécution. **L’IPA non signé n’est pas directement installable.** Sur Windows, Sideloadly peut le signer avec ton compte Apple et l’installer : voir [INSTALLER-WINDOWS.md](INSTALLER-WINDOWS.md). Le workflow ne contient aucun token GitHub personnel ni secret Apple.

Pour l’iPhone 12 sous iOS 27, vérifier également avec un Xcode/SDK adapté à cette version : le runner macOS fourni n’est pas une garantie de compatibilité avec ce système.

# Vérifications à effectuer dans Xcode

Ces tests sont proposés, **pas annoncés comme déjà exécutés**. Commencer par une compilation simulateur, puis tester sur iPhone 12 avec sa version réelle d’iOS.

| Test | Procédure | Résultat attendu |
|---|---|---|
| Première ouverture | Installer puis ouvrir | État vide clair, aucun faux titre ni connexion imposée |
| Import PDF | Importer un PDF de plusieurs pages | Un titre avec le bon nombre de pages et une couverture |
| Import images | Sélectionner page1, page2, page10 | Un seul titre, ordre naturel 1, 2, 10 |
| Import partiel | Sélectionner un PDF valide et un fichier image illisible | Contenu valide conservé, erreur présentée pour l’autre |
| PDF protégé | Importer un PDF verrouillé | Refus avec message, sans titre vide |
| Persistance | Importer, quitter complètement puis rouvrir | Titres et fichiers conservés |
| Lecture paginée | Lire cinq pages | Navigation correcte, compteur correspondant |
| Reprise | Fermer puis rouvrir le lecteur | Dernière page retrouvée |
| Sens manga | Activer droite vers gauche | Glisser dans le sens manga, sans changement de numérotation |
| Zoom | Pincer, déplacer, double-taper | Agrandissement et déplacement ; retour au cadrage |
| Vertical | Passer en vertical, défiler, fermer | Dernière page visible enregistrée et reprise à vérifier |
| Marque-page | Marquer une page, naviguer, revenir via le menu | Retour à la page marquée |
| Organisation | Changer titre/catégorie, ajouter favori | Recherche et filtres suivent les changements |
| Suppression | Confirmer la suppression d’un titre | Titre et copie interne effacés ; original intact |
| Hors ligne | Après import, activer le mode avion | Lecture du contenu importé possible |
| Rotation | Tourner l’iPhone en cours de lecture | Présentation adaptée sans perdre la progression |
| Gros document | Importer un PDF de plusieurs centaines de pages | Vérifier réactivité et mémoire avec Instruments |
| Accessibilité | VoiceOver et grande taille de texte | Vérifier labels, boutons, lisibilité et débordements |
| iOS 27 | Compiler avec SDK adapté puis lancer sur l’appareil | Compatibilité à confirmer, aucun résultat présumé |

Points particulièrement sensibles à vérifier sur appareil : interaction des gestes de zoom avec TabView, suivi de page en mode vertical et comportement du sélecteur Fichiers avec iCloud Drive.

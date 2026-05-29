# Trackpad

[English](README.md) | [中文](README.zh-CN.md)

Trackpad est un projet natif pour les plateformes Apple. Son objectif est de transformer un iPhone ou un iPad en trackpad pour macOS. Ce dépôt est prévu pour être hébergé ici :

```text
git@github.com:AielloChan/trackpad.git
```

Le jalon actuel est un MVP sur réseau local. L'application iOS affiche une surface tactile noire en plein écran, capture les interactions multi-touch, les normalise en événements indépendants de la plateforme, puis les envoie à une application hôte macOS. L'hôte macOS s'annonce avec Bonjour, accepte une connexion client associée, convertit les événements entrants en commandes d'entrée macOS, puis injecte les mouvements du pointeur, les clics, les glissements et le défilement avec les API système.

## État actuel

La phase 1 est utilisable pour des tests en reseau local :

- Client iOS/iPadOS avec surface tactile noire.
- Decouverte Bonjour et connexion manuelle par IP en secours.
- Code d'association a six chiffres avant le traitement des entrees.
- Mouvement du pointeur a un doigt.
- Tap a un doigt pour le clic gauche.
- Tap, second appui rapide, puis mouvement pour le glisser.
- Tap a deux doigts pour le clic droit.
- Defilement a deux doigts sans inertie generee cote client.
- Balayage vers l'interieur depuis le bord droit, avec deux contacts avant le relachement, pour ouvrir le centre de notifications macOS, puis balayage a deux doigts vers la droite pour le fermer.
- Balayage a trois doigts haut/bas/gauche/droite pour Mission Control, App Expose et la navigation entre Spaces.
- Affichage cote client de la latence, du taux d'echantillonnage tactile et du taux d'evenements envoyes.
- Curseurs de reglage pour la vitesse du pointeur, l'inertie du defilement et les delais des gestes.
- Injection cote macOS pour mouvement, clic, glisser, phases de defilement, phases d'inertie et etat de double-clic.
- Journaux persistants de l'hote macOS dans `~/Library/Logs/Trackpad/host.log`.

L'objectif est de continuer a rapprocher le ressenti de l'experience officielle du trackpad Apple. La phase 1 garde encore des verifications manuelles dans `TODOS.md`, en particulier les reglages sur appareil reel et les tests de clic/defilement dans une zone sure.

## Structure du depot

```text
apps/
  ios/
    TrackpadIOS/          Cible de l'application iOS/iPadOS.
    TrackpadIOSCore/      Logique reutilisable des gestes et du client iOS.
  macos/
    TrackpadHost/         Package Swift et CLI de l'hote macOS.
    TrackpadHostApp/      Application hote native macOS.

packages/
  TrackpadKit/            Protocole partage, transport, securite et modeles independants de la plateforme.

protocol/
  v1/                     Documentation du protocole.

docs/
  architecture.md         Architecture du systeme.
  decisions/              Decisions d'architecture.
  ios-client-mvp.md       Notes et historique de verification du MVP iOS.
  macos-host-mvp.md       Notes et historique de verification de l'hote macOS.

plans/
  *.md                    Plans d'implementation avec suivi d'avancement.

TODOS.md                  Suivi courant du projet.
AGENTS.md                 Instructions pour les agents de codage IA.
```

## Architecture

Trackpad est un systeme de controle a deux cotes :

```text
iPhone / iPad
  -> capture les touches
  -> normalise les gestes
  -> envoie des evenements TrackpadProtocol

hote macOS
  -> recoit les frames de session
  -> verifie l'association
  -> convertit les evenements en commandes macOS
  -> injecte des entrees CGEvent
```

Le protocole partage est la frontiere entre les clients et les hotes. Les details tactiles iOS ne doivent pas fuir dans la couche d'injection macOS, et les details d'injection macOS ne doivent pas fuir dans le mappeur de gestes iOS.

La couche transport reste abstraite. Le MVP utilise Bonjour et TCP direct sur le reseau local. Les versions futures pourront ajouter une traversee NAT de type WebRTC, un relais de secours, des clients Android et des hotes Windows sans modifier le modele principal des evenements d'entree.

## Prerequis

- macOS avec Xcode installe.
- Chaine d'outils Swift fournie par Xcode.
- iPhone/iPad ou simulateur iOS pour le client.
- Permission d'accessibilite accordee a l'application hote macOS ou au CLI hote avant l'injection d'entrees.

## Construire et lancer

### Application hote macOS

Ouvrir et lancer :

```text
apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj
```

Utiliser le scheme `TrackpadHostApp`. L'application affiche le code d'association courant, l'etat du serveur, le port, le nombre de connexions et l'etat de la permission d'accessibilite.

Construction en ligne de commande :

```bash
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build
```

### CLI hote macOS

```bash
cd apps/macos/TrackpadHost
swift run TrackpadHost status
swift run TrackpadHost request-permission
swift run TrackpadHost log-path
swift run TrackpadHost serve 123456
```

Actions locales de debug :

```bash
swift run TrackpadHost move-test
swift run TrackpadHost left-click-test
swift run TrackpadHost right-click-test
swift run TrackpadHost scroll-test
```

Executer les tests de clic et de defilement uniquement dans une zone d'interface vide et sure.

### Client iOS

Ouvrir et lancer :

```text
apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj
```

Utiliser le scheme `TrackpadIOS` sur simulateur ou appareil reel. Un iPhone ou iPad reel est necessaire pour tester correctement le ressenti tactile.

Exemple de construction pour simulateur :

```bash
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Tests

Tests du package partage :

```bash
cd packages/TrackpadKit
swift test
```

Tests de l'hote macOS :

```bash
cd apps/macos/TrackpadHost
swift test
```

Tests du coeur iOS :

```bash
cd apps/ios/TrackpadIOSCore
swift test
```

## Feuille de route

Travail a court terme :

- Continuer le reglage des gestes sur appareil reel en les comparant au comportement du trackpad Apple.
- Remplacer JSON Lines par un format binaire compact lorsque le modele d'evenements sera stabilise.
- Persister les appareils de confiance et ameliorer l'experience d'association.
- Ajouter des sessions chiffrees.

Travail a plus long terme :

- Connexion distante avec signaling, traversee NAT et relais de secours.
- Client Android.
- Hote Windows.
- Generation de schemas de protocole multiplateformes.

## Processus de developpement

`TODOS.md` est la source active du suivi. `plans/*.md` sert de source d'implementation pour les travaux scopes. Les decisions d'architecture importantes doivent etre ajoutees dans `docs/decisions/`.

Les contributeurs et agents de codage doivent lire `AGENTS.md` avant de modifier le code. Le projet privilegie les fichiers courts et lisibles, la logique reutilisable independante de la plateforme, et les tests couvrant l'encodage du protocole, les machines d'etat des gestes, le mapping des evenements et le comportement du transport.

# Scooter Power — spécification de la version 1

Date : 2026-11-12

## Objectif

Application iPhone affichant en direct le tableau de bord d'un trajet en
scooter, à partir des capteurs du téléphone fixé au guidon. Elle reproduit
la maquette fournie : thème sombre, accents cyan (vitesse, inclinaison) et
orange (accélération).

Réussite : le développeur ouvre le projet dans Xcode, le signe, le lance sur
son iPhone, démarre un trajet et voit toutes les valeurs de la maquette
évoluer avec les vrais capteurs.

## Périmètre

Inclus :

- Écran de trajet : compteur de vitesse, statistiques, accélération,
  inclinaison, barre d'actions.
- Cycle de trajet : démarrer, mettre en pause, reprendre, terminer, résumé.
- Carte du tracé en cours.
- Prise de photo enregistrée dans la photothèque.
- Mode démo quand les capteurs sont absents (simulateur).

Exclus :

- Historique et sauvegarde des trajets.
- Export (GPX ou autre), partage, comptes, synchronisation.
- iPad, paysage, Apple Watch, CarPlay, widgets, Live Activities.
- Réglages utilisateur (unités, échelle du compteur).
- Menu « ••• » de la maquette : il ne contient que « Recalibrer
  l'inclinaison ».

## Contraintes techniques

- iOS 17.0 minimum, iPhone, portrait uniquement.
- Xcode 16 ou plus récent, Swift en mode de langage 5, SwiftUI, Observation
  (`@Observable`), Swift Charts, MapKit.
- Aucune dépendance externe.
- Unités fixes : km/h, km, m, m/s², degrés. Textes en français.
- Identifiant de bundle : `com.brunotahiti.ScooterPower` (modifiable dans
  Xcode). Équipe de signature laissée vide.

## Structure du dépôt

```
ScooterPower.xcodeproj/         projet Xcode écrit à la main
Config/Info.plist               modes d'arrière-plan
ScooterPower/                   cible app
  App/                          point d'entrée, Assets
  Services/                     LocationService, MotionService, DemoFeed
  ViewModels/                   TripViewModel
  Views/                        écran, cartes, jauges, feuilles
  Theme/                        couleurs, styles
ScooterCore/                    package Swift local, sans import Apple
  Package.swift
  Sources/ScooterCore/
  Tests/ScooterCoreTests/
```

`ScooterCore` n'importe que Foundation, pour être compilé et testé sous
Linux comme sous macOS.

## ScooterCore

Toutes les entrées sont des valeurs simples horodatées ; aucun type
CoreLocation ou CoreMotion ne traverse cette frontière.

### TripStatistics

Entrée : échantillons `(horodatage, latitude, longitude, vitesse m/s,
altitude m, précision horizontale m)` et appels `pause()` / `resume()`.

Sorties :

- `currentSpeedKmh` : dernière vitesse valide, `nil` si aucun point valide
  depuis plus de 5 s.
- `maxSpeedKmh` : maximum des vitesses valides.
- `distanceMeters` : somme des distances orthodromiques (haversine) entre
  échantillons valides consécutifs.
- `movingDuration` : temps cumulé où la vitesse dépasse 3 km/h.
- `totalDuration` : temps écoulé depuis le départ, pauses exclues.
- `averageSpeedKmh` : `distance / movingDuration`, 0 si durée nulle.
- `altitudeMeters` : dernière altitude valide.
- `route` : liste des coordonnées valides, pour la carte.

Règles :

- Un échantillon est valide si la vitesse est ≥ 0 et la précision
  horizontale est comprise entre 0 et 50 m.
- Les échantillons reçus en pause sont ignorés. Le segment entre le dernier
  point avant la pause et le premier après la reprise ne compte pas dans la
  distance.
- Un saut impliquant plus de 200 km/h entre deux points est rejeté.

### AccelerationAnalyzer

Entrée : `(horodatage, vitesse GPS m/s ou nil, accélération longitudinale
capteur m/s²)`.

- L'accélération GPS est la dérivée de la vitesse entre deux points GPS.
- Filtre complémentaire : la valeur du capteur fournit la réactivité, la
  dérivée GPS corrige la dérive, avec une constante de temps de 2 s. Sans
  GPS, la valeur du capteur filtrée est utilisée seule.
- Lissage passe-bas, constante de temps 0,3 s.

Sorties :

- `current` en m/s², signée.
- `level` : `brakingHard` (≤ −2,5), `braking` (≤ −0,8), `stable`,
  `accelerating` (≥ 0,8), `acceleratingHard` (≥ 2,5).
- `history` : valeurs des 30 dernières secondes, une par 0,25 s.
- `peak` : maximum positif de `history`.
- `gaugePosition` : `current` ramené dans [−1, 1] sur une échelle de
  ±4 m/s², pour la jauge.

### LeanAngleEstimator

Il conserve aussi l'inclinaison maximale atteinte de chaque côté, pour le
résumé.

Entrée : vecteur gravité `(x, y, z)` dans le repère du téléphone.

- `calibrate()` mémorise la gravité courante comme position verticale.
- L'angle est la rotation autour de l'axe d'avance entre la gravité
  calibrée et la gravité courante, signée : positif vers la droite.
- Lissage passe-bas, constante de temps 0,2 s. Borné à ±60°.

Sorties : `angleDegrees` (signé), `side` (`left`, `right`, `upright` si
|angle| < 1°).

Limite connue : en virage équilibré, la gravité apparente reste alignée
avec le scooter ; la mesure sous-estime donc l'inclinaison réelle. L'app
l'indique dans le texte d'aide de la carte Inclinaison.

### TripSession et DemoTrip

`TripSession` porte la machine à états du trajet (`idle`, `recording`,
`paused`, `finished`) et réunit les trois composants ci-dessus ; elle est
dans `ScooterCore` pour être testée. `DemoTrip` produit le trajet
synthétique du mode démo.

## Cible app

### Services

- `LocationService` : enveloppe `CLLocationManager`. Précision
  `bestForNavigation`, type d'activité `automotiveNavigation`, mises à jour
  en arrière-plan actives pendant l'enregistrement. Publie les échantillons
  et l'état d'autorisation.
- `MotionService` : enveloppe `CMMotionManager`, device motion à 50 Hz.
  Publie la gravité et l'accélération utilisateur. L'axe d'avance est l'axe
  perpendiculaire à l'écran, projeté à l'horizontale d'après la calibration.
- `DemoFeed` : diffuse le trajet synthétique de `DemoTrip` avec les mêmes
  types de sortie.
  Utilisé quand les capteurs sont indisponibles.

Les deux services réels et `DemoFeed` se conforment à des protocoles, pour
que `TripViewModel` ne dépende d'aucun type concret.

### TripViewModel

Enveloppe observable de `TripSession`.
États : `idle` → `recording` ⇄ `paused` → `finished` → `idle`.

- `start()` : demande les autorisations, calibre l'inclinaison, démarre les
  services, désactive la mise en veille de l'écran.
- `pause()` / `resume()` : suspend ou reprend les statistiques ; les
  capteurs restent actifs.
- `finish()` : arrête les services, fige les statistiques, présente le
  résumé.
- `reset()` : retour à `idle` après fermeture du résumé.

Il expose aux vues des valeurs déjà formatées en français (virgule
décimale, `00:16:42`).

### Vues

- `TripScreen` : écran unique, défilement vertical si l'écran est petit.
- En-tête : icône, titre « Trajet en cours » / « Prêt » / « En pause »,
  pastille « Enregistrement », menu « ••• ».
- `SpeedometerView` : arc de 0 à 140 km/h gradué tous les 20, partie
  parcourue en cyan, vitesse en très grand, mention « GPS ». Affiche `--`
  sans vitesse valide.
- Cartes : vitesse maximale, vitesse moyenne, distance + altitude, durée de
  roulage + durée totale.
- `AccelerationCard` : valeur signée, libellé de niveau, jauge segmentée
  Freinage / Stable / Accélération avec curseur, graphe des 30 dernières
  secondes, pastille « Pic ».
- `LeanCard` : angle, côté, jauge en arc avec silhouette inclinée.
- Barre du bas : Carte, Pause/Reprendre, bouton principal (« Démarrer le
  trajet » ou « Terminer le trajet »), Photo.
- `MapSheet` : carte MapKit avec le tracé et la position.
- `SummaryView` : distance, durées, vitesses max et moyenne, pic
  d'accélération, inclinaison maximale de chaque côté.
- Photo : `UIImagePickerController` en mode appareil photo, image
  enregistrée dans la photothèque.

« Terminer le trajet » demande une confirmation.

## Autorisations (Info.plist)

- `NSLocationWhenInUseUsageDescription`
- `NSMotionUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `UIBackgroundModes` : `location`

## Gestion des erreurs

| Situation | Comportement |
|---|---|
| Localisation refusée | Bandeau expliquant le besoin, bouton vers Réglages ; le trajet ne démarre pas |
| GPS imprécis ou absent | Vitesse `--`, statistiques inchangées, mention « Signal GPS faible » |
| Capteurs de mouvement absents | Mode démo, mention « Données d'illustration » en bas d'écran |
| Appareil photo refusé ou absent | Alerte, le trajet continue |

## Tests

- Tests unitaires de `ScooterCore` (XCTest), exécutables par `swift test` :
  distance, durées, pause, rejet des points invalides, niveaux
  d'accélération, fenêtre de 30 s, pic, signe et calibration de
  l'inclinaison.
- L'interface, les services et le fichier projet ne peuvent pas être
  compilés dans l'environnement de développement (Linux). Leur première
  vérification est la compilation dans Xcode et un essai sur iPhone par le
  développeur.

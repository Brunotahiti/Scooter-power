# Scooter Power v2 — plan d'implémentation

**Spec :** `docs/superpowers/specs/2026-11-13-scooter-power-v2-design.md`

Exécution dans la session, un commit par tâche. TDD pour `ScooterCore`.

### Tâche 1 : SprintTimer
- `ScooterCore/Sources/ScooterCore/SprintTimer.swift`, tests `SprintTimerTests.swift`.
- `public struct SprintTimer` : `add(timestamp:speedKmh:)`, `cancelRun()`,
  `last50`, `best50`, `last80`, `best80`, `isRunning`, `runElapsed(at:)`.
- `TripSession` l'alimente en enregistrement et l'annule à la pause ;
  `TripSummary` gagne `best50`, `best80`.
- App : `SprintCard`, lignes du résumé.

### Tâche 2 : vraie inclinaison
- `MotionSample.rotationRate` ; `LeanAngleEstimator.update(gravity:timestamp:rotationRate:speed:trackExtremes:)`,
  `static func physicalLeanDegrees(speed:yawRate:)`, `static func physicsWeight(speed:)`.
- `TripSession` transmet la dernière vitesse GPS valide (5 s au plus).
- App : `MotionService` lit `rotationRate` ; `DemoTrip` en produit un cohérent.

### Tâche 3 : historique
- `RouteSimplifier.downsample(_:maxPoints:)` testé ; `Coordinate: Codable`.
- App : `Models/TripRecord.swift`, `Views/HistoryView.swift`,
  `Views/TripDetailView.swift`, `Views/TripFigures.swift` (lignes partagées
  avec le résumé), conteneur SwiftData dans `ScooterPowerApp`.

### Tâche 4 : paysage
- `SpeedometerView` accepte une échelle ; `Views/LandscapeTripView.swift` ;
  `TripScreen` choisit selon `verticalSizeClass` ; orientations dans le projet.

### Tâche 5 : activité en direct
- `TripActivityAttributes` (iOS seulement) ; `Services/LiveActivityController.swift` ;
  dossier `ScooterPowerWidgets/` ; `Config/Widgets-Info.plist` ; cible
  d'extension, dépendance et phase d'embarquement dans `project.pbxproj` ;
  script de contrôle du projet étendu.

### Fin
- Relecture indépendante de la branche, une passe de correction, README.

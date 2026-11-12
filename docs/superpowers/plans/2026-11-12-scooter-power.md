# Scooter Power v1 — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** livrer un projet Xcode qui affiche en direct le tableau de bord d'un trajet en scooter (vitesse, statistiques, accélération, inclinaison) à partir des capteurs de l'iPhone.

**Architecture :** toute la logique vit dans un package Swift local `ScooterCore`, pur Foundation, testé sous Linux : statistiques, filtres, machine à états du trajet, trajet de démonstration, formatage. La cible app `ScooterPower` ne contient que les enveloppes CoreLocation / CoreMotion, un view model `@Observable` mince et les vues SwiftUI.

**Tech Stack :** Swift (mode de langage 5), SwiftUI, Observation, Swift Charts, MapKit, CoreLocation, CoreMotion, XCTest. Xcode 16 ou plus récent.

**Spec :** `docs/superpowers/specs/2026-11-12-scooter-power-design.md`

## Global Constraints

- iOS 17.0 minimum, iPhone, portrait uniquement.
- Aucune dépendance externe.
- `ScooterCore` n'importe que `Foundation` (et `XCTest` dans les tests). `swift-tools-version: 5.9`.
- Unités fixes : km/h, km, m, m/s², degrés. Textes en français, virgule décimale.
- Identifiant de bundle `com.brunotahiti.ScooterPower`, `DEVELOPMENT_TEAM` vide.
- Projet Xcode au format `objectVersion = 77` avec groupe synchronisé sur le dossier `ScooterPower/` : aucun fichier source n'est listé dans le `.pbxproj`.
- Tous les horodatages de `ScooterCore` sont des `TimeInterval` en secondes. Les horloges GPS et mouvement ne sont jamais comparées entre elles.
- Chaque commit se termine par les lignes d'attribution de la session.

## Review Focus

1. **Points GPS en double ou en désordre** (CoreLocation redélivre des points en cache au démarrage) : ignorés, sans distance négative ni division par zéro. → Tâche 2.
2. **Vitesse GPS à −1 avec position valide** (courant à l'arrêt) : l'échantillon est ignoré, la vitesse affichée devient `--` après 5 s sans point valide, jamais une valeur négative. → Tâche 2.
3. **Trou dans les données de mouvement** (app suspendue, plusieurs secondes sans échantillon) : les filtres repartent de la nouvelle valeur, l'historique ne dépasse jamais 120 points, aucune valeur non finie. → Tâche 4.
4. **Calibration dégénérée** (téléphone à plat, gravité nulle ou NaN) : repli sur l'axe haut du téléphone, ou calibration refusée ; l'angle reste fini. → Tâche 3.
5. **Actions hors séquence** (pause sans trajet, double pause, terminer en pause, échantillons avant le départ) : sans effet, durées cohérentes. → Tâches 2 et 5.

## Fichiers

```
ScooterCore/Package.swift
ScooterCore/Sources/ScooterCore/Types.swift               Vector3, Coordinate, LocationSample, MotionSample
ScooterCore/Sources/ScooterCore/Formatters.swift          formatage français
ScooterCore/Sources/ScooterCore/TripStatistics.swift
ScooterCore/Sources/ScooterCore/MountCalibration.swift    repère du support
ScooterCore/Sources/ScooterCore/LeanAngleEstimator.swift
ScooterCore/Sources/ScooterCore/AccelerationAnalyzer.swift
ScooterCore/Sources/ScooterCore/TripSession.swift         machine à états + résumé
ScooterCore/Sources/ScooterCore/DemoTrip.swift
ScooterCore/Tests/ScooterCoreTests/<Nom>Tests.swift       un fichier par source

ScooterPower.xcodeproj/project.pbxproj
Config/Info.plist                                         UIBackgroundModes seulement
ScooterPower/App/ScooterPowerApp.swift
ScooterPower/App/Assets.xcassets/
ScooterPower/Theme/Theme.swift
ScooterPower/Services/Providers.swift                     protocoles
ScooterPower/Services/LocationService.swift
ScooterPower/Services/MotionService.swift
ScooterPower/Services/DemoFeed.swift
ScooterPower/ViewModels/TripViewModel.swift
ScooterPower/Views/TripScreen.swift
ScooterPower/Views/HeaderView.swift
ScooterPower/Views/SpeedometerView.swift
ScooterPower/Views/StatCards.swift
ScooterPower/Views/AccelerationCard.swift
ScooterPower/Views/LeanCard.swift
ScooterPower/Views/ScooterShapes.swift                    silhouettes dessinées en Path
ScooterPower/Views/BottomBar.swift
ScooterPower/Views/MapSheet.swift
ScooterPower/Views/SummaryView.swift
ScooterPower/Views/CameraPicker.swift
README.md
.gitignore
```

---

### Task 1 : Outillage, squelette du package, types et formatage

**Files :**
- Create : `.gitignore`, `ScooterCore/Package.swift`, `ScooterCore/Sources/ScooterCore/Types.swift`, `ScooterCore/Sources/ScooterCore/Formatters.swift`
- Test : `ScooterCore/Tests/ScooterCoreTests/FormattersTests.swift`

**Interfaces — Produces :**

```swift
public struct Vector3: Sendable, Equatable {
    public var x, y, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double)
    public var length: Double
    public var isFinite: Bool
    public func dot(_ o: Vector3) -> Double
    public func cross(_ o: Vector3) -> Vector3
    public func scaled(_ k: Double) -> Vector3
    public func minus(_ o: Vector3) -> Vector3
    public var normalized: Vector3?          // nil si length < 1e-9 ou non fini
}
public struct Coordinate: Sendable, Equatable { public var latitude, longitude: Double; public init(latitude:longitude:) }
public struct LocationSample: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var latitude, longitude: Double
    public var speed: Double                 // m/s, négatif = inconnu
    public var altitude: Double              // m
    public var horizontalAccuracy: Double    // m, négatif = invalide
    public init(timestamp:latitude:longitude:speed:altitude:horizontalAccuracy:)
}
public struct MotionSample: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var gravity: Vector3              // repère du téléphone, en g
    public var userAcceleration: Vector3     // repère du téléphone, en g
    public init(timestamp:gravity:userAcceleration:)
}
public enum Formatters {
    public static func duration(_ seconds: TimeInterval) -> String      // "HH:MM:SS"
    public static func decimal(_ value: Double, digits: Int) -> String  // virgule décimale
    public static func signed(_ value: Double, digits: Int) -> String   // "+2,8", "−1,3", "0,0"
}
```

- [ ] **Step 1 : installer la chaîne d'outils Swift pour Linux** (hors dépôt)

```bash
mkdir -p /opt/swift && curl -fsSL https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz | tar xz -C /opt/swift --strip-components=1
export PATH=/opt/swift/usr/bin:$PATH && swift --version
```
Attendu : `Swift version 6.0.3`.

- [ ] **Step 2 : `.gitignore`** — `.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`, `.swiftpm/`.

- [ ] **Step 3 : `Package.swift`** — bibliothèque `ScooterCore`, plateformes `.iOS(.v17)`, `.macOS(.v14)`, cible de test `ScooterCoreTests`.

- [ ] **Step 4 : écrire les tests de formatage**

```swift
final class FormattersTests: XCTestCase {
    func testDuration() {
        XCTAssertEqual(Formatters.duration(1002), "00:16:42")
        XCTAssertEqual(Formatters.duration(1085.9), "00:18:05")
        XCTAssertEqual(Formatters.duration(65105), "18:05:05")
        XCTAssertEqual(Formatters.duration(-3), "00:00:00")
        XCTAssertEqual(Formatters.duration(.nan), "00:00:00")
    }
    func testDecimal() {
        XCTAssertEqual(Formatters.decimal(12.84, digits: 1), "12,8")
        XCTAssertEqual(Formatters.decimal(68.4, digits: 0), "68")
        XCTAssertEqual(Formatters.decimal(.infinity, digits: 1), "--")
    }
    func testSigned() {
        XCTAssertEqual(Formatters.signed(2.8, digits: 1), "+2,8")
        XCTAssertEqual(Formatters.signed(-1.3, digits: 1), "\u{2212}1,3")
        XCTAssertEqual(Formatters.signed(0, digits: 1), "0,0")
        XCTAssertEqual(Formatters.signed(-0.04, digits: 1), "0,0")
    }
}
```

- [ ] **Step 5 :** `cd ScooterCore && swift test` → échec de compilation (types absents).
- [ ] **Step 6 :** implémenter `Types.swift` et `Formatters.swift`. Formatage par `String(format:)` puis remplacement de `.` par `,` (pas de `Locale`, absent ou variable sous Linux). Le signe est décidé après arrondi.
- [ ] **Step 7 :** `swift test` → 3 tests passent.
- [ ] **Step 8 :** commit « Ajoute le package ScooterCore : types et formatage ».

---

### Task 2 : TripStatistics

**Files :**
- Create : `ScooterCore/Sources/ScooterCore/TripStatistics.swift`
- Test : `ScooterCore/Tests/ScooterCoreTests/TripStatisticsTests.swift`

**Interfaces — Consumes :** `LocationSample`, `Coordinate`.

**Produces :**

```swift
public struct TripStatistics: Sendable {
    public init()
    public mutating func start(at time: TimeInterval)
    public mutating func add(_ sample: LocationSample)
    public mutating func pause(at time: TimeInterval)
    public mutating func resume(at time: TimeInterval)
    public mutating func stop(at time: TimeInterval)          // fige totalDuration
    public func currentSpeedKmh(at now: TimeInterval) -> Double?
    public func totalDuration(at now: TimeInterval) -> TimeInterval
    public private(set) var maxSpeedKmh: Double               // 0 au départ
    public private(set) var distanceMeters: Double
    public private(set) var movingDuration: TimeInterval
    public private(set) var altitudeMeters: Double?
    public private(set) var route: [Coordinate]
    public var averageSpeedKmh: Double { get }
    public static func haversine(_ a: Coordinate, _ b: Coordinate) -> Double
}
```

Règles (valeurs de la spec) :
- Valide si `speed >= 0`, `0 <= horizontalAccuracy <= 50`, toutes les valeurs finies.
- Ignoré si : avant `start`, après `stop`, en pause, non valide, ou `timestamp <=` celui du dernier point accepté.
- Rejeté si `distance / dt > 200 km/h` (55,56 m/s) par rapport au dernier point accepté ; le dernier point accepté n'est pas remplacé.
- Entre deux points acceptés : la distance s'ajoute toujours ; `dt` s'ajoute à `movingDuration` si la vitesse du nouveau point dépasse 3 km/h.
- `resume` efface le dernier point accepté : le premier point après reprise n'ajoute ni distance ni durée.
- `currentSpeedKmh(at:)` vaut `nil` sans point accepté depuis plus de 5 s.
- Rayon terrestre : 6 371 000 m.
- `pause`, `resume`, `stop` hors séquence sont sans effet.

- [ ] **Step 1 : écrire les tests**

```swift
final class TripStatisticsTests: XCTestCase {
    private func s(_ t: Double, lon: Double, speed: Double = 10, acc: Double = 5, alt: Double = 24) -> LocationSample {
        LocationSample(timestamp: t, latitude: 0, longitude: lon, speed: speed, altitude: alt, horizontalAccuracy: acc)
    }
    private func started() -> TripStatistics { var t = TripStatistics(); t.start(at: 0); return t }

    func testDistanceMaxAverage() {
        var t = started()
        t.add(s(0, lon: 0)); t.add(s(10, lon: 0.001)); t.add(s(20, lon: 0.002, speed: 12))
        XCTAssertEqual(t.distanceMeters, 222.39, accuracy: 0.05)
        XCTAssertEqual(t.movingDuration, 20, accuracy: 1e-9)
        XCTAssertEqual(t.maxSpeedKmh, 43.2, accuracy: 1e-9)
        XCTAssertEqual(t.averageSpeedKmh, 40.03, accuracy: 0.01)
        XCTAssertEqual(t.altitudeMeters, 24)
        XCTAssertEqual(t.route.count, 3)
        XCTAssertEqual(t.currentSpeedKmh(at: 21)!, 43.2, accuracy: 1e-9)
    }
    func testAverageIsZeroWithoutMovement() { XCTAssertEqual(started().averageSpeedKmh, 0) }
    func testSlowIntervalIsNotMoving() {
        var t = started()
        t.add(s(0, lon: 0)); t.add(s(10, lon: 0.00001, speed: 0.5))
        XCTAssertEqual(t.movingDuration, 0)
        XCTAssertGreaterThan(t.distanceMeters, 0)
    }
    func testInvalidSamplesIgnored() {
        var t = started()
        t.add(s(0, lon: 0, acc: 80)); t.add(s(1, lon: 0, acc: -1)); t.add(s(2, lon: 0, speed: -1))
        t.add(s(3, lon: .nan))
        XCTAssertTrue(t.route.isEmpty)
        XCTAssertNil(t.currentSpeedKmh(at: 3))
    }
    func testDuplicateAndOutOfOrderIgnored() {
        var t = started()
        t.add(s(10, lon: 0.001)); t.add(s(10, lon: 0.002)); t.add(s(5, lon: 0.003))
        XCTAssertEqual(t.route.count, 1)
        XCTAssertEqual(t.distanceMeters, 0)
    }
    func testJumpRejected() {
        var t = started()
        t.add(s(0, lon: 0)); t.add(s(1, lon: 0.01)); t.add(s(2, lon: 0.0002))
        XCTAssertEqual(t.route.count, 2)
        XCTAssertEqual(t.distanceMeters, 22.24, accuracy: 0.05)
    }
    func testPauseExcludesTimeAndGap() {
        var t = started()
        t.add(s(0, lon: 0)); t.add(s(10, lon: 0.001))
        t.pause(at: 10); t.pause(at: 12)
        t.add(s(15, lon: 0.002))
        t.resume(at: 30); t.resume(at: 31)
        t.add(s(30, lon: 0.003)); t.add(s(40, lon: 0.004))
        XCTAssertEqual(t.distanceMeters, 222.39, accuracy: 0.05)
        XCTAssertEqual(t.movingDuration, 20, accuracy: 1e-9)
        XCTAssertEqual(t.totalDuration(at: 40), 20, accuracy: 1e-9)
        XCTAssertEqual(t.totalDuration(at: 20 - 5), 10, accuracy: 1e-9) // en pause : figée
    }
    func testStaleSpeedIsNil() {
        var t = started(); t.add(s(0, lon: 0))
        XCTAssertNotNil(t.currentSpeedKmh(at: 5)); XCTAssertNil(t.currentSpeedKmh(at: 5.1))
    }
    func testNothingBeforeStartOrAfterStop() {
        var t = TripStatistics()
        t.add(s(0, lon: 0)); t.pause(at: 1); t.resume(at: 2)
        XCTAssertTrue(t.route.isEmpty); XCTAssertEqual(t.totalDuration(at: 50), 0)
        t.start(at: 0); t.add(s(1, lon: 0)); t.stop(at: 10); t.add(s(11, lon: 0.001))
        XCTAssertEqual(t.route.count, 1); XCTAssertEqual(t.totalDuration(at: 99), 10, accuracy: 1e-9)
    }
}
```

Note sur `testPauseExcludesTimeAndGap`, dernière assertion : remplacer par un appel fait pendant la pause dans une variante dédiée si l'ordre des appels la rend ambiguë — `totalDuration(at:)` interrogé à 15 après `pause(at: 10)` doit rendre 10.

- [ ] **Step 2 :** `swift test --filter TripStatisticsTests` → échec de compilation.
- [ ] **Step 3 :** implémenter `TripStatistics`.
- [ ] **Step 4 :** `swift test --filter TripStatisticsTests` → tout passe.
- [ ] **Step 5 :** commit « Ajoute TripStatistics ».

---

### Task 3 : MountCalibration et LeanAngleEstimator

**Files :**
- Create : `ScooterCore/Sources/ScooterCore/MountCalibration.swift`, `ScooterCore/Sources/ScooterCore/LeanAngleEstimator.swift`
- Test : `ScooterCore/Tests/ScooterCoreTests/MountCalibrationTests.swift`, `ScooterCore/Tests/ScooterCoreTests/LeanAngleEstimatorTests.swift`

**Interfaces — Consumes :** `Vector3`.

**Produces :**

```swift
public struct MountCalibration: Sendable, Equatable {
    public let down: Vector3       // gravité de référence, unitaire
    public let forward: Vector3    // sens de marche, unitaire, orthogonal à down
    public init?(gravity: Vector3) // nil si gravité non finie ou de norme < 0,1
    public func leanAngleDegrees(gravity: Vector3) -> Double            // + = droite ; 0 si gravité inutilisable
    public func longitudinalAcceleration(userAccelerationG: Vector3) -> Double  // m/s², + = accélération
}
public enum LeanSide: Sendable { case left, upright, right }
public struct LeanAngleEstimator: Sendable {
    public init()
    public private(set) var calibration: MountCalibration?
    @discardableResult public mutating func calibrate(gravity: Vector3) -> Bool  // remet aussi les maxima à 0
    public mutating func update(gravity: Vector3, timestamp: TimeInterval)
    public private(set) var angleDegrees: Double      // lissé, borné à ±60
    public var side: LeanSide { get }                 // upright si |angle| < 1
    public private(set) var maxLeftDegrees: Double    // valeur positive
    public private(set) var maxRightDegrees: Double
}
```

Repère du téléphone (CoreMotion) : x vers la droite de l'écran, y vers le haut de l'écran, z sortant de l'écran vers le pilote.

Algorithme de `MountCalibration` (non déterminé par les tests seuls) :

```
down    = gravity normalisé
cand    = (0,0,-1) − ((0,0,-1)·down)·down          // dos de l'écran, projeté à l'horizontale
si |cand| < 0,2 : cand = (0,1,0) − ((0,1,0)·down)·down   // téléphone à plat : haut de l'écran
forward = cand normalisé
leanAngle(g) :
    a = down − (down·forward)·forward ; b = g − (g·forward)·forward
    angle = atan2( −forward · (a × b), a · b ) en degrés
longitudinal(u) = (u · forward) × 9,80665
```

`LeanAngleEstimator` : passe-bas du premier ordre, constante de temps 0,2 s (`alpha = dt / (0,2 + dt)`). Premier échantillon, `dt <= 0` ou `dt > 1` : la valeur brute remplace la valeur lissée. Sans calibration, `update` ne fait rien.

- [ ] **Step 1 : écrire les tests**

```swift
final class MountCalibrationTests: XCTestCase {
    private func rad(_ d: Double) -> Double { d * .pi / 180 }
    func testUprightPhone() {
        let c = MountCalibration(gravity: Vector3(0, -1, 0))!
        XCTAssertEqual(c.forward, Vector3(0, 0, -1))
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(sin(rad(8)), -cos(rad(8)), 0)), 8, accuracy: 1e-6)
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(-sin(rad(20)), -cos(rad(20)), 0)), -20, accuracy: 1e-6)
        XCTAssertEqual(c.longitudinalAcceleration(userAccelerationG: Vector3(0, 0, -0.2)), 1.96133, accuracy: 1e-4)
        XCTAssertEqual(c.longitudinalAcceleration(userAccelerationG: Vector3(0, 0, 0.3)), -2.942, accuracy: 1e-3)
    }
    func testTiltedMountKeepsForwardHorizontal() {
        let c = MountCalibration(gravity: Vector3(0, -cos(rad(30)), -sin(rad(30))))!
        XCTAssertEqual(c.forward.dot(c.down), 0, accuracy: 1e-9)
        XCTAssertEqual(c.forward.length, 1, accuracy: 1e-9)
        XCTAssertLessThan(c.forward.z, 0)
        XCTAssertEqual(c.leanAngleDegrees(gravity: c.down), 0, accuracy: 1e-9)
    }
    func testFlatPhoneFallsBackToTopEdge() {
        let c = MountCalibration(gravity: Vector3(0, 0, -1))!
        XCTAssertEqual(c.forward, Vector3(0, 1, 0))
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(sin(rad(8)), 0, -cos(rad(8)))), 8, accuracy: 1e-6)
    }
    func testRejectsUnusableGravity() {
        XCTAssertNil(MountCalibration(gravity: Vector3(0, 0, 0)))
        XCTAssertNil(MountCalibration(gravity: Vector3(.nan, -1, 0)))
        let c = MountCalibration(gravity: Vector3(0, -1, 0))!
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(.nan, 0, 0)), 0)
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(0, 0, 0)), 0)
    }
}

final class LeanAngleEstimatorTests: XCTestCase {
    private func g(_ deg: Double) -> Vector3 { let r = deg * .pi / 180; return Vector3(sin(r), -cos(r), 0) }
    private func feed(_ e: inout LeanAngleEstimator, deg: Double, from t0: Double, seconds: Double) {
        var t = t0; while t < t0 + seconds { e.update(gravity: g(deg), timestamp: t); t += 0.02 }
    }
    func testConvergesAndReportsSide() {
        var e = LeanAngleEstimator(); XCTAssertTrue(e.calibrate(gravity: g(0)))
        feed(&e, deg: 8, from: 0, seconds: 2)
        XCTAssertEqual(e.angleDegrees, 8, accuracy: 0.1); XCTAssertEqual(e.side, .right)
        feed(&e, deg: -15, from: 2, seconds: 2)
        XCTAssertEqual(e.angleDegrees, -15, accuracy: 0.1); XCTAssertEqual(e.side, .left)
        XCTAssertEqual(e.maxRightDegrees, 8, accuracy: 0.1); XCTAssertEqual(e.maxLeftDegrees, 15, accuracy: 0.1)
    }
    func testUprightBelowOneDegree() {
        var e = LeanAngleEstimator(); e.calibrate(gravity: g(0)); feed(&e, deg: 0.5, from: 0, seconds: 1)
        XCTAssertEqual(e.side, .upright)
    }
    func testClampedTo60() {
        var e = LeanAngleEstimator(); e.calibrate(gravity: g(0)); feed(&e, deg: 80, from: 0, seconds: 2)
        XCTAssertEqual(e.angleDegrees, 60, accuracy: 1e-9); XCTAssertEqual(e.maxRightDegrees, 60, accuracy: 1e-9)
    }
    func testCalibrationOffsetAndRecalibration() {
        var e = LeanAngleEstimator(); e.calibrate(gravity: g(5)); feed(&e, deg: 5, from: 0, seconds: 1)
        XCTAssertEqual(e.angleDegrees, 0, accuracy: 0.05)
        feed(&e, deg: 25, from: 1, seconds: 2); XCTAssertEqual(e.maxRightDegrees, 20, accuracy: 0.1)
        e.calibrate(gravity: g(25)); XCTAssertEqual(e.maxRightDegrees, 0)
    }
    func testUncalibratedOrBadInputStaysZero() {
        var e = LeanAngleEstimator(); feed(&e, deg: 30, from: 0, seconds: 1)
        XCTAssertEqual(e.angleDegrees, 0)
        XCTAssertFalse(e.calibrate(gravity: Vector3(0, 0, 0))); XCTAssertNil(e.calibration)
        e.calibrate(gravity: g(0)); e.update(gravity: Vector3(.nan, 0, 0), timestamp: 5)
        XCTAssertTrue(e.angleDegrees.isFinite)
    }
    func testGapSnapsToNewValue() {
        var e = LeanAngleEstimator(); e.calibrate(gravity: g(0)); feed(&e, deg: 0, from: 0, seconds: 1)
        e.update(gravity: g(12), timestamp: 30)
        XCTAssertEqual(e.angleDegrees, 12, accuracy: 1e-6)
    }
}
```

- [ ] **Step 2 :** `swift test --filter "MountCalibrationTests|LeanAngleEstimatorTests"` → échec de compilation.
- [ ] **Step 3 :** implémenter les deux fichiers.
- [ ] **Step 4 :** mêmes tests → tout passe.
- [ ] **Step 5 :** commit « Ajoute la calibration du support et l'estimation d'inclinaison ».

---

### Task 4 : AccelerationAnalyzer

**Files :**
- Create : `ScooterCore/Sources/ScooterCore/AccelerationAnalyzer.swift`
- Test : `ScooterCore/Tests/ScooterCoreTests/AccelerationAnalyzerTests.swift`

**Produces :**

```swift
public enum AccelerationLevel: Sendable { case brakingHard, braking, stable, accelerating, acceleratingHard }
public struct AccelerationAnalyzer: Sendable {
    public init()
    public mutating func addSensor(timestamp: TimeInterval, longitudinal: Double)   // m/s², horloge mouvement
    public mutating func addGPSSpeed(timestamp: TimeInterval, speed: Double)        // m/s, horloge GPS
    public private(set) var current: Double
    public var level: AccelerationLevel { get }
    public static func level(for value: Double) -> AccelerationLevel
    public private(set) var history: [Double]      // au plus 120 valeurs, la plus récente en dernier
    public var peak: Double { get }                // max(0, max(history))
    public private(set) var tripPeak: Double       // maximum positif de current depuis init
    public var gaugePosition: Double { get }       // current / 4, borné à [-1, 1]
    public static let historyCapacity = 120
    public static let historyInterval = 0.25
}
```

Seuils : `<= -2.5` brakingHard, `<= -0.8` braking, `>= 2.5` acceleratingHard, `>= 0.8` accelerating, sinon stable.

Algorithme (non déterminé par les tests seuls) :

```
addSensor(t, a) :
    a non fini → ignoré
    sensorSum += a ; sensorCount += 1                     // pour la correction GPS
    fused = a − bias
    premier échantillon, dt <= 0 ou dt > 1 : current = fused ; nextHistoryTime = t
    sinon : current += (fused − current) × dt / (0,3 + dt)
    tripPeak = max(tripPeak, current)
    si t >= nextHistoryTime : ajouter current à history (retirer la tête au-delà de 120)
                              nextHistoryTime += 0,25 ; si nextHistoryTime <= t : nextHistoryTime = t + 0,25
addGPSSpeed(t, v) :
    v non fini ou < 0 → ignoré
    si un point GPS précédent existe, 0 < dt <= 5 et sensorCount > 0 :
        aGps  = (v − vPréc) / dt
        error = (sensorSum / sensorCount − bias) − aGps
        bias += error × dt / (2 + dt)
    mémoriser (t, v) ; sensorSum = 0 ; sensorCount = 0
```

Les deux horloges ne sont jamais soustraites l'une de l'autre.

- [ ] **Step 1 : écrire les tests**

```swift
final class AccelerationAnalyzerTests: XCTestCase {
    private func feed(_ a: inout AccelerationAnalyzer, _ value: Double, from t0: Double, seconds: Double) {
        let n = Int((seconds * 50).rounded()); for i in 0..<n { a.addSensor(timestamp: t0 + Double(i) * 0.02, longitudinal: value) }
    }
    func testLevels() {
        XCTAssertEqual(AccelerationAnalyzer.level(for: 2.8), .acceleratingHard)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 2.5), .acceleratingHard)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 1.0), .accelerating)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 0.79), .stable)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -0.79), .stable)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -0.8), .braking)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -2.5), .brakingHard)
    }
    func testConvergesWithoutGPS() {
        var a = AccelerationAnalyzer(); feed(&a, 0, from: 0, seconds: 1); feed(&a, 2.8, from: 1, seconds: 3)
        XCTAssertEqual(a.current, 2.8, accuracy: 0.02); XCTAssertEqual(a.level, .acceleratingHard)
        XCTAssertEqual(a.gaugePosition, 0.7, accuracy: 0.01)
    }
    func testHistoryIsThirtySecondWindow() {
        var a = AccelerationAnalyzer(); feed(&a, 1, from: 0, seconds: 10)
        XCTAssertEqual(a.history.count, 40)
        feed(&a, 1, from: 10, seconds: 40); XCTAssertEqual(a.history.count, 120)
    }
    func testPeakLeavesWindowButTripPeakStays() {
        var a = AccelerationAnalyzer(); feed(&a, 3.6, from: 0, seconds: 3); feed(&a, 1, from: 3, seconds: 5)
        XCTAssertEqual(a.peak, 3.6, accuracy: 0.05)
        feed(&a, 1, from: 8, seconds: 35)
        XCTAssertEqual(a.peak, 1, accuracy: 0.05); XCTAssertEqual(a.tripPeak, 3.6, accuracy: 0.05)
    }
    func testPeakIsNeverNegative() {
        var a = AccelerationAnalyzer(); XCTAssertEqual(a.peak, 0)
        feed(&a, -3, from: 0, seconds: 3); XCTAssertEqual(a.peak, 0); XCTAssertEqual(a.tripPeak, 0)
    }
    func testGaugeClamped() {
        var a = AccelerationAnalyzer(); feed(&a, 10, from: 0, seconds: 3); XCTAssertEqual(a.gaugePosition, 1)
        feed(&a, -10, from: 3, seconds: 3); XCTAssertEqual(a.gaugePosition, -1)
    }
    func testGPSRemovesSensorBias() {
        var a = AccelerationAnalyzer()
        for s in 0..<30 { a.addGPSSpeed(timestamp: 1000 + Double(s), speed: 10); feed(&a, 1.0, from: Double(s), seconds: 1) }
        XCTAssertEqual(a.current, 0, accuracy: 0.1)
    }
    func testGPSKeepsRealAcceleration() {
        var a = AccelerationAnalyzer()
        for s in 0..<30 { a.addGPSSpeed(timestamp: Double(s), speed: 2.0 * Double(s)); feed(&a, 2.0, from: Double(s), seconds: 1) }
        XCTAssertEqual(a.current, 2, accuracy: 0.1)
    }
    func testGapSnapsAndKeepsHistoryBounded() {
        var a = AccelerationAnalyzer(); feed(&a, 0, from: 0, seconds: 2)
        let before = a.history.count
        a.addSensor(timestamp: 500, longitudinal: 3)
        XCTAssertEqual(a.current, 3, accuracy: 1e-9); XCTAssertEqual(a.history.count, before + 1)
    }
    func testBadInputIgnored() {
        var a = AccelerationAnalyzer(); feed(&a, 1, from: 0, seconds: 2)
        a.addSensor(timestamp: 2, longitudinal: .nan); a.addGPSSpeed(timestamp: 0, speed: -1)
        a.addGPSSpeed(timestamp: 1, speed: .infinity); a.addGPSSpeed(timestamp: 5, speed: 3); a.addGPSSpeed(timestamp: 5, speed: 9)
        feed(&a, 1, from: 2.02, seconds: 1)
        XCTAssertEqual(a.current, 1, accuracy: 0.02)
    }
}
```

- [ ] **Step 2 :** `swift test --filter AccelerationAnalyzerTests` → échec de compilation.
- [ ] **Step 3 :** implémenter `AccelerationAnalyzer`.
- [ ] **Step 4 :** mêmes tests → tout passe.
- [ ] **Step 5 :** commit « Ajoute AccelerationAnalyzer ».

---

### Task 5 : TripSession et DemoTrip

**Files :**
- Create : `ScooterCore/Sources/ScooterCore/TripSession.swift`, `ScooterCore/Sources/ScooterCore/DemoTrip.swift`
- Test : `ScooterCore/Tests/ScooterCoreTests/TripSessionTests.swift`, `ScooterCore/Tests/ScooterCoreTests/DemoTripTests.swift`

**Interfaces — Consumes :** tout ce que produisent les tâches 1 à 4.

**Produces :**

```swift
public enum TripState: Sendable { case idle, recording, paused, finished }
public struct TripSummary: Sendable, Equatable {
    public var distanceMeters, maxSpeedKmh, averageSpeedKmh, peakAcceleration, maxLeanLeftDegrees, maxLeanRightDegrees: Double
    public var movingDuration, totalDuration: TimeInterval
}
public struct TripSession: Sendable {
    public init()
    public private(set) var state: TripState
    public private(set) var statistics: TripStatistics
    public private(set) var acceleration: AccelerationAnalyzer
    public private(set) var lean: LeanAngleEstimator
    public mutating func start(at time: TimeInterval)      // idle → recording, repart de zéro
    public mutating func pause(at time: TimeInterval)      // recording → paused
    public mutating func resume(at time: TimeInterval)     // paused → recording
    public mutating func finish(at time: TimeInterval)     // recording ou paused → finished
    public mutating func reset()                           // → idle, tout à zéro
    public mutating func recalibrate()                     // la prochaine MotionSample recalibre
    public mutating func handle(_ sample: LocationSample)
    public mutating func handle(_ sample: MotionSample)
    public func summary(at now: TimeInterval) -> TripSummary
}
public struct DemoTrip: Sendable {
    public init()
    public func location(at t: TimeInterval) -> LocationSample   // t = secondes depuis le début de la démo
    public func motion(at t: TimeInterval) -> MotionSample
}
```

Règles de `TripSession` :
- Toute transition non listée est sans effet.
- `handle` ne fait rien en `idle` et `finished`.
- En `recording` et `paused`, les `MotionSample` alimentent l'inclinaison et l'accélération (les capteurs restent actifs en pause). Les `LocationSample` alimentent `statistics` (qui les ignore en pause) et, si la vitesse est valide, `acceleration.addGPSSpeed`.
- La première `MotionSample` après `start` ou `recalibrate` calibre l'inclinaison. Si la calibration échoue, la suivante réessaie.
- L'accélération longitudinale vient de `lean.calibration.longitudinalAcceleration` ; sans calibration, la `MotionSample` n'alimente pas l'accélération.

`DemoTrip` : fonctions déterministes et continues de `t`. Départ `48.8566, 2.3522`, cap vers l'est. Vitesse `v(t) = 13 + 9·sin(t/11) + 4·sin(t/3.7)` bornée à `[0, 30]` m/s ; longitude par intégration analytique de la vitesse non bornée ; altitude `24 + 3·sin(t/40)` ; précision 5 m. Mouvement : gravité d'un téléphone droit incliné de `12·sin(t/6)` degrés ; `userAcceleration.z = −v'(t) / 9,80665`.

- [ ] **Step 1 : écrire les tests**

```swift
final class TripSessionTests: XCTestCase {
    private let up = Vector3(0, -1, 0)
    private func loc(_ t: Double, lon: Double, speed: Double = 10) -> LocationSample {
        LocationSample(timestamp: t, latitude: 0, longitude: lon, speed: speed, altitude: 24, horizontalAccuracy: 5)
    }
    private func mot(_ t: Double, lean deg: Double = 0, forwardG: Double = 0) -> MotionSample {
        let r = deg * .pi / 180
        return MotionSample(timestamp: t, gravity: Vector3(sin(r), -cos(r), 0), userAcceleration: Vector3(0, 0, -forwardG))
    }
    func testLifecycle() {
        var s = TripSession(); XCTAssertEqual(s.state, .idle)
        s.pause(at: 0); s.resume(at: 0); s.finish(at: 0); XCTAssertEqual(s.state, .idle)
        s.start(at: 0); XCTAssertEqual(s.state, .recording)
        s.start(at: 5); s.resume(at: 5); XCTAssertEqual(s.state, .recording)
        s.pause(at: 10); XCTAssertEqual(s.state, .paused)
        s.finish(at: 20); XCTAssertEqual(s.state, .finished)
        XCTAssertEqual(s.summary(at: 99).totalDuration, 10, accuracy: 1e-9)
        s.pause(at: 30); s.start(at: 30); XCTAssertEqual(s.state, .finished)
        s.reset(); XCTAssertEqual(s.state, .idle); XCTAssertEqual(s.summary(at: 0).totalDuration, 0)
    }
    func testIgnoresSamplesWhenIdleOrFinished() {
        var s = TripSession(); s.handle(loc(0, lon: 0)); s.handle(mot(0))
        XCTAssertTrue(s.statistics.route.isEmpty); XCTAssertNil(s.lean.calibration)
        s.start(at: 0); s.handle(loc(1, lon: 0)); s.finish(at: 2); s.handle(loc(3, lon: 0.001))
        XCTAssertEqual(s.statistics.route.count, 1)
    }
    func testFirstMotionSampleCalibratesThenFeedsBoth() {
        var s = TripSession(); s.start(at: 0)
        s.handle(mot(0, lean: 5))
        var t = 0.02; while t < 3 { s.handle(mot(t, lean: 13, forwardG: 0.2)); t += 0.02 }
        XCTAssertEqual(s.lean.angleDegrees, 8, accuracy: 0.2)
        XCTAssertEqual(s.acceleration.current, 1.96, accuracy: 0.05)
        s.recalibrate(); s.handle(mot(3, lean: 13)); s.handle(mot(3.02, lean: 13))
        XCTAssertEqual(s.lean.angleDegrees, 0, accuracy: 0.05)
    }
    func testFailedCalibrationRetries() {
        var s = TripSession(); s.start(at: 0)
        s.handle(MotionSample(timestamp: 0, gravity: Vector3(0, 0, 0), userAcceleration: Vector3(0, 0, 0)))
        XCTAssertNil(s.lean.calibration); XCTAssertEqual(s.acceleration.current, 0)
        s.handle(mot(0.02)); XCTAssertNotNil(s.lean.calibration)
    }
    func testPauseKeepsSensorsButFreezesStatistics() {
        var s = TripSession(); s.start(at: 0); s.handle(mot(0))
        s.handle(loc(0, lon: 0)); s.handle(loc(10, lon: 0.001)); s.pause(at: 10)
        s.handle(loc(20, lon: 0.002)); var t = 10.0; while t < 12 { s.handle(mot(t, lean: 10)); t += 0.02 }
        XCTAssertEqual(s.statistics.distanceMeters, 111.19, accuracy: 0.05)
        XCTAssertEqual(s.lean.angleDegrees, 10, accuracy: 0.2)
    }
    func testSummaryAndRestart() {
        var s = TripSession(); s.start(at: 0); s.handle(mot(0))
        s.handle(loc(0, lon: 0)); s.handle(loc(10, lon: 0.001, speed: 12))
        var t = 0.02; while t < 3 { s.handle(mot(t, lean: -9, forwardG: 0.3)); t += 0.02 }
        s.finish(at: 10); let r = s.summary(at: 50)
        XCTAssertEqual(r.distanceMeters, 111.19, accuracy: 0.05); XCTAssertEqual(r.maxSpeedKmh, 43.2, accuracy: 1e-9)
        XCTAssertEqual(r.maxLeanLeftDegrees, 9, accuracy: 0.2); XCTAssertEqual(r.maxLeanRightDegrees, 0)
        XCTAssertEqual(r.peakAcceleration, 2.94, accuracy: 0.05); XCTAssertEqual(r.totalDuration, 10, accuracy: 1e-9)
        s.reset(); s.start(at: 100)
        XCTAssertEqual(s.summary(at: 100), TripSummary(distanceMeters: 0, maxSpeedKmh: 0, averageSpeedKmh: 0, peakAcceleration: 0,
            maxLeanLeftDegrees: 0, maxLeanRightDegrees: 0, movingDuration: 0, totalDuration: 0))
    }
}

final class DemoTripTests: XCTestCase {
    func testSamplesStayPlausible() {
        let d = DemoTrip()
        for i in 0..<6000 {
            let t = Double(i) * 0.1; let l = d.location(at: t); let m = d.motion(at: t)
            XCTAssertEqual(l.timestamp, t); XCTAssertEqual(m.timestamp, t)
            XCTAssertTrue((0...30).contains(l.speed)); XCTAssertEqual(l.horizontalAccuracy, 5)
            XCTAssertEqual(m.gravity.length, 1, accuracy: 1e-9)
            XCTAssertLessThan(abs(m.userAcceleration.z) * 9.80665, 4)
        }
    }
    func testDrivesASessionEndToEnd() {
        let d = DemoTrip(); var s = TripSession(); s.start(at: 0)
        for i in 0..<3000 { let t = Double(i) * 0.02; s.handle(d.motion(at: t)); if i % 50 == 0 { s.handle(d.location(at: t)) } }
        let r = s.summary(at: 60)
        XCTAssertGreaterThan(r.distanceMeters, 300); XCTAssertLessThan(r.distanceMeters, 1800)
        XCTAssertGreaterThan(r.maxSpeedKmh, 30); XCTAssertLessThanOrEqual(r.maxSpeedKmh, 108)
        XCTAssertGreaterThan(r.maxLeanRightDegrees, 5); XCTAssertGreaterThan(r.peakAcceleration, 0.5)
        XCTAssertFalse(s.statistics.route.isEmpty)
    }
}
```

- [ ] **Step 2 :** `swift test --filter "TripSessionTests|DemoTripTests"` → échec de compilation.
- [ ] **Step 3 :** implémenter `TripSession.swift` et `DemoTrip.swift`.
- [ ] **Step 4 :** `swift test` (suite complète) → tout passe.
- [ ] **Step 5 :** commit « Ajoute TripSession et le trajet de démonstration ».

---

### Task 6 : Projet Xcode, thème et services

**Files :**
- Create : `ScooterPower.xcodeproj/project.pbxproj`, `Config/Info.plist`, `ScooterPower/App/ScooterPowerApp.swift`, `ScooterPower/App/Assets.xcassets/` (`Contents.json`, `AccentColor.colorset`, `AppIcon.appiconset`), `ScooterPower/Theme/Theme.swift`, `ScooterPower/Services/Providers.swift`, `LocationService.swift`, `MotionService.swift`, `DemoFeed.swift`

**Interfaces — Consumes :** `LocationSample`, `MotionSample`, `Vector3`, `DemoTrip`.

**Produces :**

```swift
enum LocationAuthorization { case notDetermined, denied, authorized }
@MainActor protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    var onAuthorizationChange: ((LocationAuthorization) -> Void)? { get set }
    var onSample: ((LocationSample) -> Void)? { get set }
    func requestAuthorization()
    func start()
    func stop()
}
@MainActor protocol MotionProviding: AnyObject {
    var isAvailable: Bool { get }
    var onSample: ((MotionSample) -> Void)? { get set }
    func start()
    func stop()
}
final class LocationService: NSObject, LocationProviding   // CLLocationManagerDelegate
final class MotionService: MotionProviding
final class DemoFeed: LocationProviding, MotionProviding   // authorization == .authorized, isAvailable == true

enum Theme {   // couleurs relevées sur la maquette
    static let background  = Color(hex: 0x000000)
    static let card        = Color(hex: 0x0E1114)
    static let cardBorder  = Color(hex: 0x1E2A30)
    static let cyan        = Color(hex: 0x19D3F3)
    static let orange      = Color(hex: 0xFF8A1F)
    static let red         = Color(hex: 0xE5484D)
    static let finish      = Color(hex: 0xD9534F)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xA0A6AD)
    static let gaugeIdle   = Color(hex: 0x4A4F55)
}
extension View { func cardStyle() -> some View }   // fond card, bord 1 pt, rayon 22
```

Décisions :
- **Horodatage** : `LocationService` utilise `CLLocation.timestamp.timeIntervalSinceReferenceDate` ; `MotionService` utilise `CMDeviceMotion.timestamp` (temps depuis le démarrage). `DemoFeed` utilise le temps écoulé depuis son `start()` pour les deux.
- **`LocationService`** : `desiredAccuracy = kCLLocationAccuracyBestForNavigation`, `activityType = .automotiveNavigation`, `distanceFilter = kCLDistanceFilterNone`, `pausesLocationUpdatesAutomatically = false`. `allowsBackgroundLocationUpdates = true` et `showsBackgroundLocationIndicator = true` dans `start()`, `false` dans `stop()`. `requestAuthorization()` appelle `requestWhenInUseAuthorization()`. `.restricted` et `.denied` → `.denied`.
- **`MotionService`** : `deviceMotionUpdateInterval = 1/50`, `startDeviceMotionUpdates(to: .main)`, `isAvailable = isDeviceMotionAvailable`.
- **`DemoFeed`** : un `Timer` à 50 Hz sur le run loop principal ; émet une `MotionSample` à chaque tic et une `LocationSample` tous les 50 tics.
- **`ScooterPowerApp`** : `WindowGroup { TripScreen() }`, `.preferredColorScheme(.dark)`. (`TripScreen` arrive en tâche 7 ; pour ce commit, un `Text("Scooter Power")` provisoire.)
- **`Config/Info.plist`** : uniquement `UIBackgroundModes = [location]`. Placé hors du dossier synchronisé pour ne pas être copié comme ressource.
- **Réglages de build** (cible, Debug et Release) : `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_FILE = Config/Info.plist`, `PRODUCT_BUNDLE_IDENTIFIER = com.brunotahiti.ScooterPower`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `TARGETED_DEVICE_FAMILY = 1`, `SWIFT_VERSION = 5.0`, `DEVELOPMENT_TEAM = ""`, `CODE_SIGN_STYLE = Automatic`, `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`, `INFOPLIST_KEY_CFBundleDisplayName = "Scooter Power"`, `INFOPLIST_KEY_UILaunchScreen_Generation = YES`, `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`, `INFOPLIST_KEY_UIRequiresFullScreen = YES`, et les quatre textes d'autorisation :
  - `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Scooter Power utilise votre position pour mesurer la vitesse, la distance et tracer votre trajet."`
  - `INFOPLIST_KEY_NSMotionUsageDescription = "Scooter Power utilise les capteurs de mouvement pour mesurer l'accélération et l'inclinaison."`
  - `INFOPLIST_KEY_NSCameraUsageDescription = "Scooter Power utilise l'appareil photo pour prendre des photos pendant le trajet."`
  - `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "Scooter Power enregistre vos photos de trajet dans votre photothèque."`
- **`.pbxproj`** : une cible application `ScooterPower` ; `PBXFileSystemSynchronizedRootGroup` sur `ScooterPower/` ; `XCLocalSwiftPackageReference` de chemin relatif `ScooterCore` ; `XCSwiftPackageProductDependency` `ScooterCore` liée dans la phase Frameworks ; phases Sources, Frameworks, Resources.

- [ ] **Step 1 :** écrire `Config/Info.plist`, le catalogue d'assets (AccentColor = cyan `#19D3F3`, AppIcon vide à une seule taille 1024) et `project.pbxproj`.
- [ ] **Step 2 : vérifier la structure du projet** par un script Python hors dépôt (dans le dossier scratchpad) qui analyse le format plist OpenStep et contrôle que : chaque identifiant de 24 caractères hexadécimaux référencé est défini dans `objects` ; `rootObject` est un `PBXProject` ; la cible a les trois phases ; la dépendance de package est présente dans `packageProductDependencies` et dans un `PBXBuildFile` de la phase Frameworks ; les deux `.plist`/`.json` sont bien formés.
  Attendu : `OK`, aucune référence orpheline.
- [ ] **Step 3 :** écrire `Theme.swift`, `Providers.swift`, les trois services et `ScooterPowerApp.swift`.
- [ ] **Step 4 : contrôle de syntaxe** (seule vérification possible sous Linux pour les fichiers qui importent des frameworks Apple) :

```bash
find ScooterPower -name '*.swift' -print0 | xargs -0 swiftc -frontend -parse
```
Attendu : aucune sortie, code de retour 0. Ce contrôle ne résout ni les types ni les imports.

- [ ] **Step 5 :** commit « Ajoute le projet Xcode, le thème et les services capteurs ».

---

### Task 7 : TripViewModel et interface

**Files :**
- Create : `ScooterPower/ViewModels/TripViewModel.swift` et tous les fichiers de `ScooterPower/Views/`
- Modify : `ScooterPower/App/ScooterPowerApp.swift` (remplacer le texte provisoire par `TripScreen()`)

**Interfaces — Consumes :** `TripSession`, `TripState`, `TripSummary`, `AccelerationLevel`, `LeanSide`, `Coordinate`, `Formatters`, `LocationProviding`, `MotionProviding`, `LocationService`, `MotionService`, `DemoFeed`, `Theme`.

**Produces :**

```swift
@MainActor @Observable final class TripViewModel {
    init()                                          // capteurs réels si MotionService().isAvailable, sinon DemoFeed
    init(location: LocationProviding, motion: MotionProviding, isDemo: Bool)

    private(set) var state: TripState
    private(set) var isDemo: Bool
    private(set) var locationDenied: Bool
    private(set) var gpsWeak: Bool                  // recording et vitesse courante nil

    // rafraîchis à 10 Hz par un Timer, uniquement quand state != .idle
    private(set) var speedKmh: Double?              // nil → "--"
    private(set) var speedText, maxSpeedText, averageSpeedText: String
    private(set) var distanceText, altitudeText: String
    private(set) var movingDurationText, totalDurationText: String
    private(set) var accelerationText: String       // "+2,8"
    private(set) var accelerationLevel: AccelerationLevel
    private(set) var gaugePosition: Double
    private(set) var accelerationHistory: [Double]
    private(set) var peakText: String               // "+3,6 m/s²"
    private(set) var leanDegrees: Double            // signé
    private(set) var leanText: String               // "8°"
    private(set) var leanSide: LeanSide
    private(set) var route: [Coordinate]
    private(set) var summary: TripSummary?          // non nil en .finished

    func start()
    func togglePause()
    func finish()
    func reset()
    func recalibrate()
}
```

Décisions :
- `start()` : si autorisation `.notDetermined`, la demander et démarrer dès qu'elle devient `.authorized` ; si `.denied`, `locationDenied = true` et rien d'autre. Au démarrage effectif : `session.start(at: now)`, démarrage des deux fournisseurs, `UIApplication.shared.isIdleTimerDisabled = true`. `finish()` et `reset()` le remettent à `false`.
- Horloge du view model pour `start/pause/resume/finish` et les durées : `Date().timeIntervalSinceReferenceDate` — la même que celle des `LocationSample`. En mode démo, l'horloge est celle de `DemoFeed`, exposée par une fermeture `now: () -> TimeInterval` passée à l'initialiseur complet.
- Les échantillons modifient `session` à leur cadence ; les propriétés observées ne sont recopiées qu'au tic 10 Hz, pour ne pas redessiner l'écran 50 fois par seconde.
- Textes : distance en km à 1 décimale (`"12,8 km"`), altitude en m sans décimale (`"24 m"`), vitesses sans décimale, valeurs absentes `"--"`.

Libellés (copie exacte) :

| Élément | Texte |
|---|---|
| Titre | `Prêt à partir` (idle), `Trajet en cours` (recording), `En pause` (paused), `Trajet terminé` (finished) |
| Pastille | `Enregistrement` (recording, point rouge), `En pause` (paused, point gris) ; absente sinon |
| Compteur | `GPS`, `km/h`, `Vitesse actuelle` ; graduations chiffrées 0, 20, 40, 60, 80, 100, 120, 140 |
| Cartes | `Vitesse maximale`, `Vitesse moyenne`, `Distance`, `Altitude`, `Durée de roulage`, `Durée totale` |
| Accélération | `Poussée d'accélération`, unité `m/s²`, `30 dernières secondes`, `Pic` |
| Niveaux | `Freinage fort`, `Freinage`, `Stable`, `Accélération`, `Accélération forte` |
| Jauge | `Freinage`, `Stable`, `Accélération` |
| Inclinaison | `Inclinaison`, `Vers la droite`, `Vers la gauche`, `Droit`, `Gauche`, `Droite` |
| Aide inclinaison | `En virage, l'angle affiché est inférieur à l'inclinaison réelle.` |
| Barre | `Carte`, `Photo`, `Démarrer le trajet`, `Terminer le trajet` |
| Menu ••• | `Recalibrer l'inclinaison` |
| Confirmation | titre `Terminer le trajet ?`, boutons `Terminer`, `Annuler` |
| Bandeaux | `Signal GPS faible`, `Données d'illustration` |
| Localisation refusée | `Scooter Power a besoin de votre position pour mesurer le trajet.` + bouton `Ouvrir Réglages` |
| Photo indisponible | `Appareil photo indisponible` |
| Résumé | titre `Résumé du trajet`, lignes `Distance`, `Durée de roulage`, `Durée totale`, `Vitesse maximale`, `Vitesse moyenne`, `Pic d'accélération`, `Inclinaison max. gauche`, `Inclinaison max. droite`, bouton `Nouveau trajet` |

Géométrie et couleurs :
- **`SpeedometerView(speedKmh: Double?)`** : arc de 200° ouvert vers le bas (de 190° à −10° en repère trigonométrique, 0 km/h à gauche), échelle 0–140. Graduations fines tous les 2 km/h, longues tous les 10. Partie parcourue en `Theme.cyan` avec halo, reste en `Theme.gaugeIdle`. Vitesse en police arrondie noire, taille 110, `contentTransition(.numericText())`. Vitesse au-delà de 140 : arc plein.
- **Jauge d'accélération** : 27 segments ; les 8 premiers `Theme.red`, les 7 centraux gris, les 12 derniers `Theme.orange` (atténués au-delà du curseur) ; curseur blanc cerclé d'orange placé à `gaugePosition`.
- **Graphe** : Swift Charts, `AreaMark` + `LineMark` orange, axe Y fixe de 0 à 4 avec repères `0,0`, `+2,0`, `+4,0` ; les valeurs négatives sont tracées à 0.
- **Couleur de la carte accélération** : orange pour les niveaux d'accélération, rouge pour les freinages, gris pour stable (valeur, libellé, chevrons).
- **`LeanCard`** : arc gradué de −45° à +45°, repère cyan à l'angle courant (borné à ±45 pour l'affichage), silhouette de scooter (`ScooterShapes`) pivotée de l'angle, verticale en pointillés.
- **`ScooterShapes`** : deux `Shape` dessinées en `Path` (scooter vu de dessus pour la carte accélération, vu de face pour l'inclinaison). Aucune image importée.
- **`BottomBar`** : en `idle`, bouton principal cyan `Démarrer le trajet` et pas de bouton pause ; sinon bouton `Theme.finish` et bouton rond pause / lecture.
- **`MapSheet`** : `Map` avec `MapPolyline` du tracé en cyan et `UserAnnotation()` ; feuille à détentes `.medium`, `.large`.
- **`CameraPicker`** : `UIViewControllerRepresentable` autour de `UIImagePickerController(sourceType: .camera)` ; à la prise, `UIImageWriteToSavedPhotosAlbum`. Si `isSourceTypeAvailable(.camera)` est faux, alerte au lieu de la feuille.
- **`TripScreen`** : `ScrollView` vertical sur fond `Theme.background`, barre du bas fixée par `safeAreaInset(edge: .bottom)`. Résumé présenté en `fullScreenCover` quand `state == .finished` ; sa fermeture appelle `reset()`.

- [ ] **Step 1 :** écrire `TripViewModel.swift`.
- [ ] **Step 2 :** écrire `ScooterShapes`, `SpeedometerView`, `StatCards`, `HeaderView`.
- [ ] **Step 3 :** écrire `AccelerationCard`, `LeanCard`.
- [ ] **Step 4 :** écrire `BottomBar`, `MapSheet`, `CameraPicker`, `SummaryView`, `TripScreen` ; brancher `TripScreen()` dans `ScooterPowerApp`.
- [ ] **Step 5 : contrôle de syntaxe** — même commande qu'en tâche 6, étape 4. Attendu : code de retour 0.
- [ ] **Step 6 : contrôle de cohérence avec `ScooterCore`** — vérifier par recherche que chaque symbole `ScooterCore` utilisé dans `ScooterPower/` existe avec la même orthographe dans `ScooterCore/Sources/` (les imports ne sont pas résolus par l'étape 5).
- [ ] **Step 7 :** commit « Ajoute le view model et l'interface du trajet ».

---

### Task 8 : README et vérification finale

**Files :**
- Create : `README.md`

- [ ] **Step 1 : `README.md`** — ce que fait l'app ; prérequis (Xcode 16+, iOS 17+, iPhone réel pour les capteurs) ; ouvrir `ScooterPower.xcodeproj`, choisir son équipe de signature, lancer ; fixer le téléphone au guidon avant de démarrer (la position au départ sert de zéro) ; limite de la mesure d'inclinaison en virage ; mode démo dans le simulateur ; `cd ScooterCore && swift test` ; mention explicite que l'app n'a pas été compilée dans Xcode par son auteur et que la première compilation peut demander des retouches.
- [ ] **Step 2 :** `cd ScooterCore && swift test` → tous les tests passent ; relancer le script de la tâche 6, étape 2, et le contrôle de syntaxe.
- [ ] **Step 3 :** commit « Ajoute le README », puis `git push -u origin claude/nice-shannon-289ops`.

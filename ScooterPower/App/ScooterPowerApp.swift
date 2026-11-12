import SwiftData
import SwiftUI

@main
struct ScooterPowerApp: App {
    var body: some Scene {
        WindowGroup {
            TripScreen()
        }
        .modelContainer(for: TripRecord.self)
    }
}

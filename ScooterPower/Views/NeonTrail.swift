import MapKit
import SwiftUI

/// Traînée lumineuse façon ruban de lumière des motos néon : halo large et
/// diffus, lueur colorée, trait vif et cœur blanc incandescent. Utilisée pour
/// toutes les traînées de l'app (trajet revu, balade de groupe, course).
enum NeonTrail {
    @MainActor @MapContentBuilder
    static func content(_ coordinates: [CLLocationCoordinate2D], color: Color, main: Bool = true) -> some MapContent {
        let scale: CGFloat = main ? 1 : 0.8
        if coordinates.count > 1 {
            MapPolyline(coordinates: coordinates)
                .stroke(color.opacity(0.16), style: StrokeStyle(lineWidth: 20 * scale, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: coordinates)
                .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: coordinates)
                .stroke(color, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: coordinates)
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round, lineJoin: .round))
        }
    }
}

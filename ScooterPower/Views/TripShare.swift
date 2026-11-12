import SwiftUI
import UIKit
import ScooterCore

/// Image de résumé d'un trajet, faite pour être partagée.
struct TripShareCard: View {
    let summary: TripSummary
    let route: [Coordinate]
    let title: String
    let units: UnitSystem

    private struct Figure: Identifiable {
        let id: Int
        let title: String
        let value: String
    }

    private var figures: [Figure] {
        let distance: String = Formatters.decimal(units.distance(fromMeters: summary.distanceMeters), digits: 1)
            + " " + units.distanceUnit
        let top: String = Formatters.decimal(units.speed(fromKmh: summary.maxSpeedKmh), digits: 0) + " " + units.speedUnit
        let average: String = Formatters.decimal(units.speed(fromKmh: summary.averageSpeedKmh), digits: 0)
            + " " + units.speedUnit
        let lean: String = Formatters.decimal(max(summary.maxLeanLeftDegrees, summary.maxLeanRightDegrees), digits: 0) + "°"
        var list: [(String, String)] = [
            (L("Distance"), distance),
            (L("Durée de roulage"), Formatters.duration(summary.movingDuration)),
            (L("Vitesse maximale"), top),
            (L("Vitesse moyenne"), average),
            (L("Pic d'accélération"), Formatters.signed(summary.peakAcceleration, digits: 1) + " m/s²"),
            (L("Inclinaison max."), lean),
        ]
        for interval in SpeedInterval.all {
            if let time = summary.best(interval) {
                list.append((interval.label + " km/h", Formatters.decimal(time, digits: 1) + " s"))
            }
        }
        var result: [Figure] = []
        for index in list.indices {
            result.append(Figure(id: index, title: list[index].0, value: list[index].1))
        }
        return result
    }

    /// Les chiffres deux par deux.
    private var pairs: [[Figure]] {
        let all: [Figure] = figures
        var result: [[Figure]] = []
        var index = 0
        while index < all.count {
            let end: Int = min(index + 2, all.count)
            result.append(Array(all[index..<end]))
            index += 2
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if route.count > 1 {
                RouteSketch(route: route)
                    .stroke(Theme.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            }
            grid
        }
        .padding(22)
        .frame(width: 360)
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "Scooter Power")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Theme.cyan)
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var grid: some View {
        VStack(spacing: 12) {
            ForEach(pairs.indices, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(pairs[row]) { figure in
                        cell(figure)
                    }
                    if pairs[row].count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cell(_ figure: Figure) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(figure.title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(figure.value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Le tracé dessiné sans carte, proportions conservées, nord en haut.
struct RouteSketch: Shape {
    let route: [Coordinate]

    func path(in rect: CGRect) -> Path {
        let points: [PlanePoint] = RouteProjector.unitPoints(route)
        var path = Path()
        guard points.count > 1 else { return path }
        let side: CGFloat = min(rect.width, rect.height)
        let originX: CGFloat = rect.midX - side / 2
        let originY: CGFloat = rect.midY - side / 2
        for index in points.indices {
            let x: CGFloat = originX + CGFloat(points[index].x) * side
            let y: CGFloat = originY + CGFloat(points[index].y) * side
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

/// Fabrique les fichiers à partager, dans le dossier temporaire.
@MainActor
enum TripExporter {
    static func imageFile(summary: TripSummary, route: [Coordinate], title: String) -> URL? {
        let card = TripShareCard(summary: summary, route: route, title: title, units: AppSettings.shared.units)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        return write(data, name: GPXExporter.fileName(for: title) + ".png")
    }

    static func gpxFile(route: [Coordinate], title: String, date: Date?) -> URL? {
        let text: String = GPXExporter.document(route: route, name: title, date: date)
        return write(Data(text.utf8), name: GPXExporter.fileName(for: title) + ".gpx")
    }

    private static func write(_ data: Data, name: String) -> URL? {
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Feuille de partage du système.
struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Bouton de partage d'un trajet : image du résumé ou tracé GPX.
struct ShareMenu: View {
    let summary: TripSummary
    let route: [Coordinate]
    let title: String
    let date: Date?

    private struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var shared: SharedFile?
    @State private var failed = false

    var body: some View {
        Menu {
            Button("Partager l'image du résumé", systemImage: "photo") {
                present(TripExporter.imageFile(summary: summary, route: route, title: title))
            }
            if route.count > 1 {
                Button("Exporter le tracé (GPX)", systemImage: "map") {
                    present(TripExporter.gpxFile(route: route, title: title, date: date))
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Partager")
        .sheet(item: $shared) { file in
            ActivityView(url: file.url)
        }
        .alert("Partage impossible", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func present(_ url: URL?) {
        if let url {
            shared = SharedFile(url: url)
        } else {
            failed = true
        }
    }
}

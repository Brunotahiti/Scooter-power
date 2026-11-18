import AVFoundation
import MapKit
import ScooterCore
import UIKit

/// Fabrique une vidéo verticale (1080 × 1920, 30 images/s) d'un trajet, prête
/// pour les réseaux sociaux : carte avec le tracé qui se dessine et le
/// scooter qui avance, compteur de vitesse, inclinaison, poussée et temps,
/// signature « Scooter Power ». Le trajet est accéléré pour durer au plus 20 s.
@MainActor
final class ReplayVideoExporter {
    enum ExportError: Error {
        case noRoute
        case writerFailed
    }

    static let width = 1080
    static let height = 1920
    static let fps: Int32 = 30
    static let maxSeconds: Double = 20
    private static let mapHeight: CGFloat = 1180

    private let replay: TripReplay
    private let title: String
    private let units: UnitSystem
    private let satellite: Bool

    init(replay: TripReplay, title: String, units: UnitSystem, satellite: Bool) {
        self.replay = replay
        self.title = title
        self.units = units
        self.satellite = satellite
    }

    /// Crée la vidéo et renvoie son fichier ; `progress` reçoit l'avancement de 0 à 1.
    func export(progress: @escaping (Double) -> Void) async throws -> URL {
        guard replay.route.count > 1 else { throw ExportError.noRoute }
        let snapshot: MKMapSnapshotter.Snapshot = try await mapSnapshot()
        let scooter: UIImage? = UIImage(named: "ScooterTop")
        let routePoints: [CGPoint] = replay.route.map { snapshot.point(for: $0.mapCoordinate) }

        let url: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(GPXExporter.fileName(for: title) + ".mp4")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Self.width,
            AVVideoHeightKey: Self.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Self.width,
                kCVPixelBufferHeightKey as String: Self.height,
            ])
        guard writer.canAdd(input) else { throw ExportError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let videoSeconds: Double = min(Self.maxSeconds, max(4, replay.duration))
        let frameCount: Int = Int(videoSeconds * Double(Self.fps))
        // Une seconde figée à la fin, sur le trajet complet.
        let holdFrames: Int = Int(Self.fps)
        for index in 0..<(frameCount + holdFrames) {
            let fraction: Double = min(1, Double(index) / Double(max(1, frameCount - 1)))
            let time: TimeInterval = fraction * replay.duration
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool,
                  let buffer = Self.makeBuffer(pool: pool, draw: { context in
                      self.drawFrame(in: context, snapshot: snapshot, routePoints: routePoints,
                                     scooter: scooter, time: time)
                  })
            else { throw ExportError.writerFailed }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: Self.fps))
            progress(Double(index + 1) / Double(frameCount + holdFrames))
            if index % 10 == 0 { await Task.yield() }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writerFailed }
        return url
    }

    // MARK: - Carte

    private func mapSnapshot() async throws -> MKMapSnapshotter.Snapshot {
        let options = MKMapSnapshotter.Options()
        options.size = CGSize(width: CGFloat(Self.width), height: Self.mapHeight)
        options.scale = 1
        options.region = Self.region(for: replay.route, aspect: CGFloat(Self.width) / Self.mapHeight)
        options.preferredConfiguration = satellite
            ? MKHybridMapConfiguration(elevationStyle: .flat)
            : MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.pointOfInterestFilter = .excludingAll
        return try await MKMapSnapshotter(options: options).start()
    }

    /// Région qui contient tout le tracé avec une marge, aux proportions de l'image.
    private static func region(for route: [Coordinate], aspect: CGFloat) -> MKCoordinateRegion {
        let lats: [Double] = route.map(\.latitude)
        let lons: [Double] = route.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        var latSpan: Double = max(0.003, (lats.max()! - lats.min()!) * 1.35)
        var lonSpan: Double = max(0.003, (lons.max()! - lons.min()!) * 1.35)
        // Proportions de l'image (en tenant compte de la latitude).
        let lonPerLat: Double = 1 / max(0.2, cos(center.latitude * .pi / 180))
        if lonSpan / lonPerLat / latSpan < Double(aspect) {
            lonSpan = latSpan * Double(aspect) * lonPerLat
        } else {
            latSpan = lonSpan / lonPerLat / Double(aspect)
        }
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan))
    }

    // MARK: - Dessin d'une image

    private static func makeBuffer(pool: CVPixelBufferPool, draw: (CGContext) -> Void) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        // Repère UIKit : origine en haut à gauche.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        draw(context)
        UIGraphicsPopContext()
        return buffer
    }

    private func drawFrame(in context: CGContext, snapshot: MKMapSnapshotter.Snapshot, routePoints: [CGPoint],
                           scooter: UIImage?, time: TimeInterval) {
        let width = CGFloat(Self.width)
        let height = CGFloat(Self.height)
        let frame: ReplayFrame? = replay.frame(at: time)
        let speedValue: Double = units.speed(fromKmh: frame?.speedKmh ?? 0)
        let accent: UIColor = UIColor(SpeedBar.color(at: min(1, speedValue / units.speedometerMax)))
        let red = UIColor(red: 1, green: 0.18, blue: 0.18, alpha: 1)

        UIColor.black.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Carte et tracé.
        snapshot.image.draw(in: CGRect(x: 0, y: 0, width: width, height: Self.mapHeight))
        strokeRoute(routePoints, in: context, color: UIColor.white.withAlphaComponent(0.35), width: 6, glow: nil)
        if let frame {
            let end: Int = min(frame.index, routePoints.count - 1)
            var done: [CGPoint] = Array(routePoints[0...end])
            let position: CGPoint = snapshot.point(for: frame.coordinate.mapCoordinate)
            done.append(position)
            // Ruban de lumière : halo, lueur, trait vif et cœur blanc.
            strokeRoute(done, in: context, color: accent.withAlphaComponent(0.25), width: 34, glow: accent)
            strokeRoute(done, in: context, color: accent, width: 12, glow: accent)
            strokeRoute(done, in: context, color: UIColor.white.withAlphaComponent(0.95), width: 3.5, glow: nil)
            drawScooter(scooter, at: position, heading: frame.heading, lean: frame.leanDegrees,
                        tint: accent, in: context)
        }
        // Fondu de la carte vers le panneau du bas.
        let fadeColors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fadeColors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient, start: CGPoint(x: 0, y: Self.mapHeight - 260), end: CGPoint(x: 0, y: Self.mapHeight),
                options: [])
        }

        // Titre en haut.
        drawText("Scooter Power", at: CGPoint(x: 60, y: 70), size: 64, weight: .black, color: .white,
                 italic: true, shadow: red)
        drawText(title, at: CGPoint(x: 62, y: 150), size: 34, weight: .semibold,
                 color: UIColor.white.withAlphaComponent(0.85))

        // Compteur.
        let speedText: String = Formatters.decimal(speedValue, digits: 0)
        let speedSize: CGSize = drawText(speedText, at: CGPoint(x: 60, y: 1210), size: 260, weight: .black,
                                         color: .white, italic: true, shadow: accent)
        drawText(units.speedUnit, at: CGPoint(x: 80 + speedSize.width, y: 1385), size: 70, weight: .heavy,
                 color: accent, italic: true)
        let barRect = CGRect(x: 60, y: 1530, width: width - 120, height: 26)
        UIColor.white.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: barRect, cornerRadius: 13).fill()
        accent.setFill()
        let filled: CGFloat = barRect.width * CGFloat(min(1, speedValue / units.speedometerMax))
        UIBezierPath(roundedRect: CGRect(x: barRect.minX, y: barRect.minY, width: max(26, filled), height: barRect.height),
                     cornerRadius: 13).fill()

        // Chiffres du moment.
        let lean: String = Formatters.decimal(abs(frame?.leanDegrees ?? 0), digits: 0) + "°"
        let thrust: String = Formatters.signed(frame?.acceleration ?? 0, digits: 1) + " m/s²"
        let elapsed: String = Formatters.duration(time)
        let columns: [(String, String)] = [(L("Inclinaison"), lean), (L("Poussée"), thrust), (L("Temps"), elapsed)]
        for (index, column) in columns.enumerated() {
            let x: CGFloat = 60 + CGFloat(index) * (width - 120) / 3
            drawText(column.0, at: CGPoint(x: x, y: 1610), size: 34, weight: .medium,
                     color: UIColor.white.withAlphaComponent(0.7))
            drawText(column.1, at: CGPoint(x: x, y: 1660), size: 58, weight: .heavy, color: .white, italic: true)
        }
        drawText(L("Fait avec Scooter Power"), at: CGPoint(x: 60, y: 1810), size: 32, weight: .semibold,
                 color: UIColor(red: 0.1, green: 0.83, blue: 0.95, alpha: 1))
    }

    private func strokeRoute(_ points: [CGPoint], in context: CGContext, color: UIColor, width: CGFloat, glow: UIColor?) {
        guard points.count > 1 else { return }
        let path = UIBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        context.saveGState()
        if let glow { context.setShadow(offset: .zero, blur: 24, color: glow.cgColor) }
        color.setStroke()
        path.stroke()
        context.restoreGState()
    }

    private func drawScooter(_ image: UIImage?, at point: CGPoint, heading: Double, lean: Double,
                             tint: UIColor, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: CGFloat(heading * .pi / 180))
        // Plus fin quand il penche, comme vu du dessus.
        context.scaleBy(x: 1 - 0.3 * CGFloat(min(45, abs(lean)) / 45), y: 1)
        context.setShadow(offset: .zero, blur: 30, color: tint.cgColor)
        let size = CGSize(width: 70, height: 140)
        if let image {
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        } else {
            tint.setFill()
            UIBezierPath(ovalIn: CGRect(x: -20, y: -20, width: 40, height: 40)).fill()
        }
        context.restoreGState()
    }

    @discardableResult
    private func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, color: UIColor,
                          italic: Bool = false, shadow: UIColor? = nil) -> CGSize {
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        if italic, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let shadow {
            let s = NSShadow()
            s.shadowColor = shadow.withAlphaComponent(0.8)
            s.shadowBlurRadius = size * 0.15
            s.shadowOffset = .zero
            attributes[.shadow] = s
        }
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: point)
        return string.size()
    }
}

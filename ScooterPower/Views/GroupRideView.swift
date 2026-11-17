import MapKit
import SwiftUI
import VisionKit
import ScooterCore

/// Balade de groupe : jusqu'à 5 pilotes sur la même carte, en direct.
/// Avant la balade : créer un groupe ou scanner un QR code. Pendant : la
/// carte de nuit avec les scooters et leurs traînées colorées, une carte
/// par pilote avec sa vitesse, et les boutons Inviter et Quitter.
struct GroupRideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = GroupRideService.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var showInvite = false
    @State private var showScanner = false
    /// Fond de carte en photo satellite plutôt qu'en plan.
    @AppStorage(TripMapStyle.storageKey) private var satellite = false

    /// Couleur de chaque place, dans l'ordre d'arrivée.
    static let colors: [Color] = [
        Color(hex: 0xFF2D2D), Color(hex: 0x19D3F3), Color(hex: 0x39E85A), Color(hex: 0xFFD21A), Color(hex: 0xB45CFF),
    ]

    static func color(_ index: Int) -> Color {
        colors[min(max(0, index), colors.count - 1)]
    }

    private static let red: Color = SpeedometerView.neonRed

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if service.isInRide {
                    rideContent
                } else {
                    lobby
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showInvite) {
            if let link = service.link {
                RideInviteSheet(link: link)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            RideScannerView { link in
                showScanner = false
                service.join(link)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            CarbonTexture()
                .opacity(0.18)
            RadialGradient(
                colors: [Self.red.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 320)
            RadialGradient(
                colors: [Self.red.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 1), startRadius: 10, endRadius: 300)
        }
    }

    // MARK: - En-tête

    private var subtitle: String {
        let count: Int = service.riders.count
        if !service.isInRide { return L("Jusqu'à 5 pilotes sur la même carte") }
        return count <= 1 ? L("1 pilote connecté") : L("\(String(count)) pilotes connectés")
    }

    private var header: some View {
        let shape = HexagonFrame(tip: 22)
        return HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Fermer")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    NeonSlashes()
                    Text("Balade de groupe")
                        .font(.system(size: 28, weight: .black))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
            }
            Spacer(minLength: 0)
            Color.clear.frame(width: 36, height: 36)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75), in: shape)
        .overlay(shape.stroke(Self.red, lineWidth: 1.8))
        .shadow(color: Self.red.opacity(0.7), radius: 10)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Avant la balade

    private var lobby: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            LobbyIllustration()
                .frame(height: 220)
            Text("Roulez ensemble et voyez où sont vos amis, en direct.")
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            Text("Le premier crée la balade et montre son QR code ; les autres le scannent. Les positions passent par iCloud et sont effacées quand vous quittez la balade.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            statusMessage
            Spacer(minLength: 0)
            NeonPillButton(title: L("Créer une balade"), icon: "plus.circle.fill") {
                service.create()
            }
            .disabled(service.phase == .connecting)
            DarkPillButton(title: L("Scanner un QR code"), icon: "qrcode.viewfinder") {
                showScanner = true
            }
            .disabled(service.phase == .connecting)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch service.phase {
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                Text("Connexion à la balade…")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.cyan)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.orange)
                .multilineTextAlignment(.center)
        case .idle, .active:
            EmptyView()
        }
    }

    // MARK: - Pendant la balade

    private var rideContent: some View {
        VStack(spacing: 10) {
            map
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Self.red.opacity(0.8), lineWidth: 1.5))
                .shadow(color: Self.red.opacity(0.5), radius: 8)
                .overlay(alignment: .top) { waitingBanner }
                .overlay(alignment: .topTrailing) { fitButton }
                .padding(.horizontal, 8)
                .padding(.top, 10)
            riderCards
                .padding(.horizontal, 8)
            HStack(spacing: 12) {
                NeonPillButton(title: L("Inviter par QR code"), icon: "qrcode") {
                    showInvite = true
                }
                DarkPillButton(title: L("Quitter"), icon: nil) {
                    service.leave()
                }
                .frame(width: 112)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(service.riders) { rider in
                RideMapContent.trail(rider)
            }
            ForEach(service.riders) { rider in
                if let spot = rider.position {
                    Annotation("", coordinate: spot.coordinate.mapCoordinate, anchor: .bottom) {
                        RiderMarker(rider: rider, position: spot)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(TripMapStyle.style(satellite: satellite))
        .mapControls { MapCompass() }
    }

    @ViewBuilder
    private var waitingBanner: some View {
        let mine = service.riders.first(where: { $0.isMe })
        if mine?.position == nil {
            Text("Démarrez le trajet pour que les autres vous voient.")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.75), in: Capsule())
                .overlay(Capsule().stroke(Theme.orange, lineWidth: 1))
                .foregroundStyle(Theme.orange)
                .padding(.top, 10)
        }
    }

    private var fitButton: some View {
        VStack(spacing: 8) {
            SatelliteToggle(satellite: $satellite)
            Button {
                withAnimation(.easeInOut(duration: 0.5)) { position = .automatic }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.7), in: Circle())
            }
            .accessibilityLabel("Voir tous les pilotes")
        }
        .padding(10)
        .padding(.top, 34)
    }

    private var riderCards: some View {
        HStack(spacing: 6) {
            ForEach(service.riders) { rider in
                RiderCard(rider: rider)
            }
        }
        .frame(height: 74)
    }
}

// MARK: - Carte

/// Traînée lumineuse d'un pilote : un large trait translucide sous un trait vif.
enum RideMapContent {
    @MainActor @MapContentBuilder
    static func trail(_ rider: GroupRideService.Rider) -> some MapContent {
        let color: Color = GroupRideView.color(rider.colorIndex)
        let points: [CLLocationCoordinate2D] = trailPoints(rider)
        if points.count > 1 {
            MapPolyline(coordinates: points)
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: points)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

extension RideMapContent {
    /// Traînée du pilote, prolongée jusqu'à sa position actuelle.
    static func trailPoints(_ rider: GroupRideService.Rider) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = rider.trail.points.map(\.mapCoordinate)
        if let spot = rider.position {
            points.append(spot.coordinate.mapCoordinate)
        }
        return points
    }
}

/// Étiquette du prénom au-dessus du scooter vu du dessus.
private struct RiderMarker: View {
    let rider: GroupRideService.Rider
    let position: RiderPosition

    var body: some View {
        let color: Color = GroupRideView.color(rider.colorIndex)
        let stale: Bool = position.isStale(at: Date())
        let frame = ReplayFrame(
            coordinate: position.coordinate, heading: position.heading, speedKmh: position.speedKmh,
            acceleration: position.acceleration, leanDegrees: position.leanDegrees, time: 0, index: 0)
        return VStack(spacing: 0) {
            NameTag(name: displayName, color: color)
            TopViewScooter(frame: frame, rotation: position.heading, tint: color)
                .scaleEffect(0.8)
                .frame(width: 60, height: 60)
        }
        .opacity(stale ? 0.45 : 1)
    }

    private var displayName: String {
        rider.isMe ? L("Moi") : (position.name.isEmpty ? L("Pilote") : position.name)
    }
}

struct NameTag: View {
    let name: String
    let color: Color

    var body: some View {
        let shape = HexagonFrame(tip: 7)
        return VStack(spacing: 0) {
            Text(verbatim: name)
                .font(.system(size: 13, weight: .heavy))
                .italic()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85), in: shape)
                .overlay(shape.stroke(color, lineWidth: 1.6))
                .shadow(color: color.opacity(0.8), radius: 5)
            Triangle()
                .fill(color)
                .frame(width: 10, height: 6)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cartes des pilotes

private struct RiderCard: View {
    let rider: GroupRideService.Rider

    private var units: UnitSystem { AppSettings.shared.units }

    var body: some View {
        let color: Color = GroupRideView.color(rider.colorIndex)
        let shape = HexagonFrame(tip: 9)
        let stale: Bool = rider.position.map { $0.isStale(at: Date()) } ?? true
        let speed: String = rider.position.map {
            Formatters.decimal(units.speed(fromKmh: $0.speedKmh), digits: 0)
        } ?? "--"
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color, radius: 3)
                Text(verbatim: name)
                    .font(.system(size: 12, weight: .bold))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Rectangle()
                .fill(color.opacity(0.35))
                .frame(height: 1)
                .padding(.horizontal, 6)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: stale ? "--" : speed)
                    .font(.system(size: 22, weight: .black))
                    .italic()
                    .monospacedDigit()
                Text(verbatim: units.speedUnit)
                    .font(.system(size: 9, weight: .bold))
                    .italic()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8), in: shape)
        .overlay(shape.stroke(SpeedometerView.neonRed.opacity(0.9), lineWidth: 1.4))
        .shadow(color: SpeedometerView.neonRed.opacity(0.45), radius: 5)
        .opacity(stale ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(stale ? L("hors ligne") : speed + " " + units.speedUnit)
    }

    private var name: String {
        if rider.isMe { return L("Moi") }
        let raw: String = rider.position?.name ?? ""
        return raw.isEmpty ? L("Pilote") : raw
    }
}

// MARK: - Boutons et décor

struct NeonSlashes: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(SpeedometerView.neonRed.opacity(1 - 0.2 * Double(index)))
                    .frame(width: 7, height: 22)
                    .rotationEffect(.degrees(25))
            }
        }
        .shadow(color: SpeedometerView.neonRed, radius: 4)
        .accessibilityHidden(true)
    }
}

private struct NeonPillButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        let red: Color = SpeedometerView.neonRed
        let fill = LinearGradient(
            colors: [Color(hex: 0xFF4A3D), Color(hex: 0xA80F0F)], startPoint: .top, endPoint: .bottom)
        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(fill, in: Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xFF8A80), lineWidth: 1.5))
            .shadow(color: red.opacity(0.8), radius: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct DarkPillButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(hex: 0x1A1D21), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

/// Cinq scooters vus du dessus, chacun avec sa couleur, en éventail.
private struct LobbyIllustration: View {
    var body: some View {
        // Cinq colonnes de même largeur : l'illustration tient toujours dans l'écran.
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                let color: Color = GroupRideView.color(index)
                let offset: CGFloat = CGFloat(abs(index - 2)) * 22
                TopViewScooter(
                    frame: ReplayFrame(
                        coordinate: Coordinate(latitude: 0, longitude: 0), heading: 0, speedKmh: 70,
                        acceleration: 1, leanDegrees: 0, time: 0, index: 0),
                    rotation: 0, tint: color)
                    .scaleEffect(1.1)
                    .offset(y: offset)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Inviter

/// QR code de la balade, à scanner par les autres pilotes.
struct RideInviteSheet: View {
    let link: RideLink
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image = MyCardSheet.qrImage(link.url.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: 300)
                        .shadow(color: SpeedometerView.neonRed.opacity(0.7), radius: 16)
                        .accessibilityLabel("QR code de la balade")
                }
                Text(verbatim: link.rideID)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                Text("Les autres pilotes scannent ce code avec l'appareil photo de l'iPhone, ou dans Scooter Power → Balade de groupe → Scanner un QR code. 5 pilotes au maximum.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                ShareLink(item: link.url) {
                    Label("Envoyer le lien", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Inviter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }
}

// MARK: - Scanner

/// Scanner de QR code intégré : rejoint la balade dès qu'un code valide est lu.
struct RideScannerView: View {
    let onFound: (RideLink) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                QRScanner(onFound: onFound)
                    .ignoresSafeArea()
            } else {
                Text("Le scanner n'est pas disponible. Autorisez l'appareil photo dans Réglages → Scooter Power, ou scannez le code avec l'app Appareil photo.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(30)
                    .frame(maxHeight: .infinity)
            }
            HStack {
                Text("Visez le QR code de la balade")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Fermer")
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct QRScanner: UIViewControllerRepresentable {
    let onFound: (RideLink) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (RideLink) -> Void
        private var done = false

        init(onFound: @escaping (RideLink) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let text = barcode.payloadStringValue,
                      let url = URL(string: text),
                      let link = RideLink(url: url)
                else { continue }
                done = true
                onFound(link)
                return
            }
        }
    }
}

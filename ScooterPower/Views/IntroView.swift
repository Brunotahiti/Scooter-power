import AVFoundation
import SwiftUI

/// Animation d'ouverture : la vidéo « IntroScooter.mp4 » (sans son), puis le
/// nom de l'app qui apparaît en néon. Un toucher la passe. Si la vidéo est
/// absente du bundle ou si « Réduire les animations » est activé, seul le
/// titre s'affiche, brièvement.
struct IntroView: View {
    let onFinish: () -> Void

    static let videoName = "IntroScooter"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var showTitle = false
    @State private var finished = false

    private static let red: Color = SpeedometerView.neonRed

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                IntroPlayerView(player: player)
                    .ignoresSafeArea()
            }
            title
                .opacity(showTitle ? 1 : 0)
                .scaleEffect(showTitle ? 1 : 1.25)
                .blur(radius: showTitle ? 0 : 8)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Scooter Power"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
        .task { await start() }
        .statusBarHidden()
    }

    private var title: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Rectangle()
                            .fill(Self.red.opacity(1 - 0.2 * Double(index)))
                            .frame(width: 8, height: 30)
                            .rotationEffect(.degrees(25))
                    }
                }
                Text(verbatim: "Scooter Power")
                    .font(.system(size: 40, weight: .black))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xC9CED6), Color.white],
                            startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: Self.red, radius: 14)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Self.red, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 260, height: 2)
                .shadow(color: Self.red, radius: 6)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 120)
    }

    @MainActor
    private func start() async {
        guard !reduceMotion,
              let url = Bundle.main.url(forResource: Self.videoName, withExtension: "mp4")
        else {
            withAnimation(.easeOut(duration: 0.4)) { showTitle = true }
            try? await Task.sleep(for: .seconds(1.2))
            finish()
            return
        }
        // Ne coupe pas la musique que l'utilisateur écoute.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let player = AVPlayer(url: url)
        player.isMuted = true
        self.player = player
        player.play()
        let duration: Double = (try? await player.currentItem?.asset.load(.duration).seconds) ?? 5
        let total: Double = duration.isFinite && duration > 0 ? duration : 5
        // Le titre apparaît pendant la dernière seconde et demie.
        try? await Task.sleep(for: .seconds(max(0, total - 1.6)))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showTitle = true }
        try? await Task.sleep(for: .seconds(1.9))
        finish()
    }

    @MainActor
    private func finish() {
        guard !finished else { return }
        finished = true
        player?.pause()
        onFinish()
    }
}

/// Lecteur vidéo sans commandes, qui remplit l'écran.
private struct IntroPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

import Combine
import MessageUI
import SwiftUI

/// Alerte de chute : compte à rebours de 30 s, « Je vais bien » pour annuler ;
/// à zéro (ou sur demande), le SMS aux contacts d'urgence est prêt à partir
/// avec la position. iOS impose que l'envoi soit confirmé d'un geste.
struct CrashAlertView: View {
    let alert: CrashAlert
    let onDismiss: () -> Void

    static let countdownSeconds = 30

    @State private var remaining: Int = CrashAlertView.countdownSeconds
    @State private var showMessage = false
    @State private var messageSent = false
    @State private var pulse = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let settings = AppSettings.shared
    private static let red = Color(hex: 0xFF2D2D)

    private var recipients: [String] { settings.emergencyContacts.map(\.phone) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Self.red.opacity(pulse ? 0.55 : 0.3), Color.black],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            VStack(spacing: 22) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Self.red)
                    .shadow(color: Self.red, radius: 18)
                Text(L("Chute détectée ?"))
                    .font(.system(size: 34, weight: .black))
                    .italic()
                Text(statusText)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                if !messageSent {
                    Text(verbatim: String(remaining))
                        .font(.system(size: 96, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(Self.red)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                Button {
                    CrashLog.shared.resolve(id: alert.id, outcome: .fine)
                    onDismiss()
                } label: {
                    Text(L("Je vais bien"))
                        .font(.system(size: 26, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .foregroundStyle(Color.black)
                        .background(Color(hex: 0x39E85A), in: Capsule())
                }
                HStack(spacing: 12) {
                    if !recipients.isEmpty && MFMessageComposeViewController.canSendText() {
                        alertButton(title: L("Prévenir"), icon: "message.fill") { sendAlert() }
                    }
                    alertButton(title: L("Appel d'urgence"), icon: "phone.fill") { callEmergency() }
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .onAppear { pulse = true }
        .onReceive(ticker) { _ in tick() }
        .sheet(isPresented: $showMessage) {
            MessageComposer(recipients: recipients, body: alert.message) { sent in
                showMessage = false
                if sent { messageSent = true }
                CrashAlarm.shared.stop()
            }
            .ignoresSafeArea()
        }
    }

    private var statusText: String {
        if messageSent { return L("Vos contacts ont été prévenus avec votre position.") }
        if recipients.isEmpty {
            return L("Aucun contact d'urgence enregistré. Ajoutez-en dans les réglages.")
        }
        return L("Sans réponse, le message d'alerte avec votre position sera prêt à envoyer à vos contacts.")
    }

    private func alertButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(Color.white)
                .background(Self.red, in: Capsule())
        }
    }

    private func tick() {
        guard !messageSent, !showMessage, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 { sendAlert() }
    }

    private func sendAlert() {
        guard !recipients.isEmpty, MFMessageComposeViewController.canSendText() else { return }
        CrashLog.shared.resolve(id: alert.id, outcome: .alerted)
        showMessage = true
    }

    private func callEmergency() {
        CrashLog.shared.resolve(id: alert.id, outcome: .alerted)
        // 112 fonctionne sur tous les réseaux mobiles du monde (renvoyé vers le numéro local).
        if let url = URL(string: "tel://112") {
            UIApplication.shared.open(url)
        }
    }
}

/// Fenêtre d'envoi de SMS d'iOS, déjà remplie.
private struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
        }
    }
}

import SwiftUI
import ScooterCore

/// Réglage et lien de la position en direct pour les proches.
struct LiveShareView: View {
    private let service = LiveShareService.shared
    @State private var confirmRenew = false

    private var enabled: Binding<Bool> {
        Binding(get: { service.isEnabled }, set: { value in
            service.setEnabled(value)
            if value { CrashAlarm.requestNotificationPermission() }
        })
    }

    private var message: String {
        let address: String = service.link?.absoluteString ?? ""
        return L("Suis mon trajet en scooter en direct : \(address)")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("Vos proches suivent vos trajets"), systemImage: "location.fill.viewfinder")
                        .font(.headline)
                        .foregroundStyle(Theme.cyan)
                    Text(L("Donnez-leur une fois ce lien : pendant chaque trajet, ils voient votre position sur une carte, votre vitesse et votre tracé, puis « Bien arrivé ». En cas de chute détectée, la page passe en alerte. Ils n'ont pas besoin de l'app."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 4)
                Toggle(L("Partager mes trajets en direct"), isOn: enabled)
                    .tint(Theme.cyan)
            }

            if service.isEnabled, let link = service.link {
                Section {
                    Text(verbatim: link.absoluteString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                    ShareLink(item: link, message: Text(verbatim: message)) {
                        Label(L("Envoyer le lien à mes proches"), systemImage: "paperplane.fill")
                    }
                    Button(L("Nouveau lien"), systemImage: "arrow.triangle.2.circlepath") { confirmRenew = true }
                } header: {
                    Text(L("Lien de suivi"))
                } footer: {
                    Text(L("Toute personne qui a ce lien voit vos trajets en cours. « Nouveau lien » désactive l'ancien."))
                }
                Section {
                    HStack {
                        Circle()
                            .fill(service.isLive ? Color.red : Theme.textSecondary)
                            .frame(width: 10, height: 10)
                        Text(service.isLive ? L("En direct") : L("Aucun trajet en cours"))
                        Spacer()
                        if let sent = service.lastSent {
                            Text(sent, style: .relative)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if service.failed {
                        Text(L("Envoi impossible : vérifiez la connexion et la session iCloud."))
                            .font(.footnote)
                            .foregroundStyle(Theme.orange)
                    }
                } header: {
                    Text(L("État"))
                }
            }
        }
        .navigationTitle(L("Position en direct"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("Créer un nouveau lien ?"), isPresented: $confirmRenew, titleVisibility: .visible) {
            Button(L("Nouveau lien"), role: .destructive) { service.renewLink() }
        } message: {
            Text(L("L'ancien lien ne montrera plus rien. Il faudra envoyer le nouveau à vos proches."))
        }
    }
}

/// La même page, dans une feuille ouverte depuis le menu.
struct LiveShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LiveShareView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("Fermer")) { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

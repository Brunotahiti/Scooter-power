import SwiftUI

/// Couleurs relevées sur la maquette.
enum Theme {
    static let background = Color(hex: 0x000000)
    static let card = Color(hex: 0x0E1114)
    static let cardBorder = Color(hex: 0x1E2A30)
    static let cyan = Color(hex: 0x19D3F3)
    static let orange = Color(hex: 0xFF8A1F)
    static let red = Color(hex: 0xE5484D)
    static let finish = Color(hex: 0xD9534F)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xA0A6AD)
    static let gaugeIdle = Color(hex: 0x4A4F55)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

extension View {
    /// Fond et liseré communs à toutes les cartes de l'écran. `tint` colore le
    /// liseré : cyan par défaut, orange pour la carte d'accélération.
    func cardStyle(tint: Color = Theme.cyan) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let fill = LinearGradient(
            colors: [Color(hex: 0x10191E), Color(hex: 0x070B0E)],
            startPoint: .top, endPoint: .bottom)
        let border = LinearGradient(
            colors: [tint.opacity(0.65), tint.opacity(0.15)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        return self
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 1))
    }
}

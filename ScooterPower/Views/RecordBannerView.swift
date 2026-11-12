import SwiftUI

/// Annonce affichée en haut de l'écran quand un record d'accélération tombe.
struct RecordBannerView: View {
    let banner: RecordBanner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26))
                .foregroundStyle(.black)
            VStack(alignment: .leading, spacing: 1) {
                Text("Record battu")
                    .font(.system(size: 19, weight: .heavy))
                Text(banner.title + " · ancien " + banner.previous)
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.75)
            }
            Spacer(minLength: 8)
            Text(banner.time)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 520)
        .background(Theme.orange, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.orange.opacity(0.7), radius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Record battu")
        .accessibilityValue(banner.title + ", " + banner.time + ", ancien record " + banner.previous)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    RecordBannerView(banner: RecordBanner(id: 1, title: "0–50 km/h", time: "4,2 s", previous: "4,9 s"))
        .padding()
        .background(.black)
}

import SwiftData
import SwiftUI
import ScooterCore

/// Récompenses : série de semaines, bilan de la semaine, badges et bilan de l'année.
struct RewardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TripRecord.startDate) private var trips: [TripRecord]
    @State private var showYear = false
    private let units = AppSettings.shared.units

    var body: some View {
        let rides: [RideFact] = trips.map(\.rideFact)
        let unlocked: [UnlockedBadge] = Rewards.badges(rides)
        let streak: Int = Rewards.weekStreak(rides, now: Date())
        let week: RideRecap = Rewards.weekRecap(rides, containing: Date())
        let lastWeek: RideRecap = Rewards.weekRecap(rides, containing: Date().addingTimeInterval(-7 * 86_400))
        let year: String = String(Calendar.current.component(.year, from: Date()))
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    streakCard(streak, ridden: week.trips > 0)
                    weekCard(week, previous: lastWeek)
                    Button {
                        showYear = true
                    } label: {
                        Label(L("Mon année \(year)"), systemImage: "sparkles")
                            .font(.system(size: 18, weight: .heavy))
                            .italic()
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.black)
                            .background(LinearGradient(colors: [Theme.cyan, Color(hex: 0xFF3D8B)], startPoint: .leading, endPoint: .trailing),
                                        in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    badgesGrid(unlocked)
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Récompenses"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
            .sheet(isPresented: $showYear) {
                YearRecapView(rides: rides, badges: unlocked.count)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func streakCard(_ streak: Int, ridden: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(streak > 0 ? Theme.orange : Theme.textSecondary)
                .shadow(color: Theme.orange.opacity(streak > 0 ? 0.8 : 0), radius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: streak == 1 ? L("1 semaine d'affilée") : L("\(String(streak)) semaines d'affilée"))
                    .font(.system(size: 22, weight: .heavy))
                Text(ridden || streak == 0
                     ? L("Roulez au moins une fois par semaine pour faire grandir la série.")
                     : L("Pas encore roulé cette semaine : un trajet avant dimanche prolonge la série !"))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.orange.opacity(0.5), lineWidth: 1))
    }

    private func weekCard(_ week: RideRecap, previous: RideRecap) -> some View {
        let distance: Double = units.distance(fromMeters: week.distanceMeters)
        let change: Double? = previous.distanceMeters > 0
            ? (week.distanceMeters - previous.distanceMeters) / previous.distanceMeters * 100 : nil
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Cette semaine"))
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.cyan)
            HStack {
                figure(Formatters.decimal(distance, digits: 0), units.distanceUnit)
                figure(String(week.trips), week.trips == 1 ? L("trajet") : L("trajets"))
                figure(Formatters.duration(week.movingSeconds), L("de roulage"))
            }
            if let change {
                Text(verbatim: (change >= 0 ? "▲ " : "▼ ") + Formatters.decimal(abs(change), digits: 0) + " % "
                     + L("par rapport à la semaine dernière"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Color(hex: 0x35D07F) : Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 24, weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badgesGrid(_ unlocked: [UnlockedBadge]) -> some View {
        let dates: [Badge: Date] = Dictionary(uniqueKeysWithValues: unlocked.map { ($0.badge, $0.date) })
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Badges \(String(unlocked.count))/\(String(Badge.allCases.count))"))
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.cyan)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(Badge.allCases, id: \.self) { badge in
                    BadgeTile(badge: badge, date: dates[badge])
                }
            }
        }
    }
}

private struct BadgeTile: View {
    let badge: Badge
    let date: Date?

    var body: some View {
        let earned: Bool = date != nil
        VStack(spacing: 6) {
            Image(systemName: earned ? badge.icon : "lock.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(earned ? Theme.orange : Theme.textSecondary.opacity(0.6))
                .frame(width: 58, height: 58)
                .background(Circle().fill(earned ? Theme.orange.opacity(0.18) : Color.white.opacity(0.05)))
                .shadow(color: earned ? Theme.orange.opacity(0.6) : .clear, radius: 8)
            Text(verbatim: badge.title)
                .font(.system(size: 12, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(earned ? Theme.textPrimary : Theme.textSecondary)
            Text(verbatim: date.map { AppDates.day($0) } ?? badge.detail)
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Bilan de l'année, à partager en image.
struct YearRecapView: View {
    let rides: [RideFact]
    let badges: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    private let year: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        let recap: RideRecap = Rewards.yearRecap(rides, year: year)
        let card = YearRecapCard(recap: recap, year: year, badges: badges)
        NavigationStack {
            ScrollView {
                card
                    .padding(16)
                if let image = render(card) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(L("Mon année en scooter"), image: Image(uiImage: image))) {
                        Label(L("Partager mon année"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.black)
                            .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Mon année"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func render(_ card: YearRecapCard) -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: 380).environment(\.colorScheme, .dark))
        renderer.scale = max(3, displayScale)
        return renderer.uiImage
    }
}

/// La carte « Mon année » : chiffres clés sur fond néon.
struct YearRecapCard: View {
    let recap: RideRecap
    let year: Int
    let badges: Int
    private let units = AppSettings.shared.units

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "SCOOTER POWER")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.cyan)
                    Text(L("Mon année \(String(year))"))
                        .font(.system(size: 32, weight: .black))
                        .italic()
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(Color(hex: 0xFF3D8B))
            }
            Text(verbatim: Formatters.decimal(units.distance(fromMeters: recap.distanceMeters), digits: 0) + " " + units.distanceUnit)
                .font(.system(size: 56, weight: .black).monospacedDigit())
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.7), radius: 12)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                line(String(recap.trips), L("trajets"))
                line(Formatters.duration(recap.movingSeconds), L("de roulage"))
                line(Formatters.decimal(units.distance(fromMeters: recap.longestTripMeters), digits: 0) + " " + units.distanceUnit,
                     L("plus long trajet"))
                line(String(recap.racesWon), L("ghosts battus"))
                line(recap.favouriteWeekday.map { Self.weekdayName($0) } ?? "--", L("jour préféré"))
                line(recap.favouriteHour.map { String(format: "%02d h", $0) } ?? "--", L("heure préférée"))
                line(String(badges), L("badges"))
            }
        }
        .padding(22)
        .background(
            ZStack {
                Color(hex: 0x05070C)
                LinearGradient(colors: [Theme.cyan.opacity(0.25), .clear, Color(hex: 0xFF3D8B).opacity(0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            })
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.cyan.opacity(0.6), lineWidth: 1.5))
        .foregroundStyle(.white)
    }

    private func line(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0xA0A6AD))
        }
    }

    /// Nom du jour dans la langue de l'app (1 = dimanche).
    static func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppSettings.shared.language.locale
        let names: [String] = calendar.standaloneWeekdaySymbols
        guard weekday >= 1, weekday <= names.count else { return "--" }
        return names[weekday - 1].capitalized
    }
}

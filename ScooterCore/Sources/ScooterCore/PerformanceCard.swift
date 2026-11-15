import Foundation

/// Carte de performances d'un pilote, échangée entre deux utilisateurs pour se
/// comparer. Elle voyage dans un lien `scooterpower://card?d=…`, partagé par
/// QR code ou par message : aucun serveur n'intervient.
///
/// Rien n'empêche de fabriquer une fausse carte : c'est un défi entre amis,
/// pas un classement officiel.
public struct PerformanceCard: Sendable, Equatable {
    public enum DecodingError: Error {
        case notACardLink
        case unreadable
        case unsupportedVersion
    }

    public static let scheme = "scooterpower"
    public static let host = "card"
    public static let maxNameLength = 30
    static let formatVersion = 1

    /// Pseudo du pilote, éventuellement vide.
    public let riderName: String
    /// Nom de la configuration du scooter.
    public let setupName: String
    /// Date de création de la carte.
    public let date: Date
    public let stats: PerformanceStats

    public init(riderName: String, setupName: String, date: Date, stats: PerformanceStats) {
        self.riderName = Self.clean(riderName)
        self.setupName = Self.clean(setupName)
        // Arrondie à la seconde : c'est la précision du lien.
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded())
        self.stats = Self.payload(from: stats).stats
    }

    // MARK: - Lien

    public var link: URL {
        let wire = Wire(v: Self.formatVersion, n: riderName, s: setupName,
                        t: Int(date.timeIntervalSince1970), st: Self.payload(from: stats))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(wire)) ?? Data()
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [URLQueryItem(name: "d", value: Self.base64URL(data))]
        return components.url ?? URL(string: "\(Self.scheme)://\(Self.host)")!
    }

    public init(link: URL) throws {
        guard link.scheme?.lowercased() == Self.scheme, link.host?.lowercased() == Self.host,
              let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "d" })?.value,
              !encoded.isEmpty
        else { throw DecodingError.notACardLink }
        guard encoded.count <= 4000, let data = Self.decodeBase64URL(encoded),
              let wire = try? JSONDecoder().decode(Wire.self, from: data)
        else { throw DecodingError.unreadable }
        guard wire.v == Self.formatVersion else { throw DecodingError.unsupportedVersion }
        self.init(riderName: wire.n, setupName: wire.s,
                  date: Date(timeIntervalSince1970: TimeInterval(wire.t)), stats: wire.st.stats)
    }

    /// Cherche un lien de carte dans un texte collé, par exemple un message reçu.
    public init?(text: String) {
        let prefix = "\(Self.scheme)://\(Self.host)?"
        guard let start = text.range(of: prefix, options: .caseInsensitive) else { return nil }
        let rest = text[start.lowerBound...]
        let end = rest.firstIndex(where: { $0.isWhitespace || $0 == "\"" || $0 == "<" || $0 == ">" }) ?? rest.endIndex
        guard let url = URL(string: String(rest[..<end])), let card = try? PerformanceCard(link: url) else { return nil }
        self = card
    }

    // MARK: - Format

    private struct Wire: Codable {
        var v: Int
        var n: String
        var s: String
        var t: Int
        var st: Payload
    }

    /// Les chiffres comparés, avec des clés courtes pour un lien compact.
    private struct Payload: Codable {
        struct Interval: Codable {
            var f: Int
            var t: Int
            var b: Double
            var a: Double
            var w: Double?
            var c: Int
        }

        var tc: Int?
        var dm: Double?
        var md: Double?
        var ts: Double?
        var ats: Double?
        var oas: Double?
        var bas: Double?
        var bp: Double?
        var ap: Double?
        var ll: Double?
        var lr: Double?
        var al: Double?
        var iv: [Interval]?

        var stats: PerformanceStats {
            var s = PerformanceStats(trips: [])
            s.tripCount = max(0, tc ?? 0)
            s.totalDistanceMeters = clean(dm)
            s.totalMovingDuration = clean(md)
            s.topSpeedKmh = clean(ts)
            s.averageTopSpeedKmh = clean(ats)
            s.overallAverageSpeedKmh = clean(oas)
            s.bestTripAverageSpeedKmh = clean(bas)
            s.bestPeakAcceleration = clean(bp)
            s.averagePeakAcceleration = clean(ap)
            s.maxLeanLeftDegrees = clean(ll)
            s.maxLeanRightDegrees = clean(lr)
            s.averageMaxLeanDegrees = clean(al)
            for entry in iv ?? [] {
                let interval = SpeedInterval(from: entry.f, to: entry.t)
                // Seules les plages connues de l'app, avec des temps valides.
                guard SpeedInterval.all.contains(interval),
                      entry.b.isFinite, entry.b > 0, entry.a.isFinite, entry.a > 0, entry.c > 0
                else { continue }
                s.intervals[interval] = PerformanceStats.IntervalStats(
                    best: entry.b, average: entry.a, worst: max(entry.b, entry.a, entry.w ?? 0), count: entry.c)
            }
            return s
        }

        private func clean(_ value: Double?) -> Double {
            guard let value, value.isFinite, value > 0 else { return 0 }
            return value
        }
    }

    private static func payload(from s: PerformanceStats) -> Payload {
        func rounded(_ value: Double, _ digits: Double) -> Double? {
            guard value.isFinite, value > 0 else { return nil }
            return (value * digits).rounded() / digits
        }
        var intervals: [Payload.Interval] = []
        for interval in SpeedInterval.all {
            guard let entry = s.intervals[interval],
                  let best = rounded(entry.best, 100), let average = rounded(entry.average, 100)
            else { continue }
            intervals.append(Payload.Interval(
                f: interval.from, t: interval.to, b: best, a: average, w: rounded(entry.worst, 100), c: entry.count))
        }
        return Payload(
            tc: s.tripCount, dm: rounded(s.totalDistanceMeters, 1), md: rounded(s.totalMovingDuration, 1),
            ts: rounded(s.topSpeedKmh, 10), ats: rounded(s.averageTopSpeedKmh, 10),
            oas: rounded(s.overallAverageSpeedKmh, 10), bas: rounded(s.bestTripAverageSpeedKmh, 10),
            bp: rounded(s.bestPeakAcceleration, 100), ap: rounded(s.averagePeakAcceleration, 100),
            ll: rounded(s.maxLeanLeftDegrees, 10), lr: rounded(s.maxLeanRightDegrees, 10),
            al: rounded(s.averageMaxLeanDegrees, 10), iv: intervals.isEmpty ? nil : intervals)
    }

    private static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).joined(separator: " ")
        return String(trimmed.prefix(maxNameLength))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeBase64URL(_ text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        return Data(base64Encoded: base64)
    }
}

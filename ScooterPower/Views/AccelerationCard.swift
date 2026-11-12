import Charts
import SwiftUI
import ScooterCore

extension AccelerationLevel {
    var label: String {
        switch self {
        case .brakingHard: return L("Freinage fort")
        case .braking: return L("Freinage modéré")
        case .stable: return L("Stable")
        case .accelerating: return L("Accélération modérée")
        case .acceleratingHard: return L("Accélération forte")
        }
    }

    var color: Color {
        switch self {
        case .brakingHard, .braking: return Theme.red
        case .stable: return Theme.textSecondary
        case .accelerating, .acceleratingHard: return Theme.orange
        }
    }

    /// +1 en accélération, −1 au freinage, 0 quand c'est stable.
    var direction: Int {
        switch self {
        case .brakingHard, .braking: return -1
        case .stable: return 0
        case .accelerating, .acceleratingHard: return 1
        }
    }
}

/// Poussée instantanée : valeur, niveau et jauge d'intensité colorée.
struct AccelerationCard: View {
    /// m/s², signée.
    let value: Double
    let valueText: String
    let level: AccelerationLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                    .shadow(color: Theme.cyan.opacity(0.8), radius: 6)
                    .frame(width: 30)
                    .padding(.top, 2)
                readout
                Spacer(minLength: 8)
                ScooterFrontShape()
                    .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 34, height: 54)
                    .padding(.trailing, 14)
            }
            IntensityBar(value: value)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .cardStyle(tint: Theme.orange)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poussée d'accélération")
        .accessibilityValue(L("\(valueText) mètres par seconde carrée, \(level.label)"))
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Poussée d'accélération")
                .font(.system(size: 17, weight: .semibold))
            valueLine
            levelPill
        }
    }

    private var valueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(valueText)
                .font(.system(size: 38, weight: .black))
                .italic()
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(verbatim: "m/s²")
                .font(.system(size: 22, weight: .bold))
                .italic()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var levelPill: some View {
        let shape = Capsule()
        let tint: Color = level.direction == 0 ? Theme.cyan : level.color
        return Text(level.label)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: shape)
            .overlay(shape.strokeBorder(tint.opacity(0.7), lineWidth: 1))
    }
}

/// Jauge d'intensité : vingt segments du vert au rouge, allumés selon la
/// force de la poussée, que ce soit en accélération ou au freinage.
struct IntensityBar: View {
    let value: Double

    private static let segments = 20
    private static let fullScale: Double = 4

    private var litCount: Int {
        let ratio: Double = min(1, abs(value) / Self.fullScale)
        return Int((ratio * Double(Self.segments)).rounded())
    }

    var body: some View {
        let lit: Int = litCount
        return HStack(spacing: 3) {
            ForEach(0..<Self.segments, id: \.self) { index in
                SlantedSegment()
                    .fill(index < lit ? Self.color(at: index) : Theme.gaugeIdle.opacity(0.55))
                    .shadow(color: index < lit ? Self.color(at: index).opacity(0.7) : Color.clear, radius: 3)
            }
        }
        .frame(height: 9)
        .animation(.easeOut(duration: 0.15), value: lit)
    }

    /// Du vert au jaune, puis à l'orange et au rouge.
    private static func color(at index: Int) -> Color {
        let position: Double = Double(index) / Double(segments - 1)
        if position < 0.3 { return Color(hex: 0x2EE65A) }
        if position < 0.5 { return Color(hex: 0xC8E619) }
        if position < 0.7 { return Color(hex: 0xF5C211) }
        if position < 0.85 { return Theme.orange }
        return Theme.red
    }
}

/// Un segment penché vers la droite.
private struct SlantedSegment: Shape {
    func path(in rect: CGRect) -> Path {
        let slant: CGFloat = min(rect.width * 0.35, rect.height * 0.6)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + slant, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Graphe des 30 dernières secondes, accélérations et freinages.
struct AccelerationHistoryCard: View {
    let history: [Double]
    let peakText: String

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private static let lowest: Double = -2
    private static let highest: Double = 4

    private var points: [Point] {
        let offset: Int = AccelerationAnalyzer.historyCapacity - history.count
        var result: [Point] = []
        result.reserveCapacity(history.count)
        for index in history.indices {
            let clamped: Double = min(Self.highest, max(Self.lowest, history[index]))
            result.append(Point(id: offset + index, value: clamped))
        }
        return result
    }

    /// Le point le plus haut, s'il correspond à une vraie accélération.
    private func peak(in data: [Point]) -> Point? {
        var best: Point?
        for point in data where point.value >= 0.3 {
            if best == nil || point.value > (best?.value ?? 0) {
                best = point
            }
        }
        return best
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            chart
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("30 dernières secondes")
        .accessibilityValue(L("Pic : \(peakText)"))
    }

    private var header: some View {
        HStack {
            Text("30 dernières secondes")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(L("Pic : \(peakText)"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(Theme.orange, lineWidth: 1.5))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var chart: some View {
        let data: [Point] = points
        let top: Point? = peak(in: data)
        let lastIndex: Int = AccelerationAnalyzer.historyCapacity - 1
        let ticks: [Double] = [-2, 0, 2, 4]
        return Chart {
            ForEach(data) { point in
                AreaMark(
                    x: .value("Temps", point.id),
                    yStart: .value("Accélération", 0.0),
                    yEnd: .value("Accélération", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(fill)
                LineMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let top {
                PointMark(x: .value("Temps", top.id), y: .value("Accélération", top.value))
                    .foregroundStyle(Theme.orange)
                    .symbolSize(45)
            }
        }
        .chartXScale(domain: 0...lastIndex)
        .chartYScale(domain: Self.lowest...Self.highest)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: ticks) { mark in
                AxisGridLine().foregroundStyle(Theme.cardBorder)
                AxisValueLabel {
                    Text(verbatim: axisLabel(for: mark))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                }
            }
        }
        .frame(height: 62)
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [Theme.cyan.opacity(0.4), Theme.cyan.opacity(0.04)],
            startPoint: .top, endPoint: .bottom)
    }

    private func axisLabel(for mark: AxisValue) -> String {
        guard let value = mark.as(Double.self) else { return "" }
        return Formatters.signed(value, digits: 1)
    }
}

#Preview {
    VStack {
        AccelerationCard(value: 0.4, valueText: "+0,4", level: .stable)
        AccelerationHistoryCard(
            history: [0.2, 0.4, 0.3, 0.9, 1.4, 1.8, 0.6, -0.5, -1.1, 0.2, 0.8, 0.5],
            peakText: "+1,8 m/s²")
    }
    .padding()
    .background(.black)
}

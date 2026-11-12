import Charts
import SwiftUI
import ScooterCore

extension AccelerationLevel {
    var label: String {
        switch self {
        case .brakingHard: return "Freinage fort"
        case .braking: return "Freinage"
        case .stable: return "Stable"
        case .accelerating: return "Accélération"
        case .acceleratingHard: return "Accélération forte"
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

struct AccelerationCard: View {
    /// m/s², signée.
    let value: Double
    let valueText: String
    let level: AccelerationLevel
    let history: [Double]
    let peakText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Poussée d'accélération")
                        .font(.system(size: 20, weight: .bold))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(valueText)
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("m/s²")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    Text(level.label)
                        .font(.system(size: 17, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(level.color.opacity(0.3), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(level.color, lineWidth: 1.5))
                }
                Spacer(minLength: 8)
                thrustFigure
            }

            AccelerationGauge(value: value)

            HStack {
                Text("Freinage").foregroundStyle(Theme.red)
                Spacer()
                Text("Stable").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Accélération").foregroundStyle(Theme.orange)
            }
            .font(.system(size: 14))

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(height: 1)

            HStack {
                Text("30 dernières secondes")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                HStack(spacing: 5) {
                    Text("Pic").foregroundStyle(Theme.orange)
                    Text(peakText).fontWeight(.bold)
                }
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.orange, lineWidth: 1.5))
            }

            AccelerationChart(history: history)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poussée d'accélération")
        .accessibilityValue("\(valueText) mètres par seconde carrée, \(level.label)")
    }

    /// Scooter surmonté de chevrons indiquant le sens de la poussée.
    private var thrustFigure: some View {
        VStack(spacing: 2) {
            VStack(spacing: -6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: level.direction < 0 ? "chevron.down" : "chevron.up")
                        .font(.system(size: 30, weight: .black))
                        .opacity(level.direction < 0 ? 0.4 + 0.3 * Double(index) : 1.0 - 0.3 * Double(index))
                }
            }
            .foregroundStyle(level.color)
            .shadow(color: level.color.opacity(0.8), radius: 8)
            .opacity(level.direction == 0 ? 0 : 1)

            ScooterFrontShape()
                .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 62)
        }
        .frame(width: 90)
        .animation(.easeInOut(duration: 0.25), value: level)
    }
}

/// Jauge segmentée Freinage / Stable / Accélération avec curseur.
struct AccelerationGauge: View {
    let value: Double

    private static let brakingSegments = 8
    private static let stableSegments = 7
    private static let acceleratingSegments = 12
    private static let total = brakingSegments + stableSegments + acceleratingSegments
    private static let stableLimit = 0.8
    private static let fullScale = 4.0

    /// Position du curseur entre 0 et 1. Chaque zone de couleur couvre
    /// exactement sa plage de valeurs, pour que la couleur sous le curseur
    /// corresponde toujours au niveau affiché.
    private var position: Double {
        let total = Double(Self.total)
        let brakingEnd = Double(Self.brakingSegments) / total
        let stableEnd = Double(Self.brakingSegments + Self.stableSegments) / total
        let v = min(Self.fullScale, max(-Self.fullScale, value))
        if v < -Self.stableLimit {
            return (v + Self.fullScale) / (Self.fullScale - Self.stableLimit) * brakingEnd
        }
        if v <= Self.stableLimit {
            return brakingEnd + (v + Self.stableLimit) / (2 * Self.stableLimit) * (stableEnd - brakingEnd)
        }
        return stableEnd + (v - Self.stableLimit) / (Self.fullScale - Self.stableLimit) * (1 - stableEnd)
    }

    var body: some View {
        GeometryReader { proxy in
            let knob: CGFloat = 26
            let x = knob / 2 + (proxy.size.width - knob) * CGFloat(position)
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(0..<Self.total, id: \.self) { index in
                        Capsule()
                            .fill(color(for: index))
                            .frame(height: 9)
                    }
                }
                .padding(.horizontal, knob / 2)

                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(knobColor, lineWidth: 3))
                    .shadow(color: knobColor.opacity(0.9), radius: 6)
                    .frame(width: knob, height: knob)
                    .position(x: x, y: proxy.size.height / 2)
                    .animation(.easeOut(duration: 0.15), value: position)
            }
        }
        .frame(height: 28)
    }

    private var knobColor: Color {
        let level = AccelerationAnalyzer.level(for: value)
        return level.direction == 0 ? Theme.gaugeIdle : level.color
    }

    private func color(for index: Int) -> Color {
        let center = (Double(index) + 0.5) / Double(Self.total)
        if index < Self.brakingSegments {
            // Allumé du curseur jusqu'à la zone stable quand on freine.
            return Theme.red.opacity(value < -Self.stableLimit && center < position ? 0.3 : 1)
        }
        if index < Self.brakingSegments + Self.stableSegments {
            return Theme.gaugeIdle
        }
        return Theme.orange.opacity(center <= position ? 1 : 0.25)
    }
}

/// Graphe des 30 dernières secondes. Les freinages sont tracés à zéro.
struct AccelerationChart: View {
    let history: [Double]

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private var points: [Point] {
        let offset = AccelerationAnalyzer.historyCapacity - history.count
        return history.enumerated().map { index, value in
            Point(id: offset + index, value: min(4, max(0, value)))
        }
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.orange.opacity(0.55), Theme.orange.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXScale(domain: 0...(AccelerationAnalyzer.historyCapacity - 1))
        .chartYScale(domain: 0...4)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0.0, 2.0, 4.0]) { mark in
                AxisGridLine().foregroundStyle(Theme.cardBorder)
                AxisValueLabel {
                    if let value = mark.as(Double.self) {
                        Text(value == 0 ? "0,0" : Formatters.signed(value, digits: 1))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .frame(height: 90)
    }
}

#Preview {
    AccelerationCard(
        value: 2.8, valueText: "+2,8", level: .acceleratingHard,
        history: (0..<120).map { 0.6 + 0.5 * sin(Double($0) / 6) + ($0 == 80 ? 2.5 : 0) },
        peakText: "+3,6 m/s²")
        .padding()
        .background(.black)
}

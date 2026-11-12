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

    // Le corps est découpé en petites vues : une seule grande expression
    // dépasse ce que le compilateur sait vérifier en temps raisonnable.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                readout
                Spacer(minLength: 8)
                thrustFigure
            }
            AccelerationGauge(value: value)
            gaugeLegend
            separator
            historyHeader
            AccelerationChart(history: history)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poussée d'accélération")
        .accessibilityValue("\(valueText) mètres par seconde carrée, \(level.label)")
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Poussée d'accélération")
                .font(.system(size: 18, weight: .bold))
            valueLine
            levelPill
        }
    }

    private var valueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(valueText)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("m/s²")
                .font(.system(size: 21, weight: .bold, design: .rounded))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var levelPill: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let fill: Color = level.color.opacity(0.3)
        return Text(level.label)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(level.color, lineWidth: 1.5))
    }

    private var gaugeLegend: some View {
        HStack {
            Text("Freinage").foregroundStyle(Theme.red)
            Spacer()
            Text("Stable").foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("Accélération").foregroundStyle(Theme.orange)
        }
        .font(.system(size: 14))
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(height: 1)
    }

    private var historyHeader: some View {
        HStack {
            Text("30 dernières secondes")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            peakPill
        }
    }

    private var peakPill: some View {
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

    /// Scooter surmonté de chevrons indiquant le sens de la poussée.
    private var thrustFigure: some View {
        VStack(spacing: 2) {
            chevrons
            ScooterFrontShape()
                .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 38, height: 54)
        }
        .frame(width: 90)
        .animation(.easeInOut(duration: 0.25), value: level)
    }

    private var chevrons: some View {
        let braking: Bool = level.direction < 0
        let symbol: String = braking ? "chevron.down" : "chevron.up"
        let glow: Color = level.color.opacity(0.8)
        let visibility: Double = level.direction == 0 ? 0 : 1
        return VStack(spacing: -6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .black))
                    .opacity(chevronOpacity(index: index, braking: braking))
            }
        }
        .foregroundStyle(level.color)
        .shadow(color: glow, radius: 8)
        .opacity(visibility)
    }

    /// Le chevron le plus proche du scooter est le plus pâle.
    private func chevronOpacity(index: Int, braking: Bool) -> Double {
        let step: Double = 0.3 * Double(index)
        return braking ? 0.4 + step : 1.0 - step
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
        let total: Double = Double(Self.total)
        let brakingEnd: Double = Double(Self.brakingSegments) / total
        let stableEnd: Double = Double(Self.brakingSegments + Self.stableSegments) / total
        let limit: Double = Self.stableLimit
        let outerSpan: Double = Self.fullScale - limit
        let v: Double = min(Self.fullScale, max(-Self.fullScale, value))
        if v < -limit {
            let ratio: Double = (v + Self.fullScale) / outerSpan
            return ratio * brakingEnd
        }
        if v <= limit {
            let ratio: Double = (v + limit) / (2 * limit)
            return brakingEnd + ratio * (stableEnd - brakingEnd)
        }
        let ratio: Double = (v - limit) / outerSpan
        return stableEnd + ratio * (1 - stableEnd)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                segments
                knob(in: proxy.size)
            }
        }
        .frame(height: 28)
    }

    private static let knobSize: CGFloat = 26

    private var segments: some View {
        HStack(spacing: 3) {
            ForEach(0..<Self.total, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 9)
            }
        }
        .padding(.horizontal, Self.knobSize / 2)
    }

    private func knob(in size: CGSize) -> some View {
        let travel: CGFloat = size.width - Self.knobSize
        let x: CGFloat = Self.knobSize / 2 + travel * CGFloat(position)
        let y: CGFloat = size.height / 2
        let tint: Color = knobColor
        let glow: Color = tint.opacity(0.9)
        return Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(tint, lineWidth: 3))
            .shadow(color: glow, radius: 6)
            .frame(width: Self.knobSize, height: Self.knobSize)
            .position(x: x, y: y)
            .animation(.easeOut(duration: 0.15), value: position)
    }

    private var knobColor: Color {
        let level = AccelerationAnalyzer.level(for: value)
        return level.direction == 0 ? Theme.gaugeIdle : level.color
    }

    private func color(for index: Int) -> Color {
        let center: Double = (Double(index) + 0.5) / Double(Self.total)
        let knobPosition: Double = position
        if index < Self.brakingSegments {
            // Allumé du curseur jusqu'à la zone stable quand on freine.
            let isBraking: Bool = value < -Self.stableLimit
            let dimmed: Bool = isBraking && center < knobPosition
            let opacity: Double = dimmed ? 0.3 : 1
            return Theme.red.opacity(opacity)
        }
        if index < Self.brakingSegments + Self.stableSegments {
            return Theme.gaugeIdle
        }
        let opacity: Double = center <= knobPosition ? 1 : 0.25
        return Theme.orange.opacity(opacity)
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
        let offset: Int = AccelerationAnalyzer.historyCapacity - history.count
        var result: [Point] = []
        result.reserveCapacity(history.count)
        for index in history.indices {
            let clamped: Double = min(4, max(0, history[index]))
            result.append(Point(id: offset + index, value: clamped))
        }
        return result
    }

    var body: some View {
        let lastIndex: Int = AccelerationAnalyzer.historyCapacity - 1
        let ticks: [Double] = [0, 2, 4]
        return Chart(points) { point in
            AreaMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(fillGradient)
            LineMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXScale(domain: 0...lastIndex)
        .chartYScale(domain: 0.0...4.0)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: ticks) { mark in
                AxisGridLine().foregroundStyle(Theme.cardBorder)
                AxisValueLabel {
                    Text(axisLabel(for: mark))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .frame(height: 60)
    }

    private var fillGradient: LinearGradient {
        let top: Color = Theme.orange.opacity(0.55)
        let bottom: Color = Theme.orange.opacity(0.05)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private func axisLabel(for mark: AxisValue) -> String {
        guard let value = mark.as(Double.self) else { return "" }
        return value == 0 ? "0,0" : Formatters.signed(value, digits: 1)
    }
}

#Preview {
    AccelerationCard(
        value: 2.8, valueText: "+2,8", level: .acceleratingHard,
        history: [0.4, 0.6, 0.5, 0.9, 1.4, 0.8, 0.6, 1.1, 2.9, 3.6, 1.7, 1.2, 1.0, 1.3, 1.5, 1.4],
        peakText: "+3,6 m/s²")
        .padding()
        .background(.black)
}

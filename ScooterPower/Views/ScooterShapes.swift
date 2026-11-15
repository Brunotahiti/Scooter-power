import SwiftUI

/// Maxi-scooter vu de face, au style moderne et agressif : nez en V avec deux
/// bandeaux LED lumineux, carrosserie en dégradé sombre, bulle translucide,
/// rétroviseurs, tablier, garde-boue et roue. Dessiné en code, sans image.
/// Le cadre attendu a une largeur d'environ 0,62 fois sa hauteur.
struct ScooterBadge: View {
    var body: some View {
        GeometryReader { proxy in
            let lw: CGFloat = max(0.8, proxy.size.width / 42)
            ZStack {
                part(.tyre, fill: Color(hex: 0x05080A), stroke: Color(hex: 0x6B7680), width: lw)
                part(.fender, fill: Self.bodyFill, stroke: Self.edge, width: lw * 0.8)
                part(.apron, fill: Self.bodyFill, stroke: Self.edge, width: lw)
                ScooterPart(kind: .accent)
                    .stroke(Theme.orange, style: StrokeStyle(lineWidth: lw * 1.4, lineCap: .round))
                    .shadow(color: Theme.orange.opacity(0.9), radius: lw * 1.5)
                part(.screen, fill: Self.screenFill, stroke: Theme.cyan, width: lw)
                ScooterPart(kind: .stalkLeft)
                    .stroke(Self.edge, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                ScooterPart(kind: .stalkRight)
                    .stroke(Self.edge, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                part(.mirrorLeft, fill: Self.bodyFill, stroke: Self.edge, width: lw * 0.8)
                part(.mirrorRight, fill: Self.bodyFill, stroke: Self.edge, width: lw * 0.8)
                part(.body, fill: Self.bodyFill, stroke: Color(hex: 0xD7E3EA), width: lw)
                ScooterPart(kind: .lampLeft)
                    .fill(Theme.cyan)
                    .shadow(color: Theme.cyan, radius: lw * 2)
                ScooterPart(kind: .lampRight)
                    .fill(Theme.cyan)
                    .shadow(color: Theme.cyan, radius: lw * 2)
            }
        }
        .accessibilityHidden(true)
    }

    private static let edge = Color(hex: 0x9FB3BF)

    private static var bodyFill: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x2A3A44), Color(hex: 0x0C1216)], startPoint: .top, endPoint: .bottom)
    }

    private static var screenFill: LinearGradient {
        LinearGradient(
            colors: [Theme.cyan.opacity(0.35), Theme.cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom)
    }

    private func part(_ kind: ScooterPart.Kind, fill: some ShapeStyle, stroke: Color, width: CGFloat) -> some View {
        ScooterPart(kind: kind)
            .fill(fill)
            .overlay(
                ScooterPart(kind: kind)
                    .stroke(stroke, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)))
    }
}

/// Une pièce du scooter, en coordonnées normalisées dans son cadre.
struct ScooterPart: Shape {
    enum Kind {
        case tyre, fender, apron, screen, stalkLeft, stalkRight, mirrorLeft, mirrorRight, body, lampLeft, lampRight, accent
    }

    private enum Step {
        case move(CGFloat, CGFloat)
        case line(CGFloat, CGFloat)
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        case close
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        for step in Self.steps(kind) {
            switch step {
            case .move(let x, let y):
                path.move(to: p(x, y))
            case .line(let x, let y):
                path.addLine(to: p(x, y))
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(to: p(x, y), control1: p(x1, y1), control2: p(x2, y2))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    private static func steps(_ kind: Kind) -> [Step] {
        switch kind {
        case .tyre: return [.move(0.44, 0.75), .curve(0.44, 0.71, 0.56, 0.71, 0.56, 0.75), .line(0.56, 0.96), .curve(0.56, 1, 0.44, 1, 0.44, 0.96), .close]
        case .fender: return [.move(0.35, 0.82), .curve(0.41, 0.73, 0.59, 0.73, 0.65, 0.82), .line(0.6, 0.82), .curve(0.56, 0.78, 0.44, 0.78, 0.4, 0.82), .close]
        case .apron: return [.move(0.35, 0.57), .curve(0.37, 0.66, 0.4, 0.72, 0.43, 0.76), .line(0.57, 0.76), .curve(0.6, 0.72, 0.63, 0.66, 0.65, 0.57), .close]
        case .screen: return [.move(0.29, 0.37), .curve(0.31, 0.24, 0.38, 0.11, 0.5, 0.1), .curve(0.62, 0.11, 0.69, 0.24, 0.71, 0.37), .close]
        case .stalkLeft: return [.move(0.24, 0.36), .line(0.15, 0.28)]
        case .stalkRight: return [.move(0.76, 0.36), .line(0.85, 0.28)]
        case .mirrorLeft: return [.move(0.03, 0.27), .curve(0.07, 0.23, 0.15, 0.23, 0.19, 0.25), .curve(0.17, 0.29, 0.09, 0.3, 0.05, 0.3), .close]
        case .mirrorRight: return [.move(0.97, 0.27), .curve(0.93, 0.23, 0.85, 0.23, 0.81, 0.25), .curve(0.83, 0.29, 0.91, 0.3, 0.95, 0.3), .close]
        case .body: return [.move(0.05, 0.39), .curve(0.3, 0.33, 0.7, 0.33, 0.95, 0.39), .line(0.86, 0.47), .line(0.58, 0.59), .line(0.42, 0.59), .line(0.14, 0.47), .close]
        case .lampLeft: return [.move(0.12, 0.42), .line(0.43, 0.535), .line(0.41, 0.565), .line(0.11, 0.455), .close]
        case .lampRight: return [.move(0.88, 0.42), .line(0.57, 0.535), .line(0.59, 0.565), .line(0.89, 0.455), .close]
        case .accent: return [.move(0.5, 0.6), .line(0.5, 0.74)]
        }
    }
}

#Preview {
    ScooterBadge()
        .frame(width: 124, height: 200)
        .padding()
        .background(.black)
}

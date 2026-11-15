import SwiftUI

/// Maxi-scooter vu de face, au style agressif : bulle haute, rétroviseurs
/// effilés, carénage anguleux avec phares plissés, tablier, garde-boue et
/// roue. Dessiné en `Path` pour ne dépendre d'aucune image ; s'utilise en
/// trait (`stroke`).
struct ScooterFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w: CGFloat = rect.width
        let h: CGFloat = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * w, y: rect.minY + y * h, width: width * w, height: height * h)
        }

        var path = Path()
        path.move(to: p(0.31, 0.32))
        path.addLine(to: p(0.38, 0.04))
        path.addQuadCurve(to: p(0.62, 0.04), control: p(0.50, 0.00))
        path.addLine(to: p(0.69, 0.32))
        path.move(to: p(0.27, 0.31))
        path.addLine(to: p(0.15, 0.22))
        path.move(to: p(0.01, 0.19))
        path.addLine(to: p(0.19, 0.17))
        path.addLine(to: p(0.16, 0.23))
        path.addLine(to: p(0.04, 0.24))
        path.closeSubpath()
        path.move(to: p(0.73, 0.31))
        path.addLine(to: p(0.85, 0.22))
        path.move(to: p(0.99, 0.19))
        path.addLine(to: p(0.81, 0.17))
        path.addLine(to: p(0.84, 0.23))
        path.addLine(to: p(0.96, 0.24))
        path.closeSubpath()
        path.move(to: p(0.12, 0.32))
        path.addLine(to: p(0.88, 0.32))
        path.addLine(to: p(0.95, 0.41))
        path.addLine(to: p(0.79, 0.50))
        path.addLine(to: p(0.21, 0.50))
        path.addLine(to: p(0.05, 0.41))
        path.closeSubpath()
        path.move(to: p(0.12, 0.38))
        path.addLine(to: p(0.41, 0.42))
        path.addLine(to: p(0.37, 0.46))
        path.addLine(to: p(0.20, 0.45))
        path.closeSubpath()
        path.move(to: p(0.88, 0.38))
        path.addLine(to: p(0.59, 0.42))
        path.addLine(to: p(0.63, 0.46))
        path.addLine(to: p(0.80, 0.45))
        path.closeSubpath()
        path.move(to: p(0.23, 0.50))
        path.addLine(to: p(0.33, 0.71))
        path.addLine(to: p(0.67, 0.71))
        path.addLine(to: p(0.77, 0.50))
        path.addRoundedRect(in: box(0.40, 0.57, 0.20, 0.05), cornerSize: CGSize(width: 0.03 * w, height: 0.03 * w))
        path.move(to: p(0.34, 0.79))
        path.addQuadCurve(to: p(0.66, 0.79), control: p(0.50, 0.69))
        path.addRoundedRect(in: box(0.42, 0.73, 0.16, 0.27), cornerSize: CGSize(width: 0.08 * w, height: 0.08 * w))
        return path
    }
}

#Preview {
    ScooterFrontShape()
        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .frame(width: 62, height: 100)
        .padding()
        .background(.black)
}

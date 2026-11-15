import SwiftUI

/// Pilote vu de face sur sa moto : casque, dos courbé, bras tenant le
/// guidon, carénage avec phare et roue avant. Dessiné en `Path` pour ne
/// dépendre d'aucune image ; s'utilise en trait (`stroke`).
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
        path.addEllipse(in: box(0.33, 0.03, 0.34, 0.21))
        path.move(to: p(0.38, 0.12))
        path.addQuadCurve(to: p(0.62, 0.12), control: p(0.50, 0.17))
        path.move(to: p(0.22, 0.41))
        path.addQuadCurve(to: p(0.50, 0.25), control: p(0.24, 0.25))
        path.addQuadCurve(to: p(0.78, 0.41), control: p(0.76, 0.25))
        path.move(to: p(0.24, 0.35))
        path.addQuadCurve(to: p(0.09, 0.56), control: p(0.04, 0.42))
        path.move(to: p(0.76, 0.35))
        path.addQuadCurve(to: p(0.91, 0.56), control: p(0.96, 0.42))
        path.move(to: p(0.01, 0.56))
        path.addLine(to: p(0.99, 0.56))
        path.move(to: p(0.31, 0.50))
        path.addLine(to: p(0.69, 0.50))
        path.addLine(to: p(0.76, 0.67))
        path.addQuadCurve(to: p(0.24, 0.67), control: p(0.50, 0.77))
        path.closeSubpath()
        path.addEllipse(in: box(0.40, 0.57, 0.20, 0.07))
        path.addRoundedRect(in: box(0.41, 0.73, 0.18, 0.27), cornerSize: CGSize(width: 0.09 * w, height: 0.09 * w))
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

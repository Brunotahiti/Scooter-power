import SwiftUI

/// Silhouette de scooter vue de face : guidon, tablier, corps, roue.
/// Dessinée en `Path` pour ne dépendre d'aucune image.
struct ScooterFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * w, y: rect.minY + y * h, width: width * w, height: height * h)
        }

        var path = Path()
        // Guidon
        path.move(to: point(0.02, 0.2))
        path.addLine(to: point(0.98, 0.2))
        // Tête et phare
        path.addEllipse(in: box(0.28, 0.04, 0.44, 0.3))
        // Tablier et corps
        path.addRoundedRect(in: box(0.26, 0.34, 0.48, 0.42), cornerSize: CGSize(width: 0.2 * w, height: 0.2 * w))
        // Roue avant
        path.addRoundedRect(in: box(0.41, 0.72, 0.18, 0.28), cornerSize: CGSize(width: 0.09 * w, height: 0.09 * w))
        return path
    }
}

#Preview {
    ScooterFrontShape()
        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .frame(width: 60, height: 96)
        .padding()
        .background(.black)
}

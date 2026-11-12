import Foundation

/// Allège un tracé avant de le stocker.
public enum RouteSimplifier {
    /// Garde au plus `maxPoints` points, répartis régulièrement, en conservant
    /// toujours le premier et le dernier.
    public static func downsample(_ route: [Coordinate], maxPoints: Int) -> [Coordinate] {
        let limit = max(2, maxPoints)
        guard route.count > limit else { return route }
        let lastIndex = Double(route.count - 1)
        return (0..<limit).map { step in
            let position = Double(step) * lastIndex / Double(limit - 1)
            return route[Int(position.rounded())]
        }
    }
}

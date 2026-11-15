import Foundation

/// Allège un tracé avant de le stocker.
public enum RouteSimplifier {
    /// Garde au plus `maxPoints` points, répartis régulièrement, en conservant
    /// toujours le premier et le dernier.
    public static func downsample(_ route: [Coordinate], maxPoints: Int) -> [Coordinate] {
        indices(count: route.count, maxPoints: maxPoints).map { route[$0] }
    }

    /// Indices conservés pour une liste de `count` éléments : sert à alléger
    /// ensemble plusieurs listes alignées sur le tracé.
    public static func indices(count: Int, maxPoints: Int) -> [Int] {
        let limit = max(2, maxPoints)
        guard count > limit else { return Array(0..<max(0, count)) }
        let lastIndex = Double(count - 1)
        return (0..<limit).map { step in
            Int((Double(step) * lastIndex / Double(limit - 1)).rounded())
        }
    }
}

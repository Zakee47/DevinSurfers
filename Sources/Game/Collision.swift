import SceneKit

/// Collision helpers — the core AABB loop lives in TrackManager.handleCollisions.
/// This file documents the rules and provides small shared utilities.
enum Collision {
    /// AABB overlap test for two axis-aligned boxes defined by center + half extents.
    static func overlap(c1: SCNVector3, h1: SCNVector3, c2: SCNVector3, h2: SCNVector3) -> Bool {
        abs(c1.x - c2.x) < h1.x + h2.x &&
        abs(c1.y - c2.y) < h1.y + h2.y &&
        abs(c1.z - c2.z) < h1.z + h2.z
    }
}

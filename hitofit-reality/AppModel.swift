//import SwiftUI
//
///// Maintains app-wide state for the Brick Wall VisionOS experience.
//@Observable
//class AppModel {
//    let immersiveSpaceID = "ImmersiveSpace"
//
//    enum ImmersiveSpaceState { case closed, inTransition, open }
//    var immersiveSpaceState: ImmersiveSpaceState = .closed
//
//    // MARK: - Customizable Settings
//
//    /// The wall is complete when a received cumulative count >= maxBricks.
//    var maxBricks: Int = 30
//
//    // MARK: - Runtime State
//
//    /// The last cumulative count received from the API.
//    var receivedCount: Int = 0
//
//    /// How many bricks are currently placed in the scene (== last receivedCount).
//    var bricksPlaced: Int = 0
//
//    /// Bricks added in the most recent update (delta).
//    var lastDelta: Int = 0
//
//    var isBuilding: Bool = false
//    var isCompleted: Bool = false
//
//    var progress: Double {
//        guard maxBricks > 0 else { return 0 }
//        return min(1.0, Double(bricksPlaced) / Double(maxBricks))
//    }
//
//    func reset() {
//        receivedCount = 0
//        bricksPlaced  = 0
//        lastDelta     = 0
//        isBuilding    = false
//        isCompleted   = false
//    }
//}

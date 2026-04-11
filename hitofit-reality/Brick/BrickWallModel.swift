//
//  BrickWallModel.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI

// MARK: - BrickWallModel
/// Conforms to StepDisplayable — the brick wall's pure state.
/// No timers, no network, no SwiftUI scene calls.
/// The immersive space is opened via the injected ImmersiveSpaceCoordinator.
@MainActor
@Observable
final class BrickWallModel: StepDisplayable {

    // MARK: Immersive space bookkeeping
    let immersiveSpaceID = "BrickWallImmersiveSpace"

    enum SpaceState { case closed, inTransition, open }
    var spaceState: SpaceState = .closed

    // MARK: Wall state (read-only outside this file)
    private(set) var targetBricks: Int = 0
    private(set) var bricksPlaced: Int = 0
    private(set) var lastDelta:    Int = 0
    private(set) var isStarted:    Bool = false
    private(set) var isCompleted:  Bool = false

    var progress: Double {
        guard targetBricks > 0 else { return 0 }
        return min(1.0, Double(bricksPlaced) / Double(targetBricks))
    }

    // Coordinator is injected so the model can trigger the space open
    // without depending on SwiftUI scene APIs directly.
    weak var coordinator: ImmersiveSpaceCoordinator?

    // MARK: - StepDisplayable

    func start() {
        isStarted = true
        guard spaceState == .closed else { return }
        spaceState = .inTransition
        Task { await coordinator?.openSpace() }
    }

    func setTarget(_ target: Int) {
        guard target > 0 else { return }
        targetBricks = target
        if bricksPlaced >= target { isCompleted = true }
    }

    @discardableResult
    func receive(cumulativeCount count: Int) -> Int {
        guard count > bricksPlaced else { return 0 }
        let delta    = count - bricksPlaced
        bricksPlaced = count
        lastDelta    = delta
        if targetBricks > 0 && bricksPlaced >= targetBricks {
            isCompleted = true
        }
        return delta
    }

    func reset() {
        targetBricks = 0
        bricksPlaced = 0
        lastDelta    = 0
        isStarted    = false
        isCompleted  = false
        if spaceState == .open {
            Task { await coordinator?.dismissSpace() }
        }
    }
}

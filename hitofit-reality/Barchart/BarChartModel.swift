//
//  BarChartModel.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI

// MARK: - BarChartModel
/// StepDisplayable for the real-time bar chart experience.
/// Uses MIXED immersion so the real-world passthrough stays visible.
/// Tracks a rolling history of step snapshots for the chart bars.
@MainActor
@Observable
final class BarChartModel: StepDisplayable {

    // MARK: - Immersive space
    let immersiveSpaceID = "BarChartImmersiveSpace"

    enum SpaceState { case closed, inTransition, open }
    var spaceState: SpaceState = .closed

    // MARK: - Chart data
    /// One entry per step update received. Kept to last `maxSamples` readings.
    struct Sample: Identifiable {
        let id:    UUID   = UUID()
        let index: Int          // sequential update number
        let count: Int          // cumulative step count at this update
    }

    private(set) var samples:      [Sample] = []
    private(set) var targetSteps:  Int      = 0
    private(set) var currentSteps: Int      = 0
    private(set) var isStarted:    Bool     = false
    private(set) var isCompleted:  Bool     = false

    /// How many bars to show in the chart window.
    let maxSamples = 20

    var progress: Double {
        guard targetSteps > 0 else { return 0 }
        return min(1.0, Double(currentSteps) / Double(targetSteps))
    }

    /// Highest value across visible samples (for bar scaling).
    var peakCount: Int {
        max(targetSteps, samples.map(\.count).max() ?? 1)
    }

    // MARK: - Coordinator
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
        targetSteps = target
        if currentSteps >= target { isCompleted = true }
    }

    func receive(cumulativeCount count: Int) -> Int {
        guard count > currentSteps || samples.isEmpty else { return 0}
        currentSteps = count
        let sample = Sample(index: samples.count, count: count)
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        if targetSteps > 0 && currentSteps >= targetSteps {
            isCompleted = true
        }
        return 0
    }

    func reset() {
        samples       = []
        targetSteps   = 0
        currentSteps  = 0
        isStarted     = false
        isCompleted   = false
        if spaceState == .open {
            Task { await coordinator?.dismissSpace() }
        }
    }
}

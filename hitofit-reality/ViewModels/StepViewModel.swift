//
//  StepViewModel.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//


import Foundation
import Observation

// MARK: - StepViewModel
/// Receives StepCommands from the peer network.
/// Uses DisplayRegistry to look up the correct model for each DisplayMode,
/// then forwards commands to it via StepDisplayable.
///
/// This file never changes when new display types are added.
@MainActor
@Observable
final class StepViewModel {

    // MARK: - Dependencies
    private let registry: DisplayRegistry

    // MARK: - Active display (switched by .selectDisplay command)
    private(set) var activeMode: DisplayMode = .brickWall
    private(set) var display: any StepDisplayable

    // MARK: - Raw state mirrors
    private(set) var steps:       Int  = 0
    private(set) var targetSteps: Int  = 0
    private(set) var isStarted:   Bool = false

    // MARK: - Init
    init(registry: DisplayRegistry) {
        self.registry = registry
        // Default to brickWall; overridden by .selectDisplay before .start
        guard let entry = registry.entry(for: .brickWall) else {
            fatalError("BrickWall display must be registered before StepViewModel init")
        }
        self.display    = entry.model
        self.activeMode = .brickWall
    }

    // MARK: - Command handling
    func handle(_ command: StepCommand) {
        switch command {

        case .handshake:
            break

        case .selectDisplay(let mode):
            switchDisplay(to: mode)

        case .start:
            print("StepViewModel: start [\(activeMode.label)]")
            isStarted = true
            display.start()

        case .targetSteps(let target):
            print("StepViewModel: targetSteps = \(target)")
            targetSteps = target
            display.setTarget(target)

        case .stepUpdate(let count):
            steps = count
            display.receive(cumulativeCount: count)

        case .reset:
            print("StepViewModel: reset")
            steps        = 0
            targetSteps  = 0
            isStarted    = false
            display.reset()
        }
    }

    // MARK: - Private
    private func switchDisplay(to mode: DisplayMode) {
        guard mode != activeMode else { return }
        guard let entry = registry.entry(for: mode) else {
            print("StepViewModel: no display registered for \(mode.label)")
            return
        }
        print("StepViewModel: switching display \(activeMode.label) → \(mode.label)")
        // Reset the old one cleanly before switching
        display.reset()
        display    = entry.model
        activeMode = mode
    }
}

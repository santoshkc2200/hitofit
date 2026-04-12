//
//  PedometerViewModel.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import Foundation
import CoreMotion
import PeerToPeerMessaging
import Observation

// MARK: - PedometerViewModel
/// The iPhone's single outbound-message point.
/// Owns CMPedometer, session lifecycle, and display-mode selection.
/// Views read state; they never touch the network directly.
@MainActor
@Observable
final class PedometerViewModel {

    // MARK: - Public state
    private(set) var steps:          Int          = 0
    private(set) var targetSteps:    Int          = 100
    private(set) var selectedMode:   DisplayMode  = .brickWall
    private(set) var isRunning:      Bool         = false
    private(set) var sessionStarted: Bool         = false
    private(set) var lastError:      String?      = nil

    // MARK: - Private
    private let pedometer   = CMPedometer()
    private let sendMessage: (StepCommand) async throws -> Void
    private var didAutoReset:  Bool         = false

    // MARK: - Init
    init<Manager: PeerMessagingManager>(
        controller: PeerMessagingController<Manager>
    ) where Manager.Message == StepCommand {
        self.sendMessage = { [weak controller] message in
            await controller?.send(message)
        }
    }

    // MARK: - Configuration (only valid before session starts)
    func setTargetSteps(_ value: Int) {
        guard !sessionStarted, value > 0 else { return }
        targetSteps = value
    }

    func setDisplayMode(_ mode: DisplayMode) {
        guard !sessionStarted else { return }
        selectedMode = mode
    }

    // MARK: - Session lifecycle

    /// Sends selectDisplay → start → targetSteps, then begins pedometer.
    func startSession() {
        guard !sessionStarted else { return }
        sessionStarted = true
        lastError      = nil
        didAutoReset   = false

        Task {
            do {
                try await sendMessage(.selectDisplay(mode: selectedMode))
                try await sendMessage(.start)
                try await sendMessage(.targetSteps(target: targetSteps))
                startPedometer()
            } catch {
                lastError      = error.localizedDescription
                sessionStarted = false
            }
        }
    }

    /// Stops pedometer and sends reset to Vision Pro.
    func resetSession() {
        didAutoReset = false
        stopPedometer()
        sessionStarted = false
        steps          = 0
        Task { try? await sendMessage(.reset) }
    }

    // MARK: - Pedometer (private)
    private func startPedometer() {
        guard !isRunning else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            lastError = "Step counting not available on this device."
            return
        }
        isRunning = true
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in self.lastError = error.localizedDescription }
                return
            }
            guard let data else { return }
            Task { @MainActor in
                let count = data.numberOfSteps.intValue
                self.steps = count
                try? await self.sendMessage(.stepUpdate(count: count))

                // Auto-reset when target reached or exceeded, only once per session
                if self.sessionStarted,
                   self.targetSteps > 0,
                   count >= self.targetSteps,
                   !self.didAutoReset {
                    self.didAutoReset = true
                    try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                    self.resetSession()
                }
            }
        }
    }

    private func stopPedometer() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
    }
}

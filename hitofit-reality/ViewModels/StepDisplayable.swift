//
//  StepDisplayable.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI

// MARK: - StepDisplayable
/// The contract every display model must satisfy.
/// StepViewModel talks exclusively to this protocol —
/// swap the concrete type to drive a completely different experience.
///
/// To add a new display (e.g. MapModel, LeaderboardModel):
///   1. Create a class conforming to StepDisplayable
///   2. Add its ImmersiveSpace in BrickWallApp
///   3. Register it in DisplayRegistry
///   4. Add the matching DisplayMode case to StepCommand (shared)
///   → Zero changes to StepViewModel, ClientContentView, or networking
@MainActor
protocol StepDisplayable: AnyObject {
    func setTarget(_ target: Int)
    func receive(cumulativeCount: Int) -> Int
    func reset()
    func start()
}

// MARK: - ImmersiveSpaceCoordinator
/// Decouples models from SwiftUI scene APIs.
/// One coordinator per immersive space; injected at app startup.
@MainActor
@Observable
final class ImmersiveSpaceCoordinator {
    var open:    (() async -> Void)?
    var dismiss: (() async -> Void)?

    func openSpace()    async { await open?()    }
    func dismissSpace() async { await dismiss?() }
}

// MARK: - DisplayRegistry
/// Single place that maps a DisplayMode to the live model + space ID.
/// BrickWallApp populates this; StepViewModel asks it when switching modes.
@MainActor
final class DisplayRegistry {
    private var entries: [DisplayMode: Entry] = [:]

    struct Entry {
        let model:   any StepDisplayable
        let spaceID: String
    }

    func register(_ mode: DisplayMode, model: any StepDisplayable, spaceID: String) {
        entries[mode] = Entry(model: model, spaceID: spaceID)
    }

    func entry(for mode: DisplayMode) -> Entry? { entries[mode] }
}

//
//  HitoFitCompanionApp.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI
import PeerToPeerMessaging

// MARK: - PhoneApp
/// iPhone app entry point.
/// Builds the object graph once and injects everything via environment.
///
/// Object graph:
///   serverController  ──(passed to)──▶  PedometerViewModel  (sends commands)
///                     ──(env)────────▶  ServerContentView    (connection UI)
///   pedometerViewModel ──(env)────────▶  ServerContentView
///                      ──(env)────────▶  PedometerPanelView  (step UI)
@main
struct HitoFitCompanionApp: App {

    // PeerMessagingController is the network layer — one per app lifetime.
    @State private var serverController = PeerMessagingController<Server<StepCommand>>()

    // PedometerViewModel is constructed with the controller so it can send.
    @State private var pedometerViewModel: PedometerViewModel

    init() {
        let controller = PeerMessagingController<Server<StepCommand>>()
        _serverController    = State(initialValue: controller)
        _pedometerViewModel  = State(initialValue: PedometerViewModel(controller: controller))
    }

    var body: some Scene {
        WindowGroup {
            ServerContentView()
                .environment(serverController)
                .environment(pedometerViewModel)
        }
    }
}

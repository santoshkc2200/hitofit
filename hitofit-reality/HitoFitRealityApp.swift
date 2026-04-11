//
//  HitoFitRealityApp.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//

import SwiftUI
import PeerToPeerMessaging

@main
struct HitoFitRealityApp: App {
    @State private var controller =
    PeerMessagingController<Client<StepCommand>>()
    
    // MARK: - Object graph
    // All objects are created once and wired together here.
    // Views never create models; they only read from the environment.
    
    @State private var registry      = DisplayRegistry()
    @State private var brickModel    = BrickWallModel()
    @State private var barChartModel = BarChartModel()
    @State private var brickCoord    = ImmersiveSpaceCoordinator()
    @State private var barChartCoord = ImmersiveSpaceCoordinator()
    @State private var stepViewModel: StepViewModel
    
    init() {
        // Build registry BEFORE StepViewModel — it requires brickWall to exist
        let registry      = DisplayRegistry()
        let brickModel    = BrickWallModel()
        let barChartModel = BarChartModel()
        
        registry.register(.brickWall, model: brickModel,    spaceID: brickModel.immersiveSpaceID)
        registry.register(.barChart,  model: barChartModel, spaceID: barChartModel.immersiveSpaceID)
        
        _registry      = State(initialValue: registry)
        _brickModel    = State(initialValue: brickModel)
        _barChartModel = State(initialValue: barChartModel)
        _stepViewModel = State(initialValue: StepViewModel(registry: registry))
    }
    
    var body: some Scene {
        //        WindowGroup {
        //            ClientContentView()
        //                .environment(controller)
        //                .environment(stepViewModel)
        //        }
        // MARK: - Control Window
        WindowGroup {
            ClientContentView()
                .environment(stepViewModel)
                .environment(brickModel)
                .environment(barChartModel)
                .environment(controller)
            // Wire both coordinators to their spaces via invisible helpers
                .background(
                    CoordinatorWiringView(coordinator: brickCoord,
                                          spaceID: brickModel.immersiveSpaceID)
                )
                .background(
                    CoordinatorWiringView(coordinator: barChartCoord,
                                          spaceID: barChartModel.immersiveSpaceID)
                )
                .onAppear {
                    brickModel.coordinator    = brickCoord
                    barChartModel.coordinator = barChartCoord
                }
        }
        .windowStyle(.plain)
        
        // MARK: - Brick Wall: FULL immersion
        ImmersiveSpace(id: brickModel.immersiveSpaceID) {
            BrickWallImmersiveView()
                .environment(brickModel)
                .onAppear   { brickModel.spaceState = .open   }
                .onDisappear { brickModel.spaceState = .closed }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        
        // MARK: - Bar Chart: MIXED immersion (real world stays visible)
        ImmersiveSpace(id: barChartModel.immersiveSpaceID) {
            BarChartImmersiveView()
                .environment(barChartModel)
                .onAppear   { barChartModel.spaceState = .open   }
                .onDisappear { barChartModel.spaceState = .closed }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

// MARK: - CoordinatorWiringView
/// Zero-size helper that captures SwiftUI's openImmersiveSpace /
/// dismissImmersiveSpace actions and hands them to the coordinator.
/// Keeping this separate means no other view needs to know about it.
private struct CoordinatorWiringView: View {
    let coordinator: ImmersiveSpaceCoordinator
    let spaceID: String
    
    @Environment(\.openImmersiveSpace)    private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        Color.clear
            .onAppear {
                coordinator.open = {
                    await openImmersiveSpace(id: spaceID)
                }
                coordinator.dismiss = {
                    await dismissImmersiveSpace()
                }
            }
    }
}

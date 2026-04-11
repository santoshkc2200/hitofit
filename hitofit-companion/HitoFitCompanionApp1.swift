//
//  HitoFitCompanionApp.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//

//import SwiftUI
//import PeerToPeerMessaging
//
//@main
//struct HitoFitCompanionApp: App {
//    @State private var controller =
//        PeerMessagingController<Server<StepCommand>>()
//
//    @State private var pedometerViewModel: PedometerViewModel?
//
//    var body: some Scene {
//        WindowGroup {
//            ServerContentView()
//                .environment(controller)
//                .environment(pedometerViewModel ?? PedometerViewModel(controller: controller))
//                .onAppear {
//                    if pedometerViewModel == nil {
//                        pedometerViewModel = PedometerViewModel(controller: controller)
//                    }
//                }
//        }
//    }
//}

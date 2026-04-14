//
//  StepCommand.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//

import Foundation
import PeerToPeerMessaging

// MARK: - StepCommand
/// The shared message type exchanged between the iPhone (server)
/// and the Vision Pro (client).
///
/// Shared between targets — keep this file in a shared Swift Package
/// or duplicate it across both targets. Never add platform-specific
/// imports here so it compiles on both iOS and visionOS.
public enum StepCommand: PeerToPeerMessage {
    /// Sent by the client immediately after TCP connection to confirm
      /// the channel is open. Server ignores this.
      case handshake
   
      /// Server → Client: session is starting, client should open its UI.
      case start
   
      /// Server → Client: the step goal for this session.
      case targetSteps(target: Int)
   
      /// Server → Client: latest **cumulative** step count since session began.
      case stepUpdate(count: Int)
   
      /// Server → Client: tear everything down and return to idle.
      case reset
    
    /// Server → Client: choose which visualisation to open.
     /// Must be sent **before** `.start`.
     case selectDisplay(mode: DisplayMode)
}

// MARK: - DisplayMode
/// The visualisation the iPhone operator wants to show on Vision Pro.
/// Sent before `.start` so the headset opens the correct experience.
/// Add new cases here as new display types are built.
// MARK: - DisplayMode
public enum DisplayMode: String, Codable, Sendable, CaseIterable {
    case brickWall = "brickWall"
    case barChart  = "barChart"
 
    /// Localised display name — reads from Localizable.xcstrings in whichever
    /// target (iPhone or visionOS) is currently running.
    public var localizedLabel: String {
        switch self {
        case .brickWall: return String(localized: "display.brickWall")
        case .barChart:  return String(localized: "display.barChart")
        }
    }
 
    /// Non-localised fallback used where LocalizedStringKey is not accepted
    /// (e.g. 3-D text generation in RealityKit).
    public var systemImage: String {
        switch self {
        case .brickWall: return "square.grid.3x3.fill"
        case .barChart:  return "chart.bar.fill"
        }
    }
}

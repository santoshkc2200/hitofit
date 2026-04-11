//
//  ClientContentView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//


import PeerToPeerMessaging
import SwiftUI

// MARK: - ClientContentView
/// Handles peer connection lifecycle only.
/// It does NOT know about bricks, steps, or immersive spaces —
/// all of that is driven by StepViewModel once commands arrive.
struct ClientContentView: View {
    @Environment(PeerMessagingController<Client<StepCommand>>.self) var clientController
    @Environment(StepViewModel.self) var viewmodel

    @State private var networkTask: Task<Void, Error>?
    @State private var clientID:    Int  = Int.random(in: 0...9000)
    @State private var messageTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(Text(statusText))
                Text(statusText)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            // Main content per connection state
            Group {
                switch clientController.connectionState {
                case .connected:
                    ConnectedStatusView()
                        .task {
                            await clientController.send(.handshake)
                            if messageTask == nil {
                                messageTask = Task { @MainActor in
                                    for await message in clientController.incomingMessages {
                                        viewmodel.handle(message)
                                    }
                                }
                            }
                        }

                case .waitingForConnection:
                    browsingView

                case .connecting:
                    connectingView

                default:
                    startBrowsingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controlBar.padding()
        }
        .onDisappear {
            messageTask?.cancel()
            messageTask = nil
        }
    }

    // MARK: - Sub-views

    /// Shown while connected — minimal, since the immersive space carries the experience.
    /// Swap this out for any richer "connected" UI without touching networking code.
    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView("Connecting…")
            Text("Establishing a secure connection")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var browsingView: some View {
        VStack(spacing: 16) {
            ProgressView("Searching for devices…")
            Button("Cancel") {
                networkTask?.cancel()
                networkTask = nil
            }
        }
    }

    private var startBrowsingView: some View {
        VStack(spacing: 20) {
            Text("Get Started").font(.title2).bold()
            Text("Connect to your iPad to begin.")
                .foregroundStyle(.secondary)
            Text("Your Device ID: \(clientID)")
                .font(.footnote).foregroundStyle(.secondary)

            Button {
                guard clientController.connectionState != .connecting else { return }
                networkTask = clientController.start(with: clientID.description)
            } label: {
                Label("Start Connecting", systemImage: "bolt.horizontal.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            if let error = clientController.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var controlBar: some View {
        HStack {
            switch clientController.connectionState {
            case .connected:
                Button(role: .destructive) {
                    clientController.stop()
                    messageTask?.cancel()
                    messageTask = nil
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle.fill")
                }
            case .connecting:
                ProgressView("Connecting…")
                Spacer()
            case .waitingForConnection:
                Button("Cancel") {
                    networkTask?.cancel()
                    networkTask = nil
                }
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    // MARK: - Helpers
    private var statusText: String {
        switch clientController.connectionState {
        case .connected:           return "Connected"
        case .connecting:          return "Connecting…"
        case .waitingForConnection: return "Browsing…"
        default:                   return "Not connected"
        }
    }

    private var statusColor: Color {
        switch clientController.connectionState {
        case .connected:                       return .green
        case .connecting, .waitingForConnection: return .orange
        default:                               return .red
        }
    }
}

// MARK: - ConnectedStatusView
/// Minimal "you're connected, waiting for the session to start" view.
/// Shown in the window once connected but before .start arrives.
/// Easy to replace or extend without touching ClientContentView.
private struct ConnectedStatusView: View {
    @Environment(StepViewModel.self) private var viewModel
    @Environment(BrickWallModel.self) private var wallModel

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isStarted {
                // Session is running — immersive space should be open.
                // Window shows a lightweight live summary.
                VStack(spacing: 12) {
                    Label("Session Active", systemImage: "figure.walk.circle.fill")
                        .font(.title2).fontWeight(.semibold).foregroundStyle(.green)

                    if viewModel.targetSteps > 0 {
                        VStack(spacing: 6) {
                            Text("\(viewModel.steps) / \(viewModel.targetSteps) steps")
                                .font(.title).fontWeight(.bold)
                                .contentTransition(.numericText())
                                .animation(.spring, value: viewModel.steps)

                            ProgressView(value: wallModel.progress)
                                .tint(.red).frame(maxWidth: 280)
                        }
                    }

                    if wallModel.isCompleted {
                        Label("Goal reached! 🎉", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.headline)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            } else {
                // Connected but .start not yet received
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Waiting for session to start…")
                        .font(.headline).foregroundStyle(.secondary)
                    Text("The immersive wall will open automatically.")
                        .font(.footnote).foregroundStyle(.tertiary)
                }
            }
        }
        .animation(.easeInOut, value: viewModel.isStarted)
        .animation(.easeInOut, value: wallModel.isCompleted)
    }
}

#Preview {
    // Build a registry and register the BrickWallModel for previews
    let wall = BrickWallModel()
    let registry = DisplayRegistry()
    registry.register(.brickWall, model: wall, spaceID: wall.immersiveSpaceID)

    return ClientContentView()
        .environment(PeerMessagingController<Client<StepCommand>>())
        .environment(StepViewModel(registry: registry))
        .environment(wall)
}

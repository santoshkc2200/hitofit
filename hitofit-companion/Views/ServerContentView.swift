//
//  ServerContentView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//


import SwiftUI
import PeerToPeerMessaging

// MARK: - ServerContentView
/// Handles the peer-connection lifecycle on the iPhone.
/// Once connected it hands off to PedometerPanelView.
/// This view knows nothing about steps, bricks, or the session —
/// all of that lives in PedometerViewModel.
struct ServerContentView: View {
    @Environment(PeerMessagingController<Server<StepCommand>>.self) var serverController
    @Environment(PedometerViewModel.self) var pedometerViewModel

    @State private var networkTask: Task<Void, Error>?
    @State private var serverID: Int?

    var body: some View {
        VStack(spacing: 16) {
            // ── Status indicator ─────────────────────────────────────────
            statusHeader
                .padding(.horizontal)
                .padding(.top)

            // ── Main content ─────────────────────────────────────────────
            Group {
                switch serverController.connectionState {
                case .connected:
                    PedometerPanelView()

                case .waitingForConnection:
                    listeningView

                case .connecting:
                    connectingView

                default:
                    startListeningView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Bottom control bar ───────────────────────────────────────
            controlBar.padding()
        }
        // Auto-reset the session when the peer disconnects
        .onChange(of: serverController.connectionState) { _, state in
            if state != .connected && pedometerViewModel.sessionStarted {
                pedometerViewModel.resetSession()
            }
        }
    }

    // MARK: - Status header
    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityLabel(statusText)
            Text(statusText)
                .font(.headline)
            Spacer()
        }
    }

    // MARK: - Control bar
    private var controlBar: some View {
        HStack {
            switch serverController.connectionState {
            case .connected:
                Button(role: .destructive) {
                    pedometerViewModel.resetSession()   // clean up before disconnect
                    serverController.stop()
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle.fill")
                }
            case .connecting:
                ProgressView("Connecting…")
                Spacer()
            case .waitingForConnection:
                Button("Stop Listening") {
                    networkTask?.cancel()
                    networkTask = nil
                }
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    // MARK: - State-specific views

    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView("Connecting…")
            Text("Waiting for secure handshake")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var listeningView: some View {
        VStack(spacing: 16) {
            ProgressView("Listening for incoming connections…")
            Text("ID: \(serverID?.description ?? "N/A")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Stop Listening") {
                networkTask?.cancel()
                networkTask = nil
            }
        }
    }

    private var startListeningView: some View {
        VStack(spacing: 20) {
            Text("Get Started")
                .font(.title2).bold()

            Text("Enter an ID and start listening for your Vision Pro.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("Server ID").foregroundStyle(.secondary)
                TextField(value: $serverID, format: .number) {
                    Text("e.g. 1234")
                }
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 320)

            Button {
                guard let id = serverID else { return }
                guard serverController.connectionState != .connecting else { return }
                networkTask = serverController.start(with: id.description)
            } label: {
                Label("Start Listening", systemImage: "ear.badge.waveform")
                    .font(.headline)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .disabled(serverID == nil)

            if let error = serverController.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Helpers
    private var statusText: String {
        switch serverController.connectionState {
        case .connected:            return "Connected"
        case .connecting:           return "Connecting…"
        case .waitingForConnection: return "Listening…"
        default:                    return "Not connected"
        }
    }

    private var statusColor: Color {
        switch serverController.connectionState {
        case .connected:                          return .green
        case .connecting, .waitingForConnection:  return .orange
        default:                                  return .red
        }
    }
}

#Preview {
    ServerContentView()
        .environment(PeerMessagingController<Server<StepCommand>>())
}

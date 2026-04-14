//
//  ServerContentView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//


import SwiftUI
import PeerToPeerMessaging

import SwiftUI

// MARK: - ServerContentView
struct ServerContentView: View {
    @Environment(PeerMessagingController<Server<StepCommand>>.self) var serverController
    @Environment(PedometerViewModel.self) var pedometerViewModel

    @State private var networkTask: Task<Void, Error>?
    @State private var serverID: Int?

    var body: some View {
        VStack(spacing: 16) {
            statusHeader
                .padding(.horizontal)
                .padding(.top)

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

            controlBar.padding()
        }
        .onChange(of: serverController.connectionState) { _, state in
            if state != .connected && pedometerViewModel.sessionStarted {
                pedometerViewModel.resetSession()
            }
        }
    }

    // MARK: - Status Header
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

    // MARK: - Control Bar
    private var controlBar: some View {
        HStack {
            switch serverController.connectionState {

            case .connected:
                Button(role: .destructive) {
                    pedometerViewModel.resetSession()
                    serverController.stop()
                } label: {
                    Label("server.disconnect", systemImage: "xmark.circle.fill")
                }

            case .connecting:
                ProgressView("server.connectingProgress")
                Spacer()

            case .waitingForConnection:
                Button("server.stopListening") {
                    networkTask?.cancel()
                    networkTask = nil
                }

            default:
                EmptyView()
            }
            Spacer()
        }
    }

    // MARK: - Connecting View
    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView("server.connectingProgress")

            Text("server.waitingHandshake")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Listening View
    private var listeningView: some View {
        VStack(spacing: 16) {
            ProgressView("server.listeningProgress")
            Text("server.idLabel \(serverID?.description ?? "server.id_na")")
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button("server.stopListening") {
                networkTask?.cancel()
                networkTask = nil
            }
        }
    }

    // MARK: - Start Listening View
    private var startListeningView: some View {
        VStack(spacing: 20) {

            Text("server.getStarted")
                .font(.title2)
                .bold()

            Text("server.instructions")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("server.serverID")
                    .foregroundStyle(.secondary)

                TextField(
                    value: $serverID,
                    format: .number
                ) {
                    Text("server.idPlaceholder")
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
                Label(
                    "server.startListening",
                    systemImage: "ear.badge.waveform"
                )
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
        case .connected:
            return String(localized: "status.connected")
        case .connecting:
            return String(localized: "status.connecting")
        case .waitingForConnection:
            return String(localized: "status.listening")
        default:
            return String(localized: "status.notConnected")
        }
    }

    private var statusColor: Color {
        switch serverController.connectionState {
        case .connected:
            return .green
        case .connecting, .waitingForConnection:
            return .orange
        default:
            return .red
        }
    }
}


#Preview {
    ServerContentView()
        .environment(PeerMessagingController<Server<StepCommand>>())
}

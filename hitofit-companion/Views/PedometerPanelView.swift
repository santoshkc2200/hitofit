//
//  PedometerPanelView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//

import SwiftUI

// MARK: - PedometerPanelView
/// Connected state UI on the iPhone.
/// Pre-session: lets the operator choose display mode + target steps.
/// During session: shows live count, progress bar, and end button.
struct PedometerPanelView: View {
    @Environment(PedometerViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                if !viewModel.sessionStarted {
                    displayModeCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                    sessionConfigCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                stepCountCard
                primaryActionButton

                if let error = viewModel.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .animation(.spring(response: 0.4), value: viewModel.sessionStarted)
        }
    }

    // MARK: - Display mode picker card
    private var displayModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Vision Pro Display", systemImage: "visionpro")
                .font(.headline)
            Divider()

            VStack(spacing: 10) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    DisplayModeRow(
                        mode: mode,
                        isSelected: viewModel.selectedMode == mode,
                        onTap: { viewModel.setDisplayMode(mode) }
                    )
                }
            }

            Text("The chosen experience opens automatically on Vision Pro when you start.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Session config card
    private var sessionConfigCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Session Setup", systemImage: "gearshape.fill")
                .font(.headline)
            Divider()

            HStack {
                Text("Step Target").foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { viewModel.targetSteps },
                        set: { viewModel.setTargetSteps($0) }
                    ),
                    in: 10...10_000, step: 10
                ) {
                    Text("\(viewModel.targetSteps) steps")
                        .monospacedDigit().fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Live step counter
    private var stepCountCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)
            VStack(spacing: 10) {
                // Mode label during session
                if viewModel.sessionStarted {
                    Label(viewModel.selectedMode.label,
                          systemImage: viewModel.selectedMode.systemImage)
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text(viewModel.sessionStarted ? "Steps This Session" : "Ready to Start")
                    .font(.subheadline).foregroundStyle(.secondary)

                Text("\(viewModel.steps)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring, value: viewModel.steps)

                if viewModel.sessionStarted && viewModel.targetSteps > 0 {
                    VStack(spacing: 4) {
                        ProgressView(
                            value: min(1.0, Double(viewModel.steps) / Double(viewModel.targetSteps))
                        )
                        .tint(viewModel.steps >= viewModel.targetSteps ? .green : progressTint)
                        Text("\(viewModel.steps) / \(viewModel.targetSteps)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity).frame(minHeight: 180)
    }

    private var progressTint: Color {
        viewModel.selectedMode == .brickWall ? .red : .blue
    }

    // MARK: - Primary action
    @ViewBuilder
    private var primaryActionButton: some View {
        if viewModel.sessionStarted {
            Button(role: .destructive) {
                viewModel.resetSession()
            } label: {
                Label("End Session & Reset", systemImage: "stop.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.red)
        } else {
            Button {
                viewModel.startSession()
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedMode.systemImage)
                    Text("Start \(viewModel.selectedMode.label) Session")
                        .fontWeight(.semibold)
                }
                .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.selectedMode == .brickWall ? .red : .blue)
        }
    }
}

// MARK: - DisplayModeRow
private struct DisplayModeRow: View {
    let mode:       DisplayMode
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: mode.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.25),
                                          lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private var modeDescription: String {
        switch mode {
        case .brickWall: return "Fully immersive — builds a red brick wall"
        case .barChart:  return "Mixed reality — floating chart over real world"
        }
    }
}

#Preview {
    PedometerPanelView()
}

//
//  PedometerPanelView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//

import SwiftUI

// MARK: - PedometerPanelView

// MARK: - PedometerPanelView
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
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .animation(.spring(response: 0.4), value: viewModel.sessionStarted)
        }
    }

    // MARK: - Display Mode Card
    private var displayModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("display.visionProDisplay", systemImage: "visionpro")
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

            Text("display.autoOpenHint")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Session Config Card
    private var sessionConfigCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("session.setup", systemImage: "gearshape.fill")
                .font(.headline)

            Divider()

            HStack {
                Text("session.stepTarget")
                    .foregroundStyle(.secondary)

                Spacer()

                Stepper(
                    value: Binding(
                        get: { viewModel.targetSteps },
                        set: { viewModel.setTargetSteps($0) }
                    ),
                    in: 10...10_000,
                    step: 10
                ) {
                    Text("session.stepTargetValue \(viewModel.targetSteps)")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Step Count Card
    private var stepCountCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)

            VStack(spacing: 10) {

                if viewModel.sessionStarted {
                    Label(
                        viewModel.selectedMode.localizedLabel,
                        systemImage: viewModel.selectedMode.systemImage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text(
                    viewModel.sessionStarted
                    ? "session.stepsThisSession"
                    : "session.readyToStart"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(String(viewModel.steps))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring, value: viewModel.steps)

                if viewModel.sessionStarted && viewModel.targetSteps > 0 {
                    VStack(spacing: 4) {
                        ProgressView(
                            value: min(
                                1.0,
                                Double(viewModel.steps) / Double(viewModel.targetSteps)
                            )
                        )
                        .tint(viewModel.steps >= viewModel.targetSteps ? .green : progressTint)
                        Text(String.init(format: "%d / %d", viewModel.steps, viewModel.targetSteps))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
    }

    private var progressTint: Color {
        viewModel.selectedMode == .brickWall ? .red : .blue
    }

    // MARK: - Primary Button
    @ViewBuilder
    private var primaryActionButton: some View {
        if viewModel.sessionStarted {
            Button(role: .destructive) {
                viewModel.resetSession()
            } label: {
                Label(
                    "session.endButton",
                    systemImage: "stop.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        } else {
            Button {
                viewModel.startSession()
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedMode.systemImage)

                    Text(
                        "session.startButton \(viewModel.selectedMode.localizedLabel)"
                        
                    )
                    .fontWeight(.semibold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.selectedMode == .brickWall ? .red : .blue)
        }
    }
}

// MARK: - DisplayModeRow
private struct DisplayModeRow: View {
    let mode: DisplayMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {

                Image(systemName: mode.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {

                    Text(mode.localizedLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(
                            isSelected ? .white.opacity(0.8) : .secondary
                        )
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
                            .strokeBorder(
                                isSelected ? Color.clear : Color.secondary.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private var modeDescription: String {
        switch mode {
        case .brickWall:
            return String(localized:"display.brickWallDesc")
        case .barChart:
            return String(localized:"display.barChartDesc")
        }
    }
}

#Preview {
    PedometerPanelView()
}

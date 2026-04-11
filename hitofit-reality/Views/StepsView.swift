//
//  StepsView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/09.
//


//import SwiftUI
//
///// The main content shown once the peer connection is established.
///// Hosts the brick wall status and the open/close immersive space button.
//struct StepsView: View {
//    @Environment(StepViewModel.self) private var viewModel
//    @Environment(BrickWallModel.self) private var wallModel
//    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
//    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
//
//    var body: some View {
//        VStack(spacing: 28) {
//
//            // ── Step counter card ────────────────────────────────────
//            VStack(spacing: 8) {
//                Text("Steps")
//                    .font(.title3)
//                    .foregroundStyle(.secondary)
//
//                Text("\(viewModel.steps)")
//                    .font(.system(size: 72, weight: .bold, design: .rounded))
//                    .foregroundStyle(.primary)
//                    .contentTransition(.numericText())
//                    .animation(.spring, value: viewModel.steps)
//
//                if viewModel.targetSteps > 0 {
//                    VStack(spacing: 6) {
//                        ProgressView(value: wallModel.progress)
//                            .tint(.red)
//                            .frame(maxWidth: 280)
//                        Text("\(viewModel.steps) / \(viewModel.targetSteps) target")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                } else {
//                    Text("Waiting for target…")
//                        .font(.subheadline)
//                        .foregroundStyle(.tertiary)
//                }
//            }
//            .padding(24)
//            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
//
//            // ── Brick wall status card ───────────────────────────────
//            VStack(spacing: 8) {
//                Label("Brick Wall", systemImage: "square.grid.3x3.fill")
//                    .font(.headline)
//                    .foregroundStyle(.secondary)
//
//                if wallModel.isCompleted {
//                    Label("Completed! \(wallModel.bricksPlaced) bricks", systemImage: "checkmark.seal.fill")
//                        .font(.title3)
//                        .fontWeight(.bold)
//                        .foregroundStyle(.green)
//                } else if wallModel.targetBricks > 0 {
//                    Text("\(wallModel.bricksPlaced) / \(wallModel.targetBricks) bricks placed")
//                        .font(.title3)
//                        .fontWeight(.medium)
//                        .contentTransition(.numericText())
//                        .animation(.spring, value: wallModel.bricksPlaced)
//                } else {
//                    Text("Waiting for server…")
//                        .foregroundStyle(.tertiary)
//                }
//            }
//            .padding(20)
//            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
//
//            // ── Immersive Space toggle ───────────────────────────────
//            if wallModel.immersiveSpaceState == .open {
//                Button(role: .destructive) {
//                    Task { await dismissImmersiveSpace() }
//                } label: {
//                    Label("Close Immersive Wall", systemImage: "xmark.circle.fill")
//                }
//                .buttonStyle(.bordered)
//            } else {
//                Button {
//                    Task { await openImmersiveSpace(id: wallModel.immersiveSpaceID) }
//                } label: {
//                    Label("View in Immersive Space", systemImage: "visionpro")
//                        .font(.headline)
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.red)
//                .disabled(wallModel.immersiveSpaceState == .inTransition)
//            }
//        }
//        .padding()
//        .animation(.easeInOut, value: wallModel.isCompleted)
//    }
//}
//
//#Preview {
//    StepsView()
//        .environment(StepViewModel())
//        .environment(BrickWallModel())
//}

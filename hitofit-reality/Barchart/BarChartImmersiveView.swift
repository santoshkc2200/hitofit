//
//  BarChartImmersiveView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI
import RealityKit

// MARK: - BarChartImmersiveView
/// Mixed-immersion space — real-world passthrough stays visible.
/// Renders a floating 3-D bar chart in front of the user that updates
/// in real time as step counts arrive from the iPhone.
///
/// Layout (world space, z = -1.8 m in front):
///   • Bars grow upward from a shared baseline
///   • Most-recent bar is always highlighted in orange
///   • A thin target-line plane sits at the target-step height
///   • Floating info text sits above the chart
struct BarChartImmersiveView: View {
    @Environment(BarChartModel.self) private var model

    // Scene anchors
    @State private var rootEntity   = Entity()
    @State private var infoEntity   = Entity()

    // Tracks which sample IDs are already in the scene
    @State private var renderedIDs: Set<UUID> = []

    var body: some View {
        RealityView { content in
            setupScene(content: content)
        } update: { _ in
            syncBars()
            updateInfoText()
        }
        .onChange(of: model.samples.count) { _, _ in
            syncBars()
            updateInfoText()
        }
        .onChange(of: model.isCompleted) { _, _ in updateInfoText() }
        .onChange(of: model.targetSteps) { _, _ in
            updateTargetLine()
            updateInfoText()
        }
    }

    // MARK: - Scene constants
    private let barWidth:    Float = 0.06
    private let barDepth:    Float = 0.06
    private let barSpacing:  Float = 0.09   // centre-to-centre
    private let maxBarHeight: Float = 0.70  // metres for 100 % of target
    private let baselineY:   Float = 0.20   // height off floor

    private var chartOriginX: Float {
        let totalWidth = Float(model.maxSamples) * barSpacing
        return -totalWidth * 0.5
    }

    // MARK: - Setup
    private func setupScene(content: RealityViewContent) {
        // Chart sits 1.8 m in front, at comfortable viewing height
        rootEntity.position = SIMD3<Float>(0, 0.90, -1.8)
        infoEntity.position = SIMD3<Float>(0, 1.45, -1.8)

        content.add(rootEntity)
        content.add(infoEntity)

        updateInfoText()
        updateTargetLine()
    }

    // MARK: - Sync bars with model.samples
    private func syncBars() {
        let existingIDs = renderedIDs
        let modelIDs    = Set(model.samples.map(\.id))

        // Remove bars for samples that were pruned
        for id in existingIDs where !modelIDs.contains(id) {
            if let entity = rootEntity.findEntity(named: id.uuidString) {
                entity.removeFromParent()
            }
            renderedIDs.remove(id)
        }

        // Add / update bars for new samples
        for (offset, sample) in model.samples.enumerated() {
            let isNew      = !renderedIDs.contains(sample.id)
            let isLatest   = offset == model.samples.count - 1
            let barHeight  = heightForCount(sample.count)
            let xPos       = chartOriginX + Float(offset) * barSpacing + barWidth * 0.5
            let yPos       = baselineY + barHeight * 0.5

            if isNew {
                let entity = makeBarEntity(height: barHeight, isLatest: isLatest)
                entity.name     = sample.id.uuidString
                entity.position = SIMD3<Float>(xPos, yPos - barHeight, 0)   // start below
                rootEntity.addChild(entity)
                renderedIDs.insert(sample.id)

                // Animate bar growing up
                var t = Transform()
                t.translation = SIMD3<Float>(xPos, yPos, 0)
                t.scale       = SIMD3<Float>(1, 1, 1)
                entity.move(to: t, relativeTo: rootEntity, duration: 0.35, timingFunction: .easeOut)

            } else if let entity = rootEntity.findEntity(named: sample.id.uuidString) as? ModelEntity {
                // Re-colour old bars (previous latest is no longer highlighted)
                if !isLatest {
                    recolour(entity: entity, isLatest: false)
                }
                // Reposition in case window shifted left
                var t = Transform()
                t.translation = SIMD3<Float>(xPos, yPos, 0)
                t.scale       = SIMD3<Float>(1, 1, 1)
                entity.move(to: t, relativeTo: rootEntity, duration: 0.2, timingFunction: .easeInOut)
            }
        }
    }

    // MARK: - Bar factory
    private func makeBarEntity(height: Float, isLatest: Bool) -> ModelEntity {
        let safeHeight = max(height, 0.005)
        let mesh = MeshResource.generateBox(
            width: barWidth, height: safeHeight, depth: barDepth, cornerRadius: 0.008
        )
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: isLatest ? .systemOrange : barColor(for: height))
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic  = .init(floatLiteral: 0.15)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.scale = SIMD3<Float>(1, 0.01, 1)  // start squashed, grows in animation
        return entity
    }

    private func recolour(entity: ModelEntity, isLatest: Bool) {
        guard let heightY = entity.position(relativeTo: rootEntity).y as Float?,
              let mesh = entity.model?.mesh else { return }
        // Rebuild material
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: isLatest ? .systemOrange : barColor(for: heightY))
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic  = .init(floatLiteral: 0.15)
        entity.model?.materials = [mat]
    }

    /// Colour shifts from cool blue → warm green → orange as bar nears target.
    private func barColor(for height: Float) -> UIColor {
        let ratio = Double(height / maxBarHeight)
        if ratio < 0.5 { return .systemBlue }
        if ratio < 0.85 { return .systemGreen }
        return .systemYellow
    }

    private func heightForCount(_ count: Int) -> Float {
        guard model.peakCount > 0 else { return 0.01 }
        return maxBarHeight * Float(count) / Float(model.peakCount)
    }

    // MARK: - Target line
    private func updateTargetLine() {
        rootEntity.findEntity(named: "targetLine")?.removeFromParent()
        guard model.targetSteps > 0 else { return }

        let lineY   = baselineY + heightForCount(model.targetSteps)
        let width   = Float(model.maxSamples) * barSpacing
        let mesh    = MeshResource.generatePlane(width: width, depth: barDepth * 0.4)
        var mat     = UnlitMaterial(color: .systemRed.withAlphaComponent(0.7))
        let line    = ModelEntity(mesh: mesh, materials: [mat])
        line.name        = "targetLine"
        line.position    = SIMD3<Float>(0, lineY, 0)
        line.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        rootEntity.addChild(line)
    }

    // MARK: - Info text
    private func updateInfoText() {
        infoEntity.children.removeAll()
        let mesh = MeshResource.generateText(
            infoString(),
            extrusionDepth: 0.004,
            font: .systemFont(ofSize: 0.06, weight: .bold),
            containerFrame: CGRect(x: -0.7, y: -0.055, width: 1.4, height: 0.11),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var mat = SimpleMaterial()
        mat.color     = .init(tint: model.isCompleted ? .systemGreen : .white)
        mat.metallic  = .float(0.1)
        mat.roughness = .float(0.5)
        infoEntity.addChild(ModelEntity(mesh: mesh, materials: [mat]))
    }

    private func infoString() -> String {
        if model.isCompleted {
            return "✅  Goal reached!  \(model.currentSteps) steps"
        } else if model.targetSteps > 0 {
            let pct = Int(model.progress * 100)
            return "📊  \(model.currentSteps) / \(model.targetSteps) steps  (\(pct)%)"
        } else {
            return "📊  Waiting for data…"
        }
    }
}
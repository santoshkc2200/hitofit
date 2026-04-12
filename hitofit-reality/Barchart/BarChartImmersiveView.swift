//
//  BarChartImmersiveView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/11.
//


import SwiftUI
import RealityKit

// MARK: - BarChartImmersiveView
/// Mixed-immersion space — real world passthrough stays visible.
/// Renders a floating 3-D bar chart that updates in real time.
struct BarChartImmersiveView: View {
    @Environment(BarChartModel.self) private var model
    
    @State private var rootEntity  = Entity()
    @State private var infoEntity  = Entity()
    @State private var renderedIDs: Set<UUID> = []
    
    // Capture content for fireworks
    @State private var sceneContent: RealityViewContent?
    
    var body: some View {
        RealityView { content in
            sceneContent = content
            setupScene(content: content)
        } update: { _ in }
            .onChange(of: model.samples.count) { _, _ in syncBars(); updateInfoText() }
            .onChange(of: model.isCompleted) { _, completed in
                updateInfoText()
                if completed {
                    // Fireworks origin sits in front of the chart, in the mixed-reality world
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let content = sceneContent {
                            FireworksSystem.launchCelebration(
                                in: content,
                                // Spread slightly wider since environment is visible
                                origin: SIMD3<Float>(0, 1.5, -2.2)
                            )
                        }
                    }
                }
            }
            .onChange(of: model.targetSteps) { _, _ in updateTargetLine(); updateInfoText() }
            .onChange(of: model.currentSteps) { old, new in
                if new == 0 && old > 0 { clearScene() }
            }
    }
    
    // MARK: - Constants
    private let barWidth:     Float = 0.06
    private let barDepth:     Float = 0.06
    private let barSpacing:   Float = 0.09
    private let maxBarHeight: Float = 0.70
    private let baselineY:    Float = 0.20
    
    private var chartOriginX: Float {
        -(Float(model.maxSamples) * barSpacing) * 0.5
    }
    
    // MARK: - Setup
    private func setupScene(content: RealityViewContent) {
        // 1. Create the Head Anchor
        let headAnchor = AnchorEntity(.head)
        
        // 2. Adjust local position relative to the face
        // X: 0 (center), Y: -0.1 (slightly below eye level), Z: -0.6 (60cm away)
        rootEntity.position = SIMD3<Float>(0, -0.1, -2.4)
        infoEntity.position = SIMD3<Float>(0, -0.2, -2.4)
        
        // 3. Nest your entities under the anchor
        headAnchor.addChild(rootEntity)
        headAnchor.addChild(infoEntity)
        
        // 4. Add the anchor to the RealityView
        content.add(headAnchor)
        updateInfoText()
        updateTargetLine()
    }
    
    // MARK: - Sync bars
    private func syncBars() {
        let modelIDs = Set(model.samples.map(\.id))
        for id in renderedIDs where !modelIDs.contains(id) {
            rootEntity.findEntity(named: id.uuidString)?.removeFromParent()
            renderedIDs.remove(id)
        }
        for (offset, sample) in model.samples.enumerated() {
            let isLatest  = offset == model.samples.count - 1
            let barHeight = heightForCount(sample.count)
            let xPos      = chartOriginX + Float(offset) * barSpacing + barWidth * 0.5
            let yPos      = baselineY + barHeight * 0.5
            
            if !renderedIDs.contains(sample.id) {
                let entity = makeBarEntity(height: barHeight, isLatest: isLatest)
                entity.name     = sample.id.uuidString
                entity.position = SIMD3<Float>(xPos, baselineY, 0)
                entity.scale    = SIMD3<Float>(1, 0.01, 1)
                rootEntity.addChild(entity)
                renderedIDs.insert(sample.id)
                
                var t = Transform()
                t.translation = SIMD3<Float>(xPos, yPos, 0)
                t.scale       = SIMD3<Float>(1, 1, 1)
                entity.move(to: t, relativeTo: rootEntity, duration: 0.35, timingFunction: .easeOut)
            } else if let entity = rootEntity.findEntity(named: sample.id.uuidString) as? ModelEntity {
                if !isLatest { recolour(entity: entity, height: barHeight, isLatest: false) }
                var t = Transform()
                t.translation = SIMD3<Float>(xPos, yPos, 0)
                t.scale       = SIMD3<Float>(1, 1, 1)
                entity.move(to: t, relativeTo: rootEntity, duration: 0.2, timingFunction: .easeInOut)
            }
        }
    }
    
    private func makeBarEntity(height: Float, isLatest: Bool) -> ModelEntity {
        let safeH = max(height, 0.005)
        let mesh = MeshResource.generateBox(width: barWidth, height: safeH, depth: barDepth,
                                            cornerRadius: 0.008)
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: isLatest ? .systemOrange : barColor(for: height))
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic  = .init(floatLiteral: 0.15)
        return ModelEntity(mesh: mesh, materials: [mat])
    }
    
    private func recolour(entity: ModelEntity, height: Float, isLatest: Bool) {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: isLatest ? .systemOrange : barColor(for: height))
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic  = .init(floatLiteral: 0.15)
        entity.model?.materials = [mat]
    }
    
    private func barColor(for height: Float) -> UIColor {
        let r = Double(height / maxBarHeight)
        if r < 0.5 { return .systemBlue }
        if r < 0.85 { return .systemGreen }
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
        let lineY = baselineY + heightForCount(model.targetSteps)
        let width = Float(model.maxSamples) * barSpacing
        let mesh  = MeshResource.generatePlane(width: width, depth: barDepth * 0.4)
        var mat   = UnlitMaterial(color: .systemRed.withAlphaComponent(0.7))
        let line  = ModelEntity(mesh: mesh, materials: [mat])
        line.name        = "targetLine"
        line.position    = SIMD3<Float>(0, lineY, 0)
        line.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        rootEntity.addChild(line)
    }
    
    // MARK: - Info text
    private func buildInfoText() {
        infoEntity.children.removeAll()
        let mesh = MeshResource.generateText(
            infoString(), extrusionDepth: 0.004,
            font: .systemFont(ofSize: 0.06, weight: .bold),
            containerFrame: CGRect(x: -0.7, y: -0.055, width: 1.4, height: 0.11),
            alignment: .center, lineBreakMode: .byWordWrapping)
        var mat = SimpleMaterial()
        mat.color     = .init(tint: model.isCompleted ? .systemGreen : .white)
        mat.metallic  = .float(0.1); mat.roughness = .float(0.5)
        infoEntity.addChild(ModelEntity(mesh: mesh, materials: [mat]))
    }
    
    private func infoString() -> String {
        if model.isCompleted { return "✅  Goal reached!  \(model.currentSteps) steps" }
        if model.targetSteps > 0 { return "📊  \(model.currentSteps) / \(model.targetSteps) steps  (\(Int(model.progress*100))%)" }
        return "📊  Waiting for data…"
    }
    private func updateInfoText() { buildInfoText() }
    
    // MARK: - Scene clear
    private func clearScene() {
        rootEntity.children.removeAll()
        renderedIDs.removeAll()
        buildInfoText()
    }
}

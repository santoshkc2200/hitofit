//
//  BrickWallImmersiveView.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/12.
//


import SwiftUI
import RealityKit
import AVFoundation

// MARK: - Brick Layout Helper
struct BrickLayoutEngine {
    static let bricksPerRow = 6
    static let brickWidth:  Float = 0.20
    static let brickHeight: Float = 0.07
    static let brickDepth:  Float = 0.09
    static let mortar:      Float = 0.012

    static func rowOffset(_ row: Int) -> Float {
        row.isMultiple(of: 2) ? 0 : (brickWidth + mortar) * 0.5
    }

    static func position(for index: Int) -> SIMD3<Float> {
        let col = index % bricksPerRow
        let row = index / bricksPerRow
        let xStep     = brickWidth  + mortar
        let yStep     = brickHeight + mortar
        let wallWidth = Float(bricksPerRow) * xStep - mortar
        let xOrigin   = -wallWidth * 0.5
        let x = xOrigin + Float(col) * xStep + rowOffset(row) + brickWidth * 0.5
        let y = Float(row) * yStep + brickHeight * 0.5
        return SIMD3<Float>(x: x, y: y, z: 0)
    }
}

// MARK: - BrickWallImmersiveView
struct BrickWallImmersiveView: View {
    @Environment(BrickWallModel.self) private var model

    @State private var rootEntity       = Entity()
    @State private var infoEntity       = Entity()
    @State private var deltaLabelEntity = Entity()
    @State private var sceneBrickCount: Int = 0

    @State private var audioPlayers: [AVAudioPlayer] = []
    @State private var audioIdx = 0

    // Keeps a reference to the RealityViewContent for fireworks
    @State private var sceneContent: RealityViewContent?

    var body: some View {
        RealityView { content in
            sceneContent = content
            setupScene(content: content)
        } update: { _ in }
        .onChange(of: model.bricksPlaced) { old, new in
            guard new > old else { return }
            placeBricks(from: old, count: new - old)
            showDeltaLabel(delta: new - old)
            updateInfoText()
        }
        .onChange(of: model.targetBricks) { _, _ in updateInfoText() }
        .onChange(of: model.isCompleted) { _, completed in
            if completed {
                updateInfoText()
                // Small delay so the last bricks settle before fireworks ignite
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let content = sceneContent {
                        FireworksSystem.launchCelebration(
                            in: content,
                            // Origin slightly above and in front of the wall
                            origin: SIMD3<Float>(0, 1.6, -2.5)
                        )
                    }
                }
            }
        }
        .onChange(of: model.bricksPlaced) { _, new in
            if new == 0 { clearScene() }
        }
    }

    // MARK: - Scene setup
    private func setupScene(content: RealityViewContent) {
        rootEntity.position       = SIMD3<Float>(0, 0.50, -2.5)
        infoEntity.position       = SIMD3<Float>(0, 0.4, -2.5)
        deltaLabelEntity.position = SIMD3<Float>(0, 0.85, -2.5)
        content.add(rootEntity)
        content.add(infoEntity)
        content.add(deltaLabelEntity)
        setupAudio()
        buildInfoText()
    }

    // MARK: - Brick placement
    private func placeBricks(from startIndex: Int, count: Int) {
        for offset in 0..<count {
            let delay = Double(offset) * 0.055
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                placeSingleBrick(at: startIndex + offset)
            }
        }
        sceneBrickCount += count
    }

    private func placeSingleBrick(at index: Int) {
        let entity    = makeBrickEntity()
        let targetPos = BrickLayoutEngine.position(for: index)

        entity.position           = targetPos + SIMD3<Float>(0, 0.30, 0)
        entity.scale              = SIMD3<Float>(0.08, 0.08, 0.08)
        entity.transform.rotation = simd_quatf(
            angle: Float.random(in: -0.18...0.18), axis: SIMD3<Float>(0, 0, 1))
        rootEntity.addChild(entity)

        var final = Transform()
        final.translation = targetPos
        final.scale       = SIMD3<Float>(1, 1, 1)
        final.rotation    = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        entity.move(to: final, relativeTo: rootEntity, duration: 0.26, timingFunction: .easeOut)

        playBrickSound()
    }

    private func makeBrickEntity() -> ModelEntity {
        let mesh = MeshResource.generateBox(
            width: BrickLayoutEngine.brickWidth, height: BrickLayoutEngine.brickHeight,
            depth: BrickLayoutEngine.brickDepth, cornerRadius: 0.004)
        let rv = Float.random(in: -0.09...0.09)
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: CGFloat(0.78+rv), green: CGFloat(0.12+rv*0.25),
                                            blue: 0.07, alpha: 1))
        mat.roughness = .init(floatLiteral: 0.85)
        mat.metallic  = .init(floatLiteral: 0.0)
        return ModelEntity(mesh: mesh, materials: [mat])
    }

    // MARK: - Scene clear
    private func clearScene() {
        rootEntity.children.removeAll()
        deltaLabelEntity.children.removeAll()
        sceneBrickCount = 0
        buildInfoText()
    }

    // MARK: - Delta label
    private func showDeltaLabel(delta: Int) {
        guard delta > 0 else { return }
        deltaLabelEntity.children.removeAll()

        let mesh = MeshResource.generateText(
            "+\(delta) steps", extrusionDepth: 0.006,
            font: .systemFont(ofSize: 0.065, weight: .heavy),
            containerFrame: CGRect(x: -0.45, y: -0.05, width: 0.9, height: 0.11),
            alignment: .center, lineBreakMode: .byClipping)
        var mat = SimpleMaterial()
        mat.color = .init(tint: .systemOrange); mat.metallic = .float(0.3); mat.roughness = .float(0.3)
        let badge = ModelEntity(mesh: mesh, materials: [mat])
        badge.scale = SIMD3<Float>(1.6, 1.6, 1.6)
        deltaLabelEntity.addChild(badge)

        var t = Transform(); t.scale = SIMD3<Float>(1, 1, 1)
        badge.move(to: t, relativeTo: deltaLabelEntity, duration: 0.18, timingFunction: .easeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            var t2 = Transform(); t2.scale = SIMD3<Float>(0.01, 0.01, 0.01)
            badge.move(to: t2, relativeTo: self.deltaLabelEntity, duration: 0.28, timingFunction: .easeIn)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { deltaLabelEntity.children.removeAll() }
    }

    // MARK: - Info text
    private func buildInfoText() {
        infoEntity.children.removeAll()
        let mesh = MeshResource.generateText(
            infoString(), extrusionDepth: 0.005,
            font: .systemFont(ofSize: 0.07, weight: .bold),
            containerFrame: CGRect(x: -0.75, y: -0.06, width: 1.5, height: 0.13),
            alignment: .center, lineBreakMode: .byWordWrapping)
        var mat = SimpleMaterial()
        mat.color     = .init(tint: model.isCompleted ? .systemGreen : .white)
        mat.metallic  = .float(0.15); mat.roughness = .float(0.45)
        infoEntity.addChild(ModelEntity(mesh: mesh, materials: [mat]))
    }

    private func infoString() -> String {
        if model.isCompleted { return "✅  COMPLETED  —  \(model.bricksPlaced) steps!" }
        if model.targetBricks > 0 { return "🧱  \(model.bricksPlaced) / \(model.targetBricks) steps" }
        return "🧱  Waiting for target…"
    }
    private func updateInfoText() { buildInfoText() }

    // MARK: - Audio
    private func setupAudio() { audioPlayers = (0..<3).compactMap { _ in makeAudioPlayer() } }

    private func makeAudioPlayer() -> AVAudioPlayer? {
        let sr: Double = 44100
        let n  = Int(sr * 0.10)
        var buf = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sr
            buf[i] = Float(exp(-t * 38)) * (0.45*Float(sin(2 * .pi * 160 * t))
                     + 0.55*Float.random(in: -1...1)) * 0.55
        }
        let pcm = buf.map { Int16(max(-32767, min(32767, Int($0 * 32767)))) }
        let p = try? AVAudioPlayer(data: buildWAV(pcm: pcm, sampleRate: UInt32(sr)))
        p?.prepareToPlay(); return p
    }

    private func playBrickSound() {
        let p = audioPlayers[audioIdx % audioPlayers.count]
        p.stop(); p.currentTime = 0; p.play(); audioIdx += 1
    }

    private func buildWAV(pcm: [Int16], sampleRate: UInt32) -> Data {
        let ch: UInt16 = 1, bps: UInt16 = 16
        let ds = UInt32(pcm.count) * 2
        var d = Data()
        func a<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d += "RIFF".utf8; a(36+ds); d += "WAVE".utf8
        d += "fmt ".utf8; a(UInt32(16)); a(UInt16(1)); a(ch); a(sampleRate)
        a(sampleRate*2); a(UInt16(2)); a(bps)
        d += "data".utf8; a(ds); pcm.forEach { a($0) }
        return d
    }
}

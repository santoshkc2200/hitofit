//
//  NatureParticleSystem.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/13.
//


import RealityKit
import SwiftUI

// MARK: - NatureParticleSystem
/// Ambient falling leaves + sakura petals for the BrickWall immersive space.
///
/// Architecture:
///   - Fixed pool of `ParticleEntity` wrappers (no allocation per frame).
///   - A single repeating Timer drives the physics simulation at ~30 fps.
///   - Each particle has its own wind phase, tumble axis, speed, and sway
///     amplitude, giving every piece visually distinct motion.
///   - Particles that fall below `floorY` are teleported back to a random
///     spawn position above the ceiling — continuous, seamless recycling.
///
/// Usage:
///   let system = NatureParticleSystem()
///   system.start(in: content)   // call once from RealityView setup
///   system.stop()               // call on scene clear / reset
//@MainActor
//final class NatureParticleSystem {
//
//    // MARK: - Configuration
//    struct Config {
//        /// Total particles in the pool (leaves + petals combined).
//        var totalCount:    Int   = 120
//        /// Fraction of particles that are sakura petals (rest are leaves).
//        var sakuraFraction: Double = 0.45
//        /// World-space Y at which particles spawn (above the user's head).
//        var spawnYMax:     Float = 3.8
//        /// Particles below this Y are recycled.
//        var floorY:        Float = -0.3
//        /// Horizontal spread radius around origin.
//        var spawnRadius:   Float = 5.0
//        /// Depth range (Z) — negative = in front of user.
//        var spawnZMin:     Float = -5.0
//        var spawnZMax:     Float =  1.5
//        /// Vertical fall speed range (m/s).
//        var fallSpeedMin:  Float = 0.08
//        var fallSpeedMax:  Float = 0.22
//        /// Horizontal wind drift speed range (m/s).
//        var driftMin:      Float = -0.06
//        var driftMax:      Float =  0.12
//        /// Sway amplitude (metres, sinusoidal side-to-side).
//        var swayAmpMin:    Float = 0.018
//        var swayAmpMax:    Float = 0.055
//        /// Sway frequency range (Hz).
//        var swayFreqMin:   Float = 0.25
//        var swayFreqMax:   Float = 0.65
//        /// Tumble (rotation) speed range (radians/s).
//        var tumbleMin:     Float = 0.4
//        var tumbleMax:     Float = 1.8
//        /// Physics tick interval.
//        var tickInterval:  TimeInterval = 1.0 / 30.0
//    }
//
//    var config = Config()
//
//    // MARK: - Private state
//    private var particles:  [ParticleState] = []
//    private var timer:      Timer?
//    private var rootAnchor: Entity?
//    private var elapsed:    Float = 0   // total seconds since start
//
//    // MARK: - Public API
//
//    func start(in content: RealityViewContent) {
//        let anchor = Entity()
//        anchor.position = .zero
//        content.add(anchor)
//        rootAnchor = anchor
//
//        buildPool()
//        startTimer()
//    }
//
//    func stop() {
//        timer?.invalidate()
//        timer = nil
//        rootAnchor?.children.removeAll()
//        rootAnchor?.removeFromParent()
//        rootAnchor = nil
//        particles.removeAll()
//        elapsed = 0
//    }
//
//    // MARK: - Particle pool construction
//
//    private func buildPool() {
//        guard let anchor = rootAnchor else { return }
//        let sakuraCount = Int(Double(config.totalCount) * config.sakuraFraction)
//
//        for i in 0..<config.totalCount {
//            let kind: ParticleKind = i < sakuraCount ? .sakura : .leaf
//            let entity = makeEntity(kind: kind)
//            anchor.addChild(entity)
//
//            let state = ParticleState(
//                entity:       entity,
//                kind:         kind,
//                position:     randomSpawnPosition(firstFrame: true),
//                fallSpeed:    Float.random(in: config.fallSpeedMin...config.fallSpeedMax),
//                driftX:       Float.random(in: config.driftMin...config.driftMax),
//                swayAmp:      Float.random(in: config.swayAmpMin...config.swayAmpMax),
//                swayFreq:     Float.random(in: config.swayFreqMin...config.swayFreqMax),
//                swayPhase:    Float.random(in: 0...(2 * .pi)),
//                tumbleSpeed:  Float.random(in: config.tumbleMin...config.tumbleMax),
//                tumbleAxis:   randomTumbleAxis(),
//                tumbleAngle:  Float.random(in: 0...(2 * .pi))
//            )
//            particles.append(state)
//        }
//
//        // Apply initial transforms
//        for p in particles {
//            p.entity.position    = p.position
//            p.entity.orientation = simd_quatf(angle: p.tumbleAngle, axis: p.tumbleAxis)
//        }
//    }
//
//    // MARK: - Physics tick
//
//    private func startTimer() {
//        timer = Timer.scheduledTimer(
//            withTimeInterval: config.tickInterval,
//            repeats: true
//        ) { [weak self] _ in
//            Task { @MainActor [weak self] in
//                self?.tick()
//            }
//        }
//    }
//
//    private func tick() {
//        let dt = Float(config.tickInterval)
//        elapsed += dt
//
//        for p in particles {
//            // ── Vertical fall ──────────────────────────────────────────
//            p.position.y -= p.fallSpeed * dt
//
//            // ── Sinusoidal horizontal sway ─────────────────────────────
//            let sway = p.swayAmp * sin(2 * .pi * p.swayFreq * elapsed + p.swayPhase)
//            p.position.x += (p.driftX + sway * 0.6) * dt
//
//            // ── Depth waver (gentle Z drift makes it feel 3-D) ─────────
//            p.position.z += sin(elapsed * 0.4 + p.swayPhase) * 0.008 * dt
//
//            // ── Recycle below floor ────────────────────────────────────
//            if p.position.y < config.floorY {
//                p.position = randomSpawnPosition(firstFrame: false)
//                // Refresh drift so recycled particles don't all look alike
//                p.driftX   = Float.random(in: config.driftMin...config.driftMax)
//                p.swayPhase = Float.random(in: 0...(2 * .pi))
//            }
//
//            // ── Tumble rotation ────────────────────────────────────────
//            p.tumbleAngle += p.tumbleSpeed * dt
//            let rot = simd_quatf(angle: p.tumbleAngle, axis: p.tumbleAxis)
//
//            // ── Apply to entity (no allocation — reuse existing transform) ──
//            p.entity.position    = p.position
//            p.entity.orientation = rot
//        }
//    }
//
//    // MARK: - Entity factory
//
//    private func makeEntity(kind: ParticleKind) -> ModelEntity {
//        switch kind {
//        case .sakura: return makeSakuraPetal()
//        case .leaf:   return makeLeaf()
//        }
//    }
//
//    /// Sakura petal — thin diamond-ish shape with rounded corners, pink/white.
//    private func makeSakuraPetal() -> ModelEntity {
//        // Approximate petal: slightly wider than tall box, very thin
//        let mesh = MeshResource.generateBox(
//            width:  Float.random(in: 0.028...0.044),
//            height: Float.random(in: 0.020...0.032),
//            depth:  0.003,
//            cornerRadius: 0.010
//        )
//        let color = sakuraColor()
//        var mat = PhysicallyBasedMaterial()
//        mat.baseColor = .init(tint: color)
//        mat.roughness = .init(floatLiteral: Float.random(in: 0.35...0.55))
//        mat.metallic  = .init(floatLiteral: 0.05)
//        // Subtle subsurface glow via emissive tint
//        mat.emissiveColor     = PhysicallyBasedMaterial.EmissiveColor(
//            color: color.withAlphaComponent(0.15))
//        mat.emissiveIntensity = 0.25
//        return ModelEntity(mesh: mesh, materials: [mat])
//    }
//
//    /// Leaf — wider, flatter, earthy autumn tones with slight curl.
//    private func makeLeaf() -> ModelEntity {
//        let w = Float.random(in: 0.038...0.065)
//        let h = Float.random(in: 0.028...0.048)
//        let mesh = MeshResource.generateBox(
//            width:  w,
//            height: h,
//            depth:  0.004,
//            cornerRadius: 0.006
//        )
//        var mat = PhysicallyBasedMaterial()
//        mat.baseColor = .init(tint: leafColor())
//        mat.roughness = .init(floatLiteral: Float.random(in: 0.70...0.90))
//        mat.metallic  = .init(floatLiteral: 0.0)
//        return ModelEntity(mesh: mesh, materials: [mat])
//    }
//
//    // MARK: - Colour palettes
//
//    private func sakuraColor() -> UIColor {
//        let palette: [UIColor] = [
//            UIColor(red: 1.00, green: 0.80, blue: 0.86, alpha: 0.92),  // blush pink
//            UIColor(red: 0.99, green: 0.71, blue: 0.78, alpha: 0.88),  // rose pink
//            UIColor(red: 1.00, green: 0.88, blue: 0.90, alpha: 0.95),  // pale petal
//            UIColor(red: 0.98, green: 0.76, blue: 0.82, alpha: 0.90),  // deep blush
//            UIColor(red: 1.00, green: 0.94, blue: 0.96, alpha: 0.97),  // almost white
//            UIColor(red: 0.95, green: 0.65, blue: 0.75, alpha: 0.85),  // warm rose
//            UIColor(red: 1.00, green: 0.96, blue: 0.98, alpha: 1.00),  // pure white-pink
//        ]
//        return palette.randomElement()!
//    }
//
//    private func leafColor() -> UIColor {
//        let palette: [UIColor] = [
//            UIColor(red: 0.76, green: 0.47, blue: 0.18, alpha: 0.90),  // amber
//            UIColor(red: 0.85, green: 0.35, blue: 0.10, alpha: 0.92),  // burnt orange
//            UIColor(red: 0.60, green: 0.72, blue: 0.35, alpha: 0.88),  // spring green
//            UIColor(red: 0.82, green: 0.62, blue: 0.22, alpha: 0.90),  // golden yellow
//            UIColor(red: 0.45, green: 0.62, blue: 0.28, alpha: 0.85),  // deep green
//            UIColor(red: 0.72, green: 0.28, blue: 0.15, alpha: 0.90),  // deep red-brown
//            UIColor(red: 0.88, green: 0.74, blue: 0.30, alpha: 0.92),  // light gold
//            UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 0.88),  // dark brown
//        ]
//        return palette.randomElement()!
//    }
//
//    // MARK: - Helpers
//
//    private func randomSpawnPosition(firstFrame: Bool) -> SIMD3<Float> {
//        let x = Float.random(in: -config.spawnRadius...config.spawnRadius)
//        // On first frame, scatter particles across full height so there's no
//        // "all particles falling from top" flash at startup.
//        let y: Float = firstFrame
//            ? Float.random(in: config.floorY...config.spawnYMax)
//            : Float.random(in: config.spawnYMax - 0.3 ... config.spawnYMax)
//        let z = Float.random(in: config.spawnZMin...config.spawnZMax)
//        return SIMD3<Float>(x, y, z)
//    }
//
//    private func randomTumbleAxis() -> SIMD3<Float> {
//        // Mostly tumble around X or Z (so the flat face flips naturally)
//        // with a little Y spin for variety
//        let x = Float.random(in: 0.2...1.0)
//        let y = Float.random(in: 0.0...0.4)
//        let z = Float.random(in: 0.2...1.0)
//        let len = sqrt(x*x + y*y + z*z)
//        return SIMD3<Float>(x/len, y/len, z/len)
//    }
//}
//
//// MARK: - Supporting types
//
//private enum ParticleKind { case sakura, leaf }
//
///// Heap-allocated per-particle mutable state (class so the timer
///// can mutate without copying the array on every tick).
//private final class ParticleState {
//    let entity:      ModelEntity
//    let kind:        ParticleKind
//    var position:    SIMD3<Float>
//    var fallSpeed:   Float
//    var driftX:      Float
//    let swayAmp:     Float
//    let swayFreq:    Float
//    var swayPhase:   Float
//    let tumbleSpeed: Float
//    let tumbleAxis:  SIMD3<Float>
//    var tumbleAngle: Float
//
//    init(entity: ModelEntity, kind: ParticleKind, position: SIMD3<Float>,
//         fallSpeed: Float, driftX: Float, swayAmp: Float, swayFreq: Float,
//         swayPhase: Float, tumbleSpeed: Float, tumbleAxis: SIMD3<Float>,
//         tumbleAngle: Float) {
//        self.entity      = entity
//        self.kind        = kind
//        self.position    = position
//        self.fallSpeed   = fallSpeed
//        self.driftX      = driftX
//        self.swayAmp     = swayAmp
//        self.swayFreq    = swayFreq
//        self.swayPhase   = swayPhase
//        self.tumbleSpeed = tumbleSpeed
//        self.tumbleAxis  = tumbleAxis
//        self.tumbleAngle = tumbleAngle
//    }
//}

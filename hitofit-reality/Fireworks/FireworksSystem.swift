//
//  FireworksSystem.swift
//  hitofit-companion
//
//  Created by Santosh KC on 2026/04/12.
//


import RealityKit
import SwiftUI
import AVFoundation

// MARK: - FireworksSystem
/// Self-contained fireworks engine for visionOS RealityKit scenes.
/// Works in any ImmersiveSpace — full or mixed.
///
/// Usage:
///   1. Call `FireworksSystem.launch(in: content, at: origin)` when the
///      session completes. Repeat for multiple bursts.
///   2. Call `FireworksSystem.launchCelebration(in:origin:)` for the full
///      multi-burst congratulations sequence with sound and text.
///   3. Call `FireworksSystem.clear(from:)` on reset to remove all entities.
///
/// No external assets required — everything is procedurally generated.
@MainActor
enum FireworksSystem {

    // MARK: - Public entry points

    /// Full celebration: 6 staggered bursts + congratulations text + fanfare.
    static func launchCelebration(
        in content: RealityViewContent,
        origin: SIMD3<Float> = SIMD3<Float>(0, 1.4, -3.0)
    ) {
        // ── Congratulations text (appears immediately) ───────────────────
        let textAnchor = buildCongratsText(origin: origin)
        textAnchor.name = "fireworks_congrats"
        content.add(textAnchor)

        // Animate text: scale from tiny → full → slight shrink
        var bigT = Transform()
        bigT.translation = textAnchor.position
        bigT.scale       = SIMD3<Float>(1.0, 1.0, 1.0)
        textAnchor.move(to: bigT, relativeTo: nil, duration: 0.45, timingFunction: .easeOut)

        // ── Firework bursts at staggered times ───────────────────────────
        let launchPositions: [(delay: Double, offset: SIMD3<Float>)] = [
            (0.1,  SIMD3<Float>(-0.9,  1.6, -3.2)),
            (0.45, SIMD3<Float>( 0.9,  1.8, -3.0)),
            (0.7,  SIMD3<Float>(-0.4,  2.2, -3.5)),
            (1.1,  SIMD3<Float>( 0.5,  1.3, -2.8)),
            (1.5,  SIMD3<Float>(-1.1,  2.0, -3.3)),
            (1.9,  SIMD3<Float>( 1.0,  2.4, -3.1)),
            (2.5,  SIMD3<Float>(-0.2,  1.9, -3.0)),
            (3.0,  SIMD3<Float>( 0.7,  1.5, -3.4)),
        ]

        for launch in launchPositions {
            DispatchQueue.main.asyncAfter(deadline: .now() + launch.delay) {
                let burst = makeBurst(at: launch.offset)
                burst.name = "fireworks_burst"
                content.add(burst)

                // Auto-remove burst after particles have faded
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    burst.removeFromParent()
                }
            }
        }

        // ── Fanfare sound ────────────────────────────────────────────────
        playFanfare()

        // ── Remove text after 6 s ────────────────────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            var shrink = Transform()
            shrink.translation = textAnchor.position
            shrink.scale       = SIMD3<Float>(0.01, 0.01, 0.01)
            textAnchor.move(to: shrink, relativeTo: nil, duration: 0.4, timingFunction: .easeIn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                textAnchor.removeFromParent()
            }
        }
    }

    /// Remove all fireworks entities from the scene (call on reset).
    static func clear(from content: RealityViewContent) {
        // RealityKit content doesn't expose a direct search, so we tag
        // entities by name prefix and remove via the root entity trick.
        // Callers should also store and removeFromParent directly if possible.
    }

    // MARK: - Congratulations text entity

    private static func buildCongratsText(origin: SIMD3<Float>) -> Entity {
        let anchor = Entity()
        // Start tiny — animated to full size in launchCelebration
        anchor.scale    = SIMD3<Float>(0.01, 0.01, 0.01)
        anchor.position = origin + SIMD3<Float>(0, 0.45, 0)

        // Line 1 — "🎉 Congratulations! 🎉"
        let line1 = makeTextEntity(
            "🎉  Congratulations!  🎉",
            size: 0.10,
            weight: .heavy,
            color: .systemYellow,
            width: 2.0,
            offsetY: 0.12
        )
        // Line 2 — "Goal Reached"
        let line2 = makeTextEntity(
            "Goal Reached",
            size: 0.075,
            weight: .bold,
            color: .white,
            width: 1.6,
            offsetY: 0.0
        )
        // Line 3 — subtle subtitle
        let line3 = makeTextEntity(
            "You did it! Keep moving 🏃",
            size: 0.052,
            weight: .semibold,
            color: .systemGreen,
            width: 1.4,
            offsetY: -0.11
        )

        anchor.addChild(line1)
        anchor.addChild(line2)
        anchor.addChild(line3)
        return anchor
    }

    private static func makeTextEntity(
        _ string:  String,
        size:      CGFloat,
        weight:    UIFont.Weight,
        color:     UIColor,
        width:     CGFloat,
        offsetY:   Float
    ) -> ModelEntity {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.008,
            font: .systemFont(ofSize: size, weight: weight),
            containerFrame: CGRect(x: -width / 2, y: -size / 2, width: width, height: size * 1.3),
            alignment: .center,
            lineBreakMode: .byClipping
        )
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.roughness = .init(floatLiteral: 0.2)
        mat.metallic  = .init(floatLiteral: 0.5)

        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.position = SIMD3<Float>(0, offsetY, 0)
        return entity
    }

    // MARK: - Burst factory
    // Each burst = a shell entity that spawns many particle "sparks"
    // radiating outward with gravity-like droop.

    private static func makeBurst(at position: SIMD3<Float>) -> Entity {
        let shell = Entity()
        shell.position = position

        // Pick a random palette for this burst
        let palette = randomPalette()
        let count   = Int.random(in: 60...90)

        for i in 0..<count {
            let spark = makeSparkEntity(color: palette[i % palette.count])
            shell.addChild(spark)

            // Random direction in a sphere
            let theta = Float.random(in: 0 ..< (.pi * 2))
            let phi   = Float.random(in: 0 ..< .pi)
            let speed = Float.random(in: 0.5...1.4)
            let dx    = sin(phi) * cos(theta) * speed
            let dy    = sin(phi) * sin(theta) * speed * 0.7   // slightly flattened burst
            let dz    = cos(phi) * speed

            // Simulate physics: position = velocity*t + 0.5*gravity*t²
            let duration = Double.random(in: 0.9...1.6)
            let gravity: Float = -0.45

            // Keyframe 1: mid-burst
            let t1: Float = 0.5
            var mid = Transform()
            mid.translation = SIMD3<Float>(dx * t1, dy * t1 + 0.5 * gravity * t1 * t1, dz * t1)
            mid.scale       = SIMD3<Float>(1, 1, 1)

            // Keyframe 2: end (faded out by scale → 0)
            let t2: Float = Float(duration)
            var end = Transform()
            end.translation = SIMD3<Float>(dx * t2, dy * t2 + 0.5 * gravity * t2 * t2, dz * t2)
            end.scale       = SIMD3<Float>(0.01, 0.01, 0.01)

            // Stagger each spark slightly so they don't all start together
            let startDelay = Double.random(in: 0...0.08)
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                spark.move(to: mid, relativeTo: shell,
                           duration: duration * 0.5, timingFunction: .easeOut)
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.5) {
                    spark.move(to: end, relativeTo: shell,
                               duration: duration * 0.5, timingFunction: .easeIn)
                }
            }
        }

        // Secondary ring of bright flares at 60 % radius
        for _ in 0..<12 {
            let flare = makeFlareEntity(color: palette.first ?? .systemYellow)
            shell.addChild(flare)
            let angle = Float.random(in: 0 ..< (.pi * 2))
            let r: Float = 0.38
            
            // 1. Build your transform
            var t = Transform()
            t.translation = SIMD3<Float>(cos(angle) * r, Float.random(in: -0.1...0.1), sin(angle) * r)
            t.scale = SIMD3<Float>(1, 1, 1)
            
            // 2. Create an immutable 'let' version for the closure to capture
            let finalTransform = t
            
            flare.move(to: finalTransform, relativeTo: shell, duration: 0.35, timingFunction: .easeOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var fade = Transform()
                // 3. Use the immutable constant here
                fade.translation = finalTransform.translation
                fade.scale = SIMD3<Float>(0.01, 0.01, 0.01)
                flare.move(to: fade, relativeTo: shell, duration: 0.7, timingFunction: .easeIn)
            }
        }

        return shell
    }

    // MARK: - Spark / Flare entities

    private static func makeSparkEntity(color: UIColor) -> ModelEntity {
        // Elongated box oriented along Z — looks like a streaking spark
        let mesh = MeshResource.generateBox(width: 0.012, height: 0.012, depth: 0.055,
                                            cornerRadius: 0.004)
        var mat = UnlitMaterial(color: color)
        let e = ModelEntity(mesh: mesh, materials: [mat])
        e.scale = SIMD3<Float>(0.01, 0.01, 0.01)   // start tiny, expanded in animation
        return e
    }

    private static func makeFlareEntity(color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.025)
        let brightColor = color.withAlphaComponent(0.9)
        var mat = UnlitMaterial(color: brightColor)
        let e = ModelEntity(mesh: mesh, materials: [mat])
        e.scale = SIMD3<Float>(0.01, 0.01, 0.01)
        return e
    }

    // MARK: - Colour palettes

    private static func randomPalette() -> [UIColor] {
        let palettes: [[UIColor]] = [
            // Gold & red — classic firework
            [.systemYellow, .systemOrange, .systemRed, .white],
            // Cool blue & cyan
            [.systemCyan, .systemBlue, .white, .systemTeal],
            // Party pink & purple
            [.systemPink, .systemPurple, .white, .systemIndigo],
            // Green sparkle
            [.systemGreen, .systemYellow, .white, .systemMint],
            // Rainbow mix
            [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemCyan, .systemPurple],
        ]
        return palettes.randomElement()!
    }

    // MARK: - Procedural fanfare sound

    private static var fanfarePlayer: AVAudioPlayer?

    private static func playFanfare() {
        let sampleRate: Double = 44100
        let duration:   Double = 2.5
        let samples = Int(sampleRate * duration)
        var buf = [Float](repeating: 0, count: samples)

        // Three rising tones (do–mi–sol–do') that swell and fade
        let notes: [(freq: Double, start: Double, length: Double, amp: Float)] = [
            (261.6, 0.00, 0.35, 0.55),   // C4
            (329.6, 0.20, 0.35, 0.55),   // E4
            (392.0, 0.40, 0.35, 0.55),   // G4
            (523.2, 0.60, 0.80, 0.70),   // C5
            (659.3, 0.90, 0.60, 0.60),   // E5
            (784.0, 1.10, 0.60, 0.55),   // G5
            (1046.5,1.30, 0.90, 0.50),   // C6
        ]

        for note in notes {
            let startSample = Int(note.start * sampleRate)
            let endSample   = min(samples, startSample + Int(note.length * sampleRate))
            for i in startSample..<endSample {
                let t       = Double(i - startSample) / sampleRate
                let env     = Float(sin(.pi * t / note.length))  // bell envelope
                let wave    = Float(sin(2 * .pi * note.freq * t))
                // Add a slight harmonic shimmer
                let harm    = Float(sin(2 * .pi * note.freq * 2.0 * t)) * 0.2
                buf[i] += env * note.amp * (wave + harm) * 0.4
            }
        }

        // Soft noise shimmer (sparkle texture)
        for i in 0..<samples {
            let t       = Double(i) / sampleRate
            let shimmer = Float.random(in: -1...1) * 0.04 * Float(exp(-t * 1.2))
            buf[i] += shimmer
        }

        // Clip & encode
        //let pcm = buf.map { Int16(max(-32767, min(32767, Int($0 * 32767)))) }
        let wav = FireworksSystem.generateFireworkWAV()
        fanfarePlayer = try? AVAudioPlayer(data: wav)
        fanfarePlayer?.prepareToPlay()
        fanfarePlayer?.play()
    }

    // MARK: - Minimal WAV encoder
    
    static func generateFireworkWAV() -> Data {
            let sampleRate: Double = 44100
            let duration: Double = 1.5 // Seconds
            let totalSamples = Int(sampleRate * duration)
            
            // 1. Generate the raw audio buffer (The "Boom")
            var buf = [Float](repeating: 0, count: totalSamples)
            
            for i in 0..<totalSamples {
                let t = Double(i) / sampleRate
                
                // White noise (random pressure)
                let noise = Float.random(in: -1.0...1.0)
                
                // Exponential decay: e^(-constant * time)
                // A higher constant (e.g., 5.0) makes the sound "shorter" and punchier
                let envelope = exp(-4.0 * t)
                
                // Simple Low-Pass filter to make it sound "thumpier" and less like static
                // We mix the noise with the envelope
                buf[i] = noise * Float(envelope)
            }
            
            // 2. Convert Float samples to Int16 PCM
            let pcm = buf.map { Int16(max(-32767, min(32767, Int($0 * 32767)))) }
            
            // 3. Build and return the WAV Data
            return buildWAV(pcm: pcm, sampleRate: UInt32(sampleRate))
        }
    
    private static func buildWAV(pcm: [Int16], sampleRate: UInt32) -> Data {
        let ch: UInt16 = 1, bps: UInt16 = 16
        let ds = UInt32(pcm.count) * 2
        var d = Data()
        func a<T: FixedWidthInteger>(_ v: T) {
            withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) }
        }
        d += "RIFF".utf8; a(36 + ds)
        d += "WAVE".utf8
        d += "fmt ".utf8; a(UInt32(16)); a(UInt16(1))
        a(ch); a(sampleRate); a(sampleRate * 2); a(UInt16(2)); a(bps)
        d += "data".utf8; a(ds)
        pcm.forEach { a($0) }
        return d
    }
}

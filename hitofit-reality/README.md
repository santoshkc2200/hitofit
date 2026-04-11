# VisionParticles — visionOS Particle Emitter App

A visionOS app with 3 immersive full-space particle experiences: **Snow**, **Fireworks**, and **Rain**.

---

## Project Setup

### Requirements
- Xcode 15.2+
- visionOS 1.0+ SDK
- Apple Vision Pro simulator or device

### How to create the Xcode project

1. Open **Xcode → File → New → Project**
2. Select **visionOS → App**
3. Set:
   - **Product Name**: `VisionParticles`
   - **Bundle Identifier**: `com.yourname.VisionParticles`
   - **Immersive Space**: ✅ Check "Include immersive space"
4. Replace the generated files with the Swift files in this folder

### Files

| File | Purpose |
|------|---------|
| `VisionParticlesApp.swift` | App entry point — registers all 3 `ImmersiveSpace` scenes |
| `AppModel.swift` | `@Observable` state — tracks which space is open |
| `ContentView.swift` | Main window with 3 styled buttons |
| `ExitImmersiveButton.swift` | Reusable exit button shown inside each immersive space |
| `SnowImmersiveView.swift` | Full immersive snow particle emitter |
| `FireworksImmersiveView.swift` | Full immersive fireworks burst particle emitters |
| `RainImmersiveView.swift` | Full immersive rain + mist particle emitters |

### Required Info.plist entries

Add these to your `Info.plist`:

```xml
<key>NSWorldSensingUsageDescription</key>
<string>Used to anchor particles in your space</string>

<key>UIApplicationSceneManifest</key>
<!-- Xcode generates this automatically for visionOS apps -->
```

### Required Frameworks (add in Xcode target → General → Frameworks)
- `RealityKit.framework` ✅ (add if not already present)
- `SwiftUI.framework` ✅

---

## Architecture

```
VisionParticlesApp
├── WindowGroup → ContentView
│   ├── ❄️  Snow Button      → opens SnowSpace
│   ├── 🎆  Fireworks Button → opens FireworksSpace  
│   └── 🌧️  Rain Button      → opens RainSpace
│
├── ImmersiveSpace("SnowSpace")      → SnowImmersiveView
├── ImmersiveSpace("FireworksSpace") → FireworksImmersiveView
└── ImmersiveSpace("RainSpace")      → RainImmersiveView
```

Each immersive space:
- Uses `RealityView` with `ParticleEmitterComponent`
- Shows an **Exit** button via `RealityView` attachments (positioned at eye level)
- Dismisses via `dismissImmersiveSpace` environment action

---

## Particle Details

### ❄️ Snow
- Wide plane emitter 3m above, 6×6m spread
- 300 particles/sec, 6s lifespan
- Gentle `[0, -0.5, 0]` gravity for slow drifting fall
- Cool blue-white point light

### 🎆 Fireworks
- 5 sphere burst emitters at varied positions
- 80 particles/sec each with full `spreadingAngle: .pi` for starburst
- 5 different colors: red, gold, blue, green, pink
- Downward droop gravity `[0, -0.4, 0]` for realistic trail arc

### 🌧️ Rain
- Dense plane emitter (600/sec) with fast `speed: 2.5` and steep gravity `[0, -6, 0]`
- Secondary mist/splash emitter at ground level
- Upward `acceleration: [0, 0.2, 0]` for splatter effect
- Cool blue lighting + ground reflection light

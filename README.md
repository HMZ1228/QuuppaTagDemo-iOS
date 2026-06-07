# QuuppaTagDemo for iOS

> **Version 3.0** — May 2016 spec, 2025-compatible codebase  
> Language: Objective-C · Minimum deployment: iOS 13.0  
> Supported UI languages: English · 简体中文

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Project Structure](#project-structure)
4. [Architecture](#architecture)
5. [Quuppa Beacon Format](#quuppa-beacon-format)
6. [Features](#features)
7. [Scene Presets](#scene-presets)
8. [Localization](#localization)
9. [Build & Deploy](#build--deploy)
10. [App Store Checklist](#app-store-checklist)
11. [API Deprecated → Modern Replacements](#api-deprecated--modern-replacements)
12. [Known Limitations](#known-limitations)
13. [Changelog](#changelog)

---

## Overview

**QuuppaTagDemo** turns any iOS device into a **Quuppa Intelligent Locating System** tag.  
It broadcasts a standard iBeacon packet whose UUID encodes the Quuppa Direction-Finding (DF) payload.  
Quuppa locators receive these BLE advertisements and report the device position via the Quuppa Web Services API.

**QuuppaTagDemo** 将 iOS 设备转化为 **Quuppa 智能定位系统**的标签节点。  
应用广播符合 Quuppa 规范的 iBeacon 数据包，Quuppa 定位器收到信号后通过 Web Services API 上报设备位置。

---

## Requirements

| Item | Minimum |
|------|---------|
| iOS | 13.0 |
| Xcode | 15.0 |
| Swift | N/A (Objective-C) |
| Bluetooth | BLE Peripheral capable |
| Frameworks | CoreBluetooth · CoreLocation · CoreImage · Security · UIKit |

---

## Project Structure

```
QuuppaTagDemo/
├── AppDelegate.h / .m          # App lifecycle + Scene configuration (iOS 13+)
├── SceneDelegate.h / .m        # Window & scene lifecycle (iOS 13+)
├── ViewController.h / .m       # Main screen — fully programmatic UI
│
├── Views/
│   └── OnboardingOverlayView.h / .m   # 3-step first-launch onboarding
│
├── Managers/
│   └── TagHistoryManager.h / .m       # Recent Tag ID persistence (up to 10)
│
├── Utils/
│   ├── crc-8.h / .c                   # CRC-8 (poly 0x97) — unchanged from spec
│   └── QRCodeGenerator.h / .m         # CoreImage QR code generation
│
├── QuuppaLogoUiView.h / .m     # Animated Quuppa Q logo view
│
├── Info.plist                  # Bluetooth permissions + background mode
│
├── en.lproj/
│   └── Localizable.strings     # English strings
│
└── zh-Hans.lproj/
    └── Localizable.strings     # Simplified Chinese strings
```

---

## Architecture

```
ViewController
    │
    ├── TagHistoryManager (singleton)
    │       └── NSUserDefaults → last 10 Tag IDs
    │
    ├── OnboardingOverlayView (presented once on first launch)
    │       └── UIPageControl + 3 slides + completion block
    │
    ├── QRCodeGenerator
    │       └── CIFilter "CIQRCodeGenerator" → UIImage
    │
    ├── QuuppaLogoUiView
    │       └── Custom drawRect: — animated alpha pulse when broadcasting
    │
    └── CBPeripheralManager (global singleton, persists across view lifecycle)
            └── CLBeaconRegion → peripheralDataWithMeasuredPower: → startAdvertising:
```

### Data Flow

```
User taps "Random" / enters ID
        │
        ▼
ViewController builds 8-byte CRC input:
    [0x15, 0x1A, TagID[0..5]]
        │
        ▼
crc8() → checksum byte
        │
        ▼
UUID string assembled:
    {Header}{TagID[0..2]}-{TagID[3..4]}-{CRC}{TagID[5]}-67F7-DB34C4038E5C
        │
        ▼
Stored in NSUserDefaults ("UUIDString", "tagID")
        │
        ▼
CBPeripheralManager.startAdvertising(peripheralData)
```

---

## Quuppa Beacon Format

### iBeacon fields (fixed per Quuppa spec v1.0)

| Field | Value | Notes |
|-------|-------|-------|
| Major | `0x0BAA` = 2986 | Fixed |
| Minor | `0x9730` = 38704 | Fixed |
| Measured Power | `0x56` = 86 | Base; presets offset this |

### UUID structure (16 octets)

```
Octet:  00    01    02    03  │  04    05  │  06    07  │  08  09  10  11  12  13  14  15
Field:  Hdr   ──── Quuppa Tag ID (6 bytes) ────  CRC   │  ────── DF Field (8 bytes) ───────
Value:  0x1A                                    CRC-8   │  67  F7  DB  34  C4  03  8E  5C
```

**Header** = `0x1A` (fixed)

**Quuppa Tag ID** = 6-byte big-endian device identifier (MSB first)

**Checksum** = CRC-8 over `[0x15, 0x1A, TagID[0]…TagID[5]]`
- Polynomial: `0x97`
- Initial value: `0x00`
- No input/output reflection
- No final XOR

**DF Field** = `67 F7 DB 34 C4 03 8E 5C` (fixed)

### Example

```
Tag ID:    0x112233445566
CRC input: [0x15, 0x1A, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66]
CRC-8:     0x87
UUID:      1A112233-4455-6687-67F7-DB34C4038E5C
```

### UUID String Format for `CLBeaconRegion`

```
%02X%02X%02X%02X-%02X%02X-%02X%02X-67F7-DB34C4038E5C
 Hdr  T0   T1   T2    T3   T4    T5  CRC
```

---

## Features

### v3.0 (Current)

| Feature | Description |
|---------|-------------|
| **Random Tag ID** | `SecRandomCopyBytes` — cryptographically secure 6-byte generation |
| **Manual Tag ID** | Inline text field with hex validation and error flash animation |
| **Tag ID History** | `TagHistoryManager` stores last 10 IDs; one-tap to restore any previous ID |
| **QR Code** | CoreImage `CIQRCodeGenerator` → presented in a modal sheet with share button |
| **Scene Presets** | 4 presets (Stationary / Walking / Running / Vehicle) with visual battery bars |
| **Bilingual UI** | EN / 简体中文, auto-detected from `[NSLocale preferredLanguages]`, persisted |
| **Onboarding** | 3-step overlay on first launch; skip-able; shown once per install |
| **Background Mode** | `bluetooth-peripheral` UIBackgroundMode — continues advertising when app backgrounded |
| **Haptic Feedback** | `UIImpactFeedbackGenerator` on all primary actions |
| **Programmatic UI** | No storyboard required; full Auto Layout in code |
| **Settings Persistence** | All state saved to `NSUserDefaults` and restored on next launch |
| **Animated Logo** | `QuuppaLogoUiView` pulses rings when broadcasting; stops cleanly via `[layer removeAllAnimations]` |

---

## Scene Presets

iOS CoreBluetooth does not expose a direct advertising-interval knob for iBeacon mode.  
The system targets ≈ 100 ms between packets in foreground, backing off in background.  
The **measuredPower** value passed to `peripheralDataWithMeasuredPower:` is the signal we **can** tune.  
Quuppa locators use this value as the reference RSSI for distance estimation.

| Preset | Display Hz | measuredPower | Use Case |
|--------|-----------|---------------|----------|
| Stationary | 1 Hz | 86 (Quuppa spec ref.) | Office / indoor asset, person standing still |
| Walking | 3 Hz | 75 | Pedestrian, slow movement |
| Running | 5 Hz | 69 | Athlete, fast-walking |
| Vehicle | 10 Hz | 60 | Car / forklift / large open space |

Battery impact indicator (shown in UI):
- Stationary → 1 blue bar (lowest drain)
- Walking → 2 green bars
- Running → 3 amber bars
- Vehicle → 4 red bars (highest drain)

---

## Localization

Strings are managed via a compile-time `QLangKey` enum and a `Loc(key, BOOL chinese)` inline helper in `ViewController.m`.

To add a new language:
1. Add a new column to the `table` array in `Loc()`.
2. Create the corresponding `xx.lproj/Localizable.strings` file for reference.
3. Pass the appropriate boolean or extend the helper for n-ary language support.

For a production app with many languages, migrate to standard `NSLocalizedString` + `.strings` bundles and set `CFBundleLocalizations` in `Info.plist`.

---

## Build & Deploy

### 1. Clone / copy files

Place files according to [Project Structure](#project-structure).  
No third-party dependencies — all frameworks are system-provided.

### 2. Xcode project settings

| Setting | Value |
|---------|-------|
| Deployment Target | iOS 13.0 |
| Capabilities → Background Modes | ☑ Uses Bluetooth LE accessories |
| Capabilities → Bluetooth | ☑ (auto-adds entitlement) |
| Bundle Identifier | `com.yourcompany.QuuppaTagDemo` |

### 3. Info.plist keys (already included)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>QuuppaTagDemo uses Bluetooth to broadcast your device as a Quuppa location tag.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>QuuppaTagDemo uses Bluetooth to broadcast your device as a Quuppa location tag.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-peripheral</string>
</array>
```

### 4. Storyboard

The `ViewController` builds its entire UI programmatically.  
In `Main.storyboard`, set the root view controller's **Custom Class** to `ViewController` and delete any existing layout.  
Alternatively, remove the storyboard reference and create the window in `SceneDelegate`.

### 5. Run

Build & run on a **physical device** (BLE peripheral mode is not available in Simulator).

---

## App Store Checklist

- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) declaring `NSUserDefaults` usage
- [ ] `NSBluetoothAlwaysUsageDescription` string matches your actual use
- [ ] Background mode entitlement matches `Info.plist` `UIBackgroundModes`
- [ ] App icon provided for all required sizes (see `Contents.json`)
- [ ] Launch screen storyboard present
- [ ] `CFBundleShortVersionString` and `CFBundleVersion` incremented
- [ ] Tested on physical device (BLE required)
- [ ] Tested with Bluetooth permission denied → graceful alert shown
- [ ] Tested backgrounding while broadcasting → advertising continues
- [ ] Age rating questionnaire: no in-app purchases, no user-generated content

---

## API Deprecated → Modern Replacements

| Original (2015) | Replacement (iOS 13+) | Notes |
|---|---|---|
| `UIAlertView` | `UIAlertController` | Block-based, no delegate |
| `UIAlertViewDelegate` | Completion block in `UIAlertAction` | |
| `CBPeripheralManagerStatePoweredOn` | `CBManagerStatePoweredOn` | `CBPeripheralManagerState` → `CBManagerState` |
| `CLBeaconRegion initWithProximityUUID:major:minor:identifier:` | `initWithUUID:major:minor:identifier:` | iOS 13+ |
| `CLBeacon proximityUUID` | `CLBeacon UUID` | iOS 13+ |
| `[layer removeAllAnimations]` absent | Used in `QuuppaLogoUiView.stopAnim` | Properly cancels repeating UIView animations |
| `AppDelegate.window` (sole window) | `SceneDelegate.window` | iOS 13+ multi-scene lifecycle |

---

## Known Limitations

1. **Advertising interval is not user-controllable on iOS.**  
   The OS targets ≈ 100 ms between packets in foreground, ≈ 1 s in background.  
   The "Hz" values in scene presets are informational labels for Quuppa backend configuration, not actual OS-level rates.

2. **iOS iBeacon UUID must contain the Quuppa-formatted payload.**  
   Unlike Android (which uses manufacturer-specific data), iOS uses the `proximityUUID` field.  
   The UUID layout encodes Header + Tag ID + CRC + DF Field as described in the Quuppa spec.

3. **Background advertising requires the app to have been granted Bluetooth permission.**  
   If the user denies Bluetooth access, background advertising is not possible.

4. **The Simulator does not support BLE peripheral mode.**  
   Always test on a physical device.

5. **`CLBeaconRegion peripheralDataWithMeasuredPower:` may be deprecated in a future iOS.**  
   If Apple removes iBeacon peripheral support, the app would need to switch to  
   raw `CBAdvertisementDataServiceUUIDsKey` advertising with a custom UUID encoding.

---

## Changelog

### v3.0 (2025)
- Added `TagHistoryManager` — stores last 10 Tag IDs, one-tap to restore
- Added QR code generation via `CIFilter` (CoreImage, no external lib)
- Added share sheet (`UIActivityViewController`) on QR screen
- Added `OnboardingOverlayView` — 3-step first-launch walkthrough
- Added `UIImpactFeedbackGenerator` haptic feedback on all primary actions
- Added background BLE advertising (`bluetooth-peripheral` UIBackgroundMode)
- Added battery-impact bar indicators to scene preset cards
- Added LIVE indicator (pulsing green dot) when broadcasting
- Programmatic UI — no storyboard dependency

### v2.0 (2025)
- Full programmatic UI (`ViewController` builds all views in code)
- Added bilingual support: EN / 简体中文 with auto-detection
- Added 4 scene presets with distinct `measuredPower` values
- Added random Tag ID generation via `SecRandomCopyBytes`
- Replaced all deprecated APIs (UIAlertView, CBPeripheralManagerState, etc.)
- Added `SceneDelegate` for iOS 13+ scene lifecycle
- Added `NSBluetoothAlwaysUsageDescription` to Info.plist

### v1.0 (2015 — Quuppa original)
- Initial release
- `UIAlertView`-based Tag ID entry
- Single tap to toggle broadcasting
- CoreLocation iBeacon advertising with Quuppa UUID format

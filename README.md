# QuuppaTagDemo-iOS

<div align="center">

![Platform](https://img.shields.io/badge/Platform-iOS%2013%2B-blue)
![Language](https://img.shields.io/badge/Language-Objective--C-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-3.0-purple)

**Language / 语言 / 言語 / Idioma**

[English](#english) · [中文](#中文) · [日本語](#日本語) · [Español](#español)

</div>

---

## English

### Overview

**QuuppaTagDemo** turns any iPhone or iPad into a **Quuppa Intelligent Locating System** tag.
It broadcasts a standard iBeacon packet whose UUID encodes the Quuppa Direction-Finding (DF) payload,
allowing Quuppa locators to detect and report the device's precise indoor position in real time
via the Quuppa Web Services API.

### Features

| Feature | Description |
|---------|-------------|
| **Random Tag ID** | Cryptographically secure 6-byte ID via `SecRandomCopyBytes` |
| **Manual Tag ID** | Inline hex input with validation and error animation |
| **ID History** | Stores last 10 Tag IDs — tap any to restore instantly |
| **QR Code** | CoreImage QR generation + system share sheet |
| **Scene Presets** | Stationary / Walking / Running / Vehicle — calibrated `measuredPower` + battery indicator |
| **Bilingual UI** | English / 简体中文 — auto-detected from device locale, user-switchable |
| **Onboarding** | 3-step first-launch walkthrough, skippable |
| **Background BLE** | Continues advertising when backgrounded (`bluetooth-peripheral` mode) |
| **Haptic Feedback** | `UIImpactFeedbackGenerator` on all primary actions |
| **Programmatic UI** | Full Auto Layout in code — no Storyboard required |

### Requirements

- iOS 13.0+  ·  Xcode 15+  ·  Physical device (Simulator cannot act as BLE peripheral)
- Frameworks: CoreBluetooth · CoreLocation · CoreImage · Security · UIKit

### Quick Start

```bash
git clone https://github.com/HMZ1228/QuuppaTagDemo-iOS.git
```

1. Open `QuuppaTagDemo.xcodeproj` in Xcode
2. Enable **Signing & Capabilities → Background Modes → Uses Bluetooth LE accessories**
3. Build and run on a physical device
4. Tap **Random** to generate a Tag ID, choose a scene preset, tap **Start Broadcasting**

### Quuppa Beacon Format

```
UUID (16 bytes)
┌──────────┬───────────────────┬──────────┬──────────────────────┐
│ Header   │ Quuppa Tag ID     │ CRC-8    │ DF Field             │
│ 0x1A (1B)│ 6 bytes MSB→LSB   │ 1 byte   │ 67F7DB34C4038E5C (8B)│
└──────────┴───────────────────┴──────────┴──────────────────────┘
Major: 0x0BAA (2986)  Minor: 0x9730 (38704)
CRC-8: poly=0x97, input=[0x15, 0x1A, TagID bytes]
```

### Scene Presets

| Preset | Hz | measuredPower | Use Case |
|--------|----|---------------|----------|
| Stationary | 1 | 86 (Quuppa spec ref.) | Indoor fixed asset / person standing still |
| Walking | 3 | 75 | Pedestrian, slow movement |
| Running | 5 | 69 | Athlete, fast movement |
| Vehicle | 10 | 60 | Car / forklift / large open space |

---

## 中文

### 项目简介

**QuuppaTagDemo** 将 iPhone 或 iPad 变为 **Quuppa 智能定位系统**的位置标签。
应用广播符合 Quuppa 规范的 iBeacon 数据包，UUID 中编码了 Quuppa 方向寻找（DF）载荷，
使 Quuppa 定位器能够通过 Web Services API 实时上报设备的室内精确位置。

### 功能特性

| 功能 | 说明 |
|------|------|
| **随机标签 ID** | 通过 `SecRandomCopyBytes` 生成密码学安全的 6 字节标识符 |
| **手动输入 ID** | 内联十六进制输入框，含格式验证与错误动画 |
| **ID 历史记录** | 保存最近 10 条标签 ID，一键恢复任意历史记录 |
| **二维码分享** | CoreImage 生成 QR 码 + 系统分享面板 |
| **场景预设** | 静止 / 步行 / 跑步 / 驾驶，各预设对应不同 `measuredPower` 值和电量消耗指示 |
| **双语界面** | 英文 / 简体中文，自动识别设备语言，支持手动切换 |
| **新手引导** | 首次启动时显示 3 步引导页，可跳过 |
| **后台广播** | 应用切入后台后继续发送 BLE 信号（`bluetooth-peripheral` 模式） |
| **触感反馈** | 所有主要操作均使用 `UIImpactFeedbackGenerator` 提供震动反馈 |
| **全代码 UI** | 纯 Auto Layout 编写，无需 Storyboard |

### 系统要求

- iOS 13.0+  ·  Xcode 15+  ·  真机设备（模拟器不支持 BLE 外设模式）
- 所需框架：CoreBluetooth · CoreLocation · CoreImage · Security · UIKit

### 快速开始

```bash
git clone https://github.com/HMZ1228/QuuppaTagDemo-iOS.git
```

1. 用 Xcode 打开 `QuuppaTagDemo.xcodeproj`
2. 在 **Signing & Capabilities → Background Modes** 中勾选 **Uses Bluetooth LE accessories**
3. 连接真机编译运行
4. 点击**随机生成**生成标签 ID，选择场景预设，点击**开始广播**

### 场景预设说明

| 预设 | 频率 | measuredPower | 适用场景 |
|------|------|---------------|---------|
| 静止 | 1 Hz | 86（Quuppa 规范参考值） | 室内固定资产、静止人员 |
| 步行 | 3 Hz | 75 | 行人，缓慢移动 |
| 跑步 | 5 Hz | 69 | 运动员，快速移动 |
| 驾驶 | 10 Hz | 60 | 车辆、叉车、大型开阔空间 |

> **注意**：iOS 不允许直接控制 iBeacon 广播间隔，频率数值为 Quuppa 后端的参考配置标签，实际广播间隔由系统管理（前台约 100 ms）。

---

## 日本語

### 概要

**QuuppaTagDemo** は iPhone や iPad を **Quuppa インテリジェント・ロケーティング・システム**のタグとして機能させるアプリです。
Quuppa の Direction-Finding (DF) ペイロードを UUID に組み込んだ標準 iBeacon パケットをブロードキャストし、
Quuppa ロケーターが Web Services API を通じてデバイスの正確な屋内位置をリアルタイムで報告できます。

### 主な機能

| 機能 | 説明 |
|------|------|
| **ランダム Tag ID 生成** | `SecRandomCopyBytes` による暗号学的に安全な 6 バイト ID |
| **手動 Tag ID 入力** | 16 進数インライン入力・バリデーション・エラーアニメーション付き |
| **ID 履歴** | 直近 10 件の Tag ID を保存、タップで即座に復元 |
| **QR コード共有** | CoreImage による QR 生成 + システム共有シート |
| **シーンプリセット** | 静止 / 歩行 / 走行 / 車両 — `measuredPower` を最適化、バッテリー消費インジケーター付き |
| **多言語 UI** | 英語 / 简体字中国語 — デバイスロケールを自動検出、手動切替可能 |
| **オンボーディング** | 初回起動時に 3 ステップのガイドを表示（スキップ可能） |
| **バックグラウンド BLE** | バックグラウンド移行後も BLE 広告を継続（`bluetooth-peripheral` モード） |
| **触覚フィードバック** | すべての主要操作で `UIImpactFeedbackGenerator` による振動フィードバック |
| **プログラマティック UI** | Auto Layout をコードで完全実装 — Storyboard 不要 |

### 動作環境

- iOS 13.0+  ·  Xcode 15+  ·  実機（シミュレーターは BLE ペリフェラルモード非対応）
- 使用フレームワーク：CoreBluetooth · CoreLocation · CoreImage · Security · UIKit

### クイックスタート

```bash
git clone https://github.com/HMZ1228/QuuppaTagDemo-iOS.git
```

1. `QuuppaTagDemo.xcodeproj` を Xcode で開く
2. **Signing & Capabilities → Background Modes → Uses Bluetooth LE accessories** を有効化
3. 実機にビルド・実行
4. **ランダム** をタップして Tag ID を生成 → シーンプリセットを選択 → **ブロードキャスト開始** をタップ

### シーンプリセット

| プリセット | Hz | measuredPower | 用途 |
|-----------|-----|---------------|------|
| 静止 | 1 Hz | 86（Quuppa 仕様の基準値） | 屋内固定資産・静止人物 |
| 歩行 | 3 Hz | 75 | 歩行者・緩やかな移動 |
| 走行 | 5 Hz | 69 | アスリート・速い移動 |
| 車両 | 10 Hz | 60 | 自動車・フォークリフト・広大な空間 |

---

## Español

### Descripción general

**QuuppaTagDemo** convierte cualquier iPhone o iPad en una etiqueta del **Sistema de Localización Inteligente Quuppa**.
La aplicación emite paquetes iBeacon estándar cuyo UUID codifica el payload de Direction-Finding (DF) de Quuppa,
permitiendo que los localizadores detecten y reporten la posición interior precisa del dispositivo en tiempo real
a través de la Quuppa Web Services API.

### Características

| Característica | Descripción |
|----------------|-------------|
| **Tag ID aleatorio** | ID de 6 bytes criptográficamente seguro mediante `SecRandomCopyBytes` |
| **Tag ID manual** | Campo hexadecimal en línea con validación y animación de error |
| **Historial de IDs** | Guarda los últimos 10 Tag IDs — toca cualquiera para restaurarlo |
| **Código QR** | Generación QR con CoreImage + hoja de compartir del sistema |
| **Presets de escena** | Estático / Caminando / Corriendo / Vehículo — `measuredPower` calibrado + indicador de batería |
| **Interfaz multiidioma** | Inglés / 中文 — detectado desde el idioma del dispositivo, con cambio manual |
| **Introducción guiada** | Tutorial de 3 pasos en el primer lanzamiento, omitible |
| **BLE en segundo plano** | Continúa emitiendo BLE en segundo plano (modo `bluetooth-peripheral`) |
| **Retroalimentación háptica** | `UIImpactFeedbackGenerator` en todas las acciones principales |
| **UI programática** | Auto Layout completo en código — sin Storyboard |

### Requisitos

- iOS 13.0+  ·  Xcode 15+  ·  Dispositivo físico (el Simulador no soporta modo periférico BLE)
- Frameworks: CoreBluetooth · CoreLocation · CoreImage · Security · UIKit

### Inicio rápido

```bash
git clone https://github.com/HMZ1228/QuuppaTagDemo-iOS.git
```

1. Abrir `QuuppaTagDemo.xcodeproj` en Xcode
2. Activar **Signing & Capabilities → Background Modes → Uses Bluetooth LE accessories**
3. Compilar y ejecutar en un dispositivo físico
4. Pulsar **Aleatorio** para generar un Tag ID, elegir un preset y pulsar **Iniciar transmisión**

### Presets de escena

| Preset | Hz | measuredPower | Caso de uso |
|--------|-----|---------------|-------------|
| Estático | 1 Hz | 86 (referencia Quuppa) | Activo fijo en interior, persona quieta |
| Caminando | 3 Hz | 75 | Peatón, movimiento lento |
| Corriendo | 5 Hz | 69 | Atleta, movimiento rápido |
| Vehículo | 10 Hz | 60 | Coche / carretilla elevadora / espacio amplio |

> **Nota**: iOS no permite controlar directamente el intervalo de publicidad iBeacon. Los valores Hz son etiquetas
> de referencia para la configuración del backend Quuppa; el intervalo real es gestionado por el SO (~100 ms en primer plano).

---

## Project Structure / 项目结构 / プロジェクト構成 / Estructura del proyecto

```
QuuppaTagDemo-iOS/
├── README.md
├── .gitignore
└── QuuppaTagDemo/
    ├── main.m
    ├── AppDelegate.h / .m          # App + Scene lifecycle (iOS 13+)
    ├── SceneDelegate.h / .m        # Window management (iOS 13+)
    ├── ViewController.h / .m       # Main screen — fully programmatic UI
    ├── QuuppaLogoUiView.h / .m     # Animated Quuppa Q logo view
    ├── Info.plist                  # BT permissions + background mode
    ├── Views/
    │   └── OnboardingOverlayView.h / .m   # 3-step first-launch guide
    ├── Managers/
    │   └── TagHistoryManager.h / .m       # Recent Tag ID persistence
    ├── Utils/
    │   ├── crc-8.h / .c                   # CRC-8 poly=0x97 (Quuppa spec)
    │   └── QRCodeGenerator.h / .m         # CoreImage QR utility
    ├── en.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

## License

MIT © 2025 [HMZ1228](https://github.com/HMZ1228)

# Dictakey

A macOS menu bar app that transcribes your speech and pastes it into any app. Hold a hotkey to record, release to transcribe and paste — powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit) running fully on-device.

## Features

- Runs entirely on-device — no internet required after first model download
- Works in any app with a text cursor
- Configurable hotkey (default: ⌥Space)
- Configurable microphone input
- Configurable transcription model with download progress
- Launch at login support

## Requirements

- macOS 15+
- Apple Silicon or Intel Mac

## Setup

1. Open `WhisperPaste/Dictakey.xcodeproj` in Xcode
2. Add the WhisperKit package: **File → Add Package Dependencies** → `https://github.com/argmaxinc/WhisperKit`
3. Build and run (⌘R)

On first launch, grant **Microphone** and **Accessibility** permissions when prompted. Accessibility is required to simulate the paste keystroke.

The selected Whisper model downloads automatically on first use. The default `base` model is ~142 MB.

## Permissions

| Permission | Purpose |
|---|---|
| Microphone | Recording audio for transcription |
| Accessibility | Simulating ⌘V to paste transcribed text |

## Hotkey

The default hotkey is **⌥Space** (hold to record, release to transcribe and paste). You can change it in **Settings** (click the menu bar icon → Settings, or ⌘,).

## Models

The transcription model can be changed at any time in **Settings → Transcription Model**. Switching models triggers an immediate download if the model isn't already cached. Download progress is shown both in the menu bar icon tooltip and as a progress bar inside Settings.

| Model | Size | Notes |
|---|---|---|
| Tiny | ~65 MB | Fastest, lowest accuracy |
| Base | ~142 MB | Default — good balance of speed and accuracy |
| Small | ~483 MB | Better accuracy, slightly slower |
| Medium | ~1.5 GB | High accuracy, slower |
| Large v3 | ~3.1 GB | Best accuracy, slowest |

Models are cached after the first download — switching back to a previously used model is instant.

## Building for Distribution

1. **Product → Archive**
2. **Distribute App → Custom → Copy App**
3. Move `Dictakey.app` to `/Applications`
4. Drag to Dock if desired

# Dictakey

A macOS menu bar app that transcribes your speech and pastes it into any app. Hold a hotkey to record, release to transcribe and paste — powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit) running fully on-device.

## Features

- Runs entirely on-device — no internet required after first model download
- Works in any app with a text cursor
- Configurable hotkey (default: ⌥Space)
- Configurable microphone input
- Launch at login support

## Requirements

- macOS 15+
- Apple Silicon or Intel Mac

## Setup

1. Open `WhisperPaste/Dictakey.xcodeproj` in Xcode
2. Add the WhisperKit package: **File → Add Package Dependencies** → `https://github.com/argmaxinc/WhisperKit`
3. Build and run (⌘R)

On first launch, grant **Microphone** and **Accessibility** permissions when prompted. Accessibility is required to simulate the paste keystroke.

The Whisper model downloads automatically on first launch (~150 MB for the default `base` model).

## Permissions

| Permission | Purpose |
|---|---|
| Microphone | Recording audio for transcription |
| Accessibility | Simulating ⌘V to paste transcribed text |

## Hotkey

The default hotkey is **⌥Space** (hold to record, release to transcribe and paste). You can change it in **Settings** (click the menu bar icon → Settings, or ⌘,).

## Building for Distribution

1. **Product → Archive**
2. **Distribute App → Custom → Copy App**
3. Move `Dictakey.app` to `/Applications`
4. Drag to Dock if desired

## Models

The transcription model can be changed in `WhisperTranscriber.swift`. Available sizes (speed vs accuracy tradeoff):

- `tiny` — fastest
- `base` — default, good balance
- `small` / `medium` / `large-v3` — more accurate, slower

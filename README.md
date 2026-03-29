# LaptopSlap

Minimal macOS app that listens to the microphone, looks for short impact-like sounds, and immediately plays your chosen audio file. Repeated slaps can stack multiple playbacks at once, so a second hit does not wait for the first sound to finish.

## What it already does

- lets you choose an `mp3`, `wav`, `m4a`, or `aiff`
- listens to the laptop microphone
- filters for short transient peaks instead of general speech-like audio
- applies a cooldown so one impact does not retrigger dozens of times
- allows overlapping playback by spawning a fresh `AVAudioPlayer` per trigger

## Detection idea

The current detector only fires when several conditions are true at the same time:

- the peak is much higher than the adaptive noise floor
- the peak is sharp relative to average loudness (`crest factor`)
- the waveform changes very abruptly (`transient ratio`)
- the signal crosses zero often enough, which helps reject long vowel-heavy speech
- the loudest part is brief rather than sustained (`high-energy cap`)

This is not lab-grade classification, but it is a practical first pass for “hit the chassis, make it moan” behavior.

## Run

```bash
swift run
```

If macOS asks for microphone permission, allow it for the host process that launches the app.

## Open as an app

This repo now also contains an Xcode macOS app project:

- [`LaptopSlap.xcodeproj`](/Users/v/Documents/Playground/LaptopSlap.xcodeproj/project.pbxproj)

Open it in Xcode, select the `LaptopSlap` target, and run. The app bundle includes the proper microphone usage string in:

- [`Info.plist`](/Users/v/Documents/Playground/LaptopSlap/Info.plist)

## GitHub build

This repo includes a GitHub Actions workflow at:

- [`.github/workflows/build-macos-app.yml`](/Users/v/Documents/Playground/.github/workflows/build-macos-app.yml)

On every push to `main` or a `codex/*` branch, GitHub builds the app on macOS and uploads `LaptopSlap.app.zip` as a workflow artifact.

## Tune

Start with these expectations:

- if speech still triggers it, increase `Crest Factor`, `Transient Ratio`, or `Zero Crossing`
- if actual slaps do not trigger, lower `Peak Gate` or `Minimum Peak`
- if one slap creates too many triggers, increase `Cooldown ms`

## Next step with your sample files

If you give me:

- one or more recordings of actual slaps
- optionally a short recording of normal speech in the same room

then I can tighten the detector around your real acoustic profile instead of these generic heuristics.

## Current defaults

This workspace is prewired to use:

- slap example: `/Users/v/Downloads/Новая запись 5.m4a`
- moan playback: `/Users/v/Downloads/usb-moan-app/sounds/moan.mp3`

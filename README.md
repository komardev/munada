# Munada

A lightweight macOS menu bar app for Muslim prayer times. Shows the next
prayer and a live countdown in the menu bar, with today's full schedule in the
dropdown. Times are computed offline — no network, no tracking.

![Munada](docs/screenshot.png)

## Features

- Next prayer name + countdown in the menu bar
- Today's schedule with the current prayer highlighted; sunrise shown as info
- Offline calculation via [Adhan](https://github.com/batoulapps/adhan-swift)
- 13 calculation methods (Kemenag, Umm al-Qura, ISNA, MWL, Egyptian, Karachi,
  Turkey, and more); Kemenag applies the standard Indonesian ihtiyati margin
- Madhab selector for Asr (Shafi/Maliki/Hanbali vs Hanafi)
- Per-prayer manual minute adjustments to match a local schedule
- Location by GPS or city search; suggests the method commonly used in the
  detected country
- Local notifications at each prayer time with an optional pre-alert
- Open at login
- Languages: Indonesian, English, Arabic (defaults to the system language)

## Build

Requires macOS 13+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Munada.xcodeproj -scheme Munada -configuration Release \
  -derivedDataPath build build
```

The built app is at `build/Build/Products/Release/Munada.app`. Copy it to
`/Applications` to install. Dependencies are fetched automatically via Swift
Package Manager.

## Accuracy

Prayer times are astronomical calculations. Methods differ by region — pick the
one used where you live, and use the per-prayer adjustments to match your local
authoritative schedule if needed. Always verify against a trusted local source.

## License

MIT — see [LICENSE](LICENSE). Prayer time calculations use Adhan, also MIT.

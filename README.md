# METAR Weather

A clean iOS app for reading airport weather (METAR) at a glance — temperature, wind, and
visibility for the airports you care about, on the home screen and in a widget.

<p align="center">
  <img src="UI_screenshot.png" alt="METAR Weather — airfield list showing EFHA, KJFK and EFTP cards" width="300">
  &nbsp;&nbsp;
  <img src="WIDGET_screenshot.png" alt="METAR Weather home-screen widgets — medium and small sizes" width="300">
</p>

## Why?

The goal of this project was to fetch airport METAR weather data and display it in the format
I prefer.

In my daily work life I need temperature, wind speed, and visibility for a few nearby airports
to be easy to glance at. So I decided to try out how this "new" way of AI-assisted development
works. The app was built mostly with Claude Sonnet 4.6 and Opus 4.8 (medium to high effort);
early on I also used Gemini Pro.

I'd like to get this published to the App Store.

## Features

- **Airfield cards** — temperature, wind (direction + speed), and visibility for each airport,
  with a colour-coded flight-condition badge (VFR / MVFR / IFR / LIFR), plus the airport name
  and its published radio frequencies.
- **Full METAR decode** — tap the raw METAR line on any card to expand a complete,
  human-readable breakdown (wind, clouds, weather phenomena, QNH, trend, and more).
- **Manage airports** — add by ICAO code, remove, and drag to reorder from the Settings page.
- **Unit options** — temperature in °C / °F and wind in knots / m/s / mph.
- **Home-screen widget** — a compact card (small & medium) that is **configurable**: pick which
  saved airport each widget shows.
- **Auto-refresh** — both the app and the widget refresh roughly every 30 minutes; the app also
  refreshes when brought back to the foreground if its data is older than that, and there's a
  manual **Refresh** button.

## How it works

You add airports by their 4-letter **ICAO code** (e.g. `EFHA`, `KJFK`). For each code the app
fetches:

1. **Airport info** — name and any published radio frequencies.
2. **METAR** — the current observation, which is parsed for the card metrics and the full decode.

The app and the widget share data through an App Group, so the widget stays in sync with your
saved airports and units.

All weather and airport data is provided by **[aviationweather.gov](https://aviationweather.gov)**
(NOAA / National Weather Service). Thank you for that!

## Tech

- **SwiftUI** app with a **WidgetKit** extension (configurable via **AppIntents**).
- Data sharing between app and widget via an **App Group**.
- Targets **iOS 18+** on iPhone.
- The project also lists **macOS 15+** as a supported destination (a native Mac build, not
  Catalyst). The release `.ipa` is iOS only.

## Install

An unsigned `.ipa` is attached to each release. Download it from
[the latest release](https://github.com/HenriVSL/METAR-Weather/releases/latest) and sideload it
with a tool that re-signs it with your own Apple ID, such as [AltStore](https://altstore.io),
[SideStore](https://sidestore.io) or [Sideloadly](https://sideloadly.io). With a free Apple ID
the signature expires after 7 days, so the app has to be re-signed weekly (AltStore and SideStore
can refresh it for you).

The widget extension is inside the `.ipa` and gets re-signed along with the app. On a free Apple
ID it uses up an extra App ID.

## Build from source

Requires Xcode 16 or later.

```sh
git clone https://github.com/HenriVSL/METAR-Weather.git
open "METAR-Weather/METAR Weather.xcodeproj"
```

1. Under **Signing & Capabilities**, choose your own team for both the **METAR Weather** and
   **MetarWidgetExtension** targets.
2. If the bundle identifiers (`henril.METAR-Weather`, `henril.METAR-Weather.MetarWidget`) or the
   App Group (`group.henril.METAR-Weather`) can't be registered to your team, change them to your
   own. The App Group must be the same in both targets' entitlements and in `appGroupID` in
   `MetarWidget/WidgetShared.swift`, or the widget won't see your airports.
3. Run the **METAR Weather** scheme on a device or simulator.

## Status

Working and in use; cleaning things up with the aim of an App Store release.

> ⚠️ This app is for situational awareness only and is **not** an approved source for flight
> planning or operational decisions. Always use official aviation weather briefings.

## License

MIT, see [LICENSE](LICENSE).

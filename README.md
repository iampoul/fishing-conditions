# Fishing Conditions for Omarchy

Fishing Conditions is an international Omarchy bar widget for forecast-based
trip conditions, optional marine data, and nearby mapped water discovery.

## Features

- Weather conditions from Open-Meteo for any selected coordinates.
- Optional marine wave and sea-temperature conditions where Open-Meteo supplies
  them. Inland locations can legitimately have no marine data.
- A consumer-controlled location picker: saved location, international
  city/place autocomplete, or manual WGS84 coordinates.
- User-triggered nearby mapped-water discovery with OpenStreetMap data through
  Overpass. Results are candidates, not verified fishing spots.
- Clear fresh, loading, stale, and error states. Forecast data remains visible
  when a later refresh fails.

## Install for development

This source tree is intended to live in a repository-level `plugins/` folder.
For Omarchy to discover it, copy the plugin directory to the user plugin root:

```sh
cp -a plugins/fishing-conditions \
  ~/.config/omarchy/plugins/io.github.iampoul.fishing-conditions

omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.iampoul.fishing-conditions
```

An installable published repository must instead have this directory's contents,
including `manifest.json`, at its repository root:

```sh
omarchy plugin add https://github.com/iampoul/fishing-conditions.git --enable
```

## Use

Click the bar widget and choose **Change location**:

1. Type at least three characters to search cities, towns, and named places with
   Open-Meteo, then select a suggested result.
2. Use **Use coordinates** to work without a geocoder.
3. Select **Find water nearby** after setting a location. The lookup defaults to
   5 km and is capped at 10 km to protect the shared public map service. Choose
   a mapped water candidate to make it the active fishing location.

Middle-click the bar widget to request a refresh. The default refresh interval
is 30 minutes. The active location and widget preferences are stored locally in
Omarchy's `shell.json` configuration.

## Data, privacy, and limitations

- Weather and marine data come from [Open-Meteo](https://open-meteo.com/).
  Its free service is for non-commercial use and requires attribution.
- Place autocomplete uses Open-Meteo Geocoding. It resolves places rather than
  street addresses; use coordinates when a precise location is required.
- Nearby-water discovery uses
  [OpenStreetMap](https://www.openstreetmap.org/copyright) data through
  Overpass. It searches named mapped water areas, is manual and bounded, and
  never runs on the weather-refresh timer. One fallback public endpoint is used
  only when the primary endpoint is busy or unavailable.
- Entered address text and selected coordinates are sent only to the provider
  needed for the explicit action. The plugin has no telemetry and does not use
  IP-based location inference.
- Weather and activity factors are forecasts and personal comfort indicators,
  not a catch prediction, a safety guarantee, tide information, water-level
  information, or local regulation advice.
- A mapped water feature does not establish public access, legal fishing,
  ownership, species, stocking, fishability, or safety. Check local forecasts,
  hazards, closures, permits, and regulations before going out.

## Validation

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.iampoul.fishing-conditions"

omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/Service.qml" \
  "$PLUGIN_DIR/BarWidget.qml" \
  "$PLUGIN_DIR/Panel.qml" \
  "$PLUGIN_DIR/LocationPicker.qml"
```

`curl` must be present because Quickshell uses it as a tracked process for HTTPS
requests. The plugin does not execute shell snippets: all requests are passed
to `curl` as discrete arguments.

## License

MIT. See [LICENSE](LICENSE).

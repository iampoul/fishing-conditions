# Fishing Conditions

An international Omarchy bar widget for fishing trip conditions: weather, wind,
waves, and sunrise/sunset for a chosen location, with a display-only map.

## Features

- Weather conditions from Open-Meteo (weather code, temperature, wind, pressure)
- Wave height / direction / period and water temperature (marine service)
- Sunrise / sunset for the saved location
- Single-location design: search an address or place, or drag the map to pin
  an exact spot
- Live theme colours (text, surfaces, urgent, accent) from the active Omarchy
  theme — no hardcoded palette

## Install

```sh
omarchy plugin add https://github.com/iampoul/fishing-conditions --enable
```

## Widget

The bar pill shows the summary label, temperature, and wind at a glance. Middle
click forces a refresh.

Settings:

| Key              | Default | Description                                  |
| ---------------- | ------- | -------------------------------------------- |
| `location`       | —       | Saved location `{ name, latitude, longitude }` |
| `units`          | `metric`| `metric` or `imperial`                        |
| `refreshMinutes` | `30`    | Refresh interval                              |
| `windCautionKph` | `25`    | Wind threshold that counts as a caution factor |
| `waveCautionM`   | `1.5`   | Wave threshold that counts as a caution factor|

## Note

Conditions are advisory — not a fish-activity or safety prediction. Map tiles
come from OpenStreetMap / Esri; attribution is shown on the map.

## License

MIT
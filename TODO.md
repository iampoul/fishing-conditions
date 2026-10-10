# TODO

## Current state
- Fishing conditions (weather, wind, waves, sunrise/sunset) for a saved location.
- Address search + autocomplete moves the saved location.
- Display-only OSM map (fixed zoom 16) showing the saved location; tiles fetched via
  curl into `~/.cache/omarchy-fishing/tiles`.

## Done
- [x] Initial plugin structure (manifest, bar widget, panel, service, models)
- [x] Weather + marine conditions from Open-Meteo (keyless)
- [x] Address picker w/ Photon autocomplete + Nominatim fallback
- [x] OSM map with curl-based tile fetching (Qt Image is blocked by OSM UA policy)
- [x] Map display-only at saved location (pan/zoom/drag-set deferred)
- [x] Persistent tile cache under ~/.cache

## Next
- [ ] Verify display-only map loads on a fresh shell (initial-load failure from the
      Canvas rewrite must not regress)
- [ ] Consider restoring smooth drag-to-pan with an atomic renderer (was jumping —
      needs proper fix, e.g. one-pass position+content swap) if drag-pick is wanted
- [ ] Re-evaluate interactive map ("Set as location" on the map) once panning is fixed
- [ ] Optional: prefetch/adjacent-zoom cache for snappier zoom (pan/zoom currently N/A)
- [ ] Decide tile cache location/config (currently hardcoded ~/.cache/omarchy-fishing)
- [ ] Sweep for leftover debug/trace code before release
- [ ] Plugin validate & lint pass as a release gate

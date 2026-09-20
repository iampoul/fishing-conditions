import QtQuick
import Quickshell.Io
import "ConditionsModel.js" as Model

Item {
    id: root

    property var settings: ({})
    property bool loading: false
    property bool marineLoading: false
    property string error: ""
    property string marineError: ""
    property var forecast: null
    property var marine: null
    property var summary: ({ level: "unavailable", label: "Set location", factors: [] })
    property var geocodeResults: []
    property string geocodeError: ""
    property bool geocoding: false
    property var waterFeatures: []
    property string waterError: ""
    property bool findingWater: false
    property string waterQuery: ""
    property bool waterFallbackUsed: false
    property double waterRetryAfter: -Infinity
    property date fetchedAt: new Date(0)
    property date nextRefreshAt: new Date(0)
    property int retryMinutes: 1
    property int geocodeGeneration: 0
    property bool geocodeBusy: false
    property string pendingGeocodeQuery: ""
    property bool marineRequested: false
    property int requestGeneration: 0
    property bool refreshPending: false
    readonly property var location: settings && settings.location ? settings.location : null
    readonly property bool hasLocation: location && Model.validCoordinates(location.latitude, location.longitude)
    readonly property bool stale: forecast !== null && Date.now() - fetchedAt.getTime() > 45 * 60 * 1000
    readonly property string ageLabel: forecast === null ? "" : Math.max(0, Math.round((Date.now() - fetchedAt.getTime()) / 60000)) + "m ago"

    function configure(nextSettings) {
        settings = nextSettings || ({})
        requestGeneration += 1
        overpassRequest.running = false
        findingWater = false
        waterFeatures = []
        marine = null
        marineError = ""
        if (loading || marineLoading) {
            refreshPending = hasLocation
            forecastRequest.running = false
            marineRequest.running = false
            return
        }
        if (hasLocation)
            refresh(false)
        else {
            forecast = null
            marine = null
            summary = ({ level: "unavailable", label: "Set location", factors: [] })
        }
    }

    function refresh(manual) {
        if (!hasLocation || loading || (manual && Date.now() < nextRefreshAt.getTime()))
            return
        error = ""
        loading = true
        forecastRequest.generation = requestGeneration
        forecastRequest.exec(curlArguments(Model.buildForecastUrl(location.latitude, location.longitude)))
        marineRequested = settings.mode === "coastal" || settings.mode === "offshore" || settings.mode === "auto"
        if (marineRequested && !marineLoading) {
            marineError = ""
            marineLoading = true
            marineRequest.generation = requestGeneration
            marineRequest.exec(curlArguments(Model.buildMarineUrl(location.latitude, location.longitude)))
        }
    }

    function runPendingRefresh() {
        if (!refreshPending || loading || marineLoading)
            return
        refreshPending = false
        refresh(false)
    }

    function curlArguments(url) {
        return [
            "curl", "--fail", "--silent", "--show-error",
            "--connect-timeout", "3", "--max-time", "10",
            "--header", "Accept: application/json",
            "--user-agent", "OmarchyFishingConditions/0.1 (+https://github.com/iampoul)",
            url
        ]
    }

    function updateSummary() {
        summary = Model.conditionSummary(forecast, marine, settings)
    }

    function refreshSucceeded() {
        fetchedAt = new Date()
        retryMinutes = 1
        nextRefreshAt = new Date(Date.now() + 30 * 1000)
        updateSummary()
    }

    function refreshFailed(message) {
        error = message
        loading = false
        nextRefreshAt = new Date(Date.now() + retryMinutes * 60 * 1000)
        retryMinutes = Math.min(retryMinutes * 5, 60)
        updateSummary()
    }

    function cancelPlaceSearch() {
        geocodeGeneration += 1
        pendingGeocodeQuery = ""
        geocodeResults = []
        geocodeError = ""
        geocoding = false
        if (geocodeBusy)
            geocodeRequest.running = false
    }

    function searchPlaces(query) {
        var text = String(query || "").trim()
        if (text.length < 3) {
            geocodeResults = []
            if (text.length > 0 && text.length < 3)
                geocodeError = "Enter at least three characters."
            return
        }
        geocodeGeneration += 1
        pendingGeocodeQuery = text
        geocoding = true
        geocodeError = ""
        geocodeResults = []
        if (geocodeBusy) {
            geocodeRequest.running = false
            return
        }
        startPendingPlaceSearch()
    }

    function startPendingPlaceSearch() {
        if (geocodeBusy || pendingGeocodeQuery === "")
            return
        var query = pendingGeocodeQuery
        pendingGeocodeQuery = ""
        geocodeBusy = true
        geocoding = true
        geocodeRequest.generation = geocodeGeneration
        var url = "https://geocoding-api.open-meteo.com/v1/search?count=8&language=en&format=json&name="
            + encodeURIComponent(query)
        geocodeRequest.exec(curlArguments(url))
    }

    function findNearbyWaters(radiusKm) {
        if (!hasLocation || findingWater)
            return
        if (Date.now() < waterRetryAfter) {
            waterError = "Map service is busy. Try again in about a minute."
            return
        }
        var radius = Math.max(1000, Math.min(Number(radiusKm || 5) * 1000, 10000))
        findingWater = true
        waterError = ""
        var latitude = Number(location.latitude).toFixed(6)
        var longitude = Number(location.longitude).toFixed(6)
        overpassRequest.generation = requestGeneration
        overpassRequest.originLatitude = Number(location.latitude)
        overpassRequest.originLongitude = Number(location.longitude)
        waterFallbackUsed = false
        waterQuery = "[out:json][timeout:8];("
            + "way[natural=water][name](around:" + radius + "," + latitude + "," + longitude + ");"
            + "relation[natural=water][name](around:" + radius + "," + latitude + "," + longitude + ");"
            + ");out center tags 15;"
        executeWaterQuery("https://overpass-api.de/api/interpreter")
    }

    function executeWaterQuery(endpoint) {
        overpassRequest.exec([
            "curl", "--fail", "--silent", "--show-error",
            "--connect-timeout", "3", "--max-time", "20",
            "--request", "POST",
            "--header", "Accept: application/json",
            "--header", "Content-Type: text/plain; charset=utf-8",
            "--user-agent", "OmarchyFishingConditions/0.1 (+https://github.com/iampoul)",
            "--data-binary", waterQuery,
            endpoint
        ])
    }

    function retryWaterQuery(message) {
        if (!waterFallbackUsed) {
            waterFallbackUsed = true
            executeWaterQuery("https://maps.mail.ru/osm/tools/overpass/api/interpreter")
            return
        }
        findingWater = false
        waterRetryAfter = Date.now() + 60 * 1000
        waterError = message
    }

    Timer {
        interval: Math.max(15, Math.min(Number(root.settings.refreshMinutes || 30), 120)) * 60 * 1000
        running: root.hasLocation
        repeat: true
        onTriggered: root.refresh(false)
    }

    Process {
        id: forecastRequest
        property int generation: -1
        stdout: StdioCollector { id: forecastBody; waitForEnd: true }
        stderr: StdioCollector { id: forecastStderr; waitForEnd: true }
        onExited: (exitCode) => {
            root.loading = false
            if (generation !== root.requestGeneration) {
                root.runPendingRefresh()
                return
            }
            if (exitCode !== 0) {
                root.refreshFailed(forecastStderr.text.trim() || "Weather request failed.")
                root.runPendingRefresh()
                return
            }
            try {
                var value = Model.decodeForecast(JSON.parse(forecastBody.text))
                if (!value)
                    throw new Error("Missing expected conditions.")
                root.forecast = value
                root.refreshSucceeded()
            } catch (exception) {
                root.refreshFailed("Weather response was invalid.")
            }
            root.runPendingRefresh()
        }
    }

    Process {
        id: marineRequest
        property int generation: -1
        stdout: StdioCollector { id: marineBody; waitForEnd: true }
        stderr: StdioCollector { id: marineStderr; waitForEnd: true }
        onExited: (exitCode) => {
            root.marineLoading = false
            if (generation !== root.requestGeneration) {
                root.runPendingRefresh()
                return
            }
            if (exitCode !== 0) {
                root.marineError = marineStderr.text.trim() || "Marine data unavailable."
                root.updateSummary()
                root.runPendingRefresh()
                return
            }
            try {
                root.marine = Model.decodeMarine(JSON.parse(marineBody.text))
                if (!root.marine)
                    root.marineError = "Marine data is unavailable for this location."
            } catch (exception) {
                root.marineError = "Marine response was invalid."
            }
            root.updateSummary()
            root.runPendingRefresh()
        }
    }

    Process {
        id: geocodeRequest
        property int generation: -1
        stdout: StdioCollector { id: geocodeBody; waitForEnd: true }
        stderr: StdioCollector { id: geocodeStderr; waitForEnd: true }
        onExited: (exitCode) => {
            var completedGeneration = generation
            root.geocodeBusy = false
            if (completedGeneration !== root.geocodeGeneration) {
                root.startPendingPlaceSearch()
                return
            }
            root.geocoding = false
            if (exitCode !== 0) {
                root.geocodeError = geocodeStderr.text.trim() || "Location search failed."
                return
            }
            try {
                var response = JSON.parse(geocodeBody.text)
                var candidates = Array.isArray(response) ? response : (response.results || [])
                root.geocodeResults = candidates.map(function(item) {
                    return {
                        label: item.display_name || [item.name, item.admin1, item.country].filter(Boolean).join(", "),
                        latitude: Number(item.lat !== undefined ? item.lat : item.latitude),
                        longitude: Number(item.lon !== undefined ? item.lon : item.longitude),
                        timezone: item.timezone || ""
                    }
                }).filter(function(item) {
                    return item.label && Model.validCoordinates(item.latitude, item.longitude)
                })
                if (root.geocodeResults.length === 0)
                    root.geocodeError = "No matching locations were found."
            } catch (exception) {
                root.geocodeError = "Location search returned invalid data."
            }
        }
    }

    Process {
        id: overpassRequest
        property int generation: -1
        property double originLatitude: 0
        property double originLongitude: 0
        stdout: StdioCollector { id: overpassBody; waitForEnd: true }
        stderr: StdioCollector { id: overpassStderr; waitForEnd: true }
        onExited: (exitCode) => {
            if (generation !== root.requestGeneration) {
                root.findingWater = false
                return
            }
            if (exitCode !== 0) {
                root.retryWaterQuery("Map service is busy. Try again in about a minute.")
                return
            }
            try {
                var response = JSON.parse(overpassBody.text)
                if (response && typeof response.remark === "string") {
                    root.retryWaterQuery("Map service is busy. Try again in about a minute.")
                    return
                }
                if (!response || !Array.isArray(response.elements))
                    throw new Error("Unexpected response.")
                root.waterFeatures = response.elements.map(function(item) {
                    var point = item.center || item
                    var latitude = Number(point.lat)
                    var longitude = Number(point.lon)
                    return {
                        osmType: item.type,
                        osmId: Number(item.id),
                        name: item.tags && item.tags.name ? item.tags.name : "Unnamed water",
                        kind: item.tags && (item.tags.water || item.tags.waterway || item.tags.leisure) || "water",
                        latitude: latitude,
                        longitude: longitude,
                        distanceM: Model.haversineMeters(originLatitude, originLongitude, latitude, longitude)
                    }
                }).filter(function(item) {
                    return Model.validCoordinates(item.latitude, item.longitude)
                }).sort(function(a, b) { return a.distanceM - b.distanceM })
                root.findingWater = false
                if (root.waterFeatures.length === 0)
                    root.waterError = "No mapped water features were found in this radius."
            } catch (exception) {
                root.retryWaterQuery("Map service returned invalid data.")
            }
        }
    }
}

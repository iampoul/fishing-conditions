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
    property date fetchedAt: new Date(0)
    property date nextRefreshAt: new Date(0)
    property int retryMinutes: 1
    property int geocodeGeneration: 0
    property bool geocodeBusy: false
    property bool geocodeProvider: false
    property bool nominatimRetried: false
    property string lastGeocodeQuery: ""
    property string pendingGeocodeQuery: ""
    property int requestGeneration: 0
    property bool refreshPending: false
    readonly property int forecastMaxBytes: 1024 * 1024
    readonly property int marineMaxBytes: 1024 * 1024
    readonly property int geocodeMaxBytes: 256 * 1024
    readonly property int stderrMaxBytes: 8 * 1024
    readonly property int maxGeocodeResults: 8

    readonly property var location: settings && settings.location ? settings.location : null
    readonly property bool hasLocation: location && Model.validCoordinates(location.latitude, location.longitude)
    readonly property bool stale: forecast !== null && Date.now() - fetchedAt.getTime() > 45 * 60 * 1000
    readonly property string ageLabel: forecast === null ? "" : Math.max(0, Math.round((Date.now() - fetchedAt.getTime()) / 60000)) + "m ago"

    function configure(nextSettings) {
        settings = nextSettings || ({})
        requestGeneration += 1
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
        forecastRequest.exec(curlArguments(Model.buildForecastUrl(location.latitude, location.longitude), forecastMaxBytes))
        if (!marineLoading) {
            marineError = ""
            marineLoading = true
            marineRequest.generation = requestGeneration
            marineRequest.exec(curlArguments(Model.buildMarineUrl(location.latitude, location.longitude), marineMaxBytes))
        }
    }

    function runPendingRefresh() {
        if (!refreshPending || loading || marineLoading)
            return
        refreshPending = false
        refresh(false)
    }

    function curlArguments(url, maxBytes) {
        return [
            "curl", "--fail", "--silent", "--show-error",
            "--connect-timeout", "3", "--max-time", "10",
            "--max-filesize", String(maxBytes),
            "--header", "Accept: application/json",
            "--user-agent", "OmarchyFishing/0.1 (+https://github.com/iampoul)",
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
            else
                geocodeError = ""
            return
        }
        geocodeGeneration += 1
        pendingGeocodeQuery = text
        lastGeocodeQuery = text
        geocodeProvider = 0
        nominatimRetried = false
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
        geocodeRequest.exec(curlArguments(Model.buildGeocodeUrl(query), geocodeMaxBytes))
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
        stdout: BoundedCollector { id: forecastBody; process: forecastRequest; maxBytes: root.forecastMaxBytes }
        stderr: BoundedCollector { id: forecastStderr; process: forecastRequest; maxBytes: root.stderrMaxBytes }
        onRunningChanged: if (running) {
            forecastBody.reset()
            forecastStderr.reset()
        }
        onExited: (exitCode) => {
            root.loading = false
            if (generation !== root.requestGeneration) {
                root.runPendingRefresh()
                return
            }
            if (forecastBody.overflowed || exitCode === 63) {
                root.refreshFailed("Weather response was too large.")
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
        stdout: BoundedCollector { id: marineBody; process: marineRequest; maxBytes: root.marineMaxBytes }
        stderr: BoundedCollector { id: marineStderr; process: marineRequest; maxBytes: root.stderrMaxBytes }
        onRunningChanged: if (running) {
            marineBody.reset()
            marineStderr.reset()
        }
        onExited: (exitCode) => {
            root.marineLoading = false
            if (generation !== root.requestGeneration) {
                root.runPendingRefresh()
                return
            }
            if (marineBody.overflowed || exitCode === 63) {
                root.marineError = "Marine response was too large."
                root.updateSummary()
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
        stdout: BoundedCollector { id: geocodeBody; process: geocodeRequest; maxBytes: root.geocodeMaxBytes }
        stderr: BoundedCollector { id: geocodeStderr; process: geocodeRequest; maxBytes: root.stderrMaxBytes }
        onRunningChanged: if (running) {
            geocodeBody.reset()
            geocodeStderr.reset()
        }
        onExited: (exitCode) => {
            var completedGeneration = generation
            root.geocodeBusy = false
            if (completedGeneration !== root.geocodeGeneration) {
                root.startPendingPlaceSearch()
                return
            }
            if (geocodeBody.overflowed || exitCode === 63) {
                root.geocoding = false
                root.geocodeError = "Location search returned too much data."
                return
            }
            if (exitCode !== 0) {
                root.geocoding = false
                root.geocodeError = geocodeStderr.text.trim() || "Location search failed."
                return
            }
            var candidates = []
            var parseFailed = false
            try {
                var parsed = JSON.parse(geocodeBody.text)
                candidates = root.geocodeProvider === 1
                    ? Model.decodeNominatim(parsed)
                    : Model.decodeGeocode(parsed)
            } catch (exception) {
                parseFailed = true
            }
            if (!parseFailed && candidates.length === 0
                    && root.geocodeProvider === 0 && !root.nominatimRetried) {
                root.nominatimRetried = true
                root.geocodeBusy = true
                root.geocodeProvider = 1
                geocodeRequest.exec(curlArguments(Model.buildNominatimUrl(root.lastGeocodeQuery), geocodeMaxBytes))
                return
            }
            root.geocoding = false
            if (parseFailed) {
                root.geocodeResults = []
                root.geocodeError = "Location search returned invalid data."
                return
            }
            root.geocodeResults = candidates.slice(0, root.maxGeocodeResults)
            if (root.geocodeResults.length === 0)
                root.geocodeError = "No matching locations were found."
        }
    }
}


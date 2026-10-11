import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import "ConditionsModel.js" as Model

Panel {
    id: root

    moduleName: "io.github.iampoul.fishing-conditions"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property var service: null
    property var persistSettings: null
    property bool pickerOpen: false
    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property color bg: root.bar ? root.bar.background : Color.background
    readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
    readonly property color secondary: Color.muted
    readonly property color border: Color.popups.border
    readonly property color accent: Color.accent

    function open() {
        root.controller.show()
        mapWake.start()
    }

    function close() {
        root.pickerOpen = false
        root.controller.hide()
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.open()
    }

    function save(next) {
        if (!root.persistSettings)
            return
        root.settings = next
        root.persistSettings(next)
        if (root.service)
            root.service.configure(next)
    }

    function selectLocation(location) {
        var next = Object.assign({}, root.settings, { location: location })
        root.save(next)
        root.pickerOpen = false
        settleMapTimer.restart()
        if (travelMap) {
            travelMap.markerLatitude = location.latitude
            travelMap.markerLongitude = location.longitude
        }
    }

    Timer {
        id: settleMapTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (travelMap)
                travelMap.recenter()
        }
    }

    Timer {
        id: mapWake
        interval: 120
        repeat: false
        onTriggered: {
            if (travelMap)
                travelMap.wake()
        }
    }

    KeyboardPanel {
        id: keyboardPanel
        anchorItem: root.anchorItem
        bar: root.bar
        owner: root
        open: root.opened
        centerOnBar: true
        contentWidth: 460
        contentHeight: 660

        Rectangle {
            anchors.fill: parent
            color: root.bg
            radius: 10
            border.color: root.border

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                RowLayout {
                    width: parent.width
                    spacing: 8
                    Text {
                        Layout.preferredWidth: implicitWidth
                        text: "Fishing conditions"
                        color: root.fg
                        font.bold: true
                        font.pixelSize: 18
                    }
                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }
                    Button {
                        text: "Change location"
                        onClicked: root.pickerOpen = true
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: root.secondary
                    // location.name is a geocoder-derived string saved from
                    // the picker and is untrusted; PlainText keeps it from
                    // ever being interpreted as HTML (see LocationPicker.qml).
                    textFormat: Text.PlainText
                    text: root.settings.location
                        ? root.settings.location.name + (root.service && root.service.ageLabel
                            ? " · updated " + root.service.ageLabel : "")
                        : "Choose a fishing location to load conditions."
                }

                TileMapEsri {
                    id: travelMap
                    visible: !!root.settings.location
                    width: parent.width
                    height: 200
                    zoom: 16
                    markerLatitude: root.settings.location ? Number(root.settings.location.latitude) : 0
                    markerLongitude: root.settings.location ? Number(root.settings.location.longitude) : 0
                    onMarkerLatitudeChanged: {
                        if (markerLatitude !== 0 || markerLongitude !== 0)
                            travelMap.recenter()
                    }
                    onMarkerLongitudeChanged: {
                        if (markerLatitude !== 0 || markerLongitude !== 0)
                            travelMap.recenter()
                    }
                }

                RowLayout {
                    visible: !!root.settings.location
                    width: parent.width
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        color: root.secondary
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        text: "Drag map to move · center is the pin."
                            + (root.settings.location ? "\nCenter: " + travelMap.latitude.toFixed(4) + ", " + travelMap.longitude.toFixed(4) : "")
                    }
                    Button {
                        text: "Set as location"
                        onClicked: {
                            var loc = {
                                name: travelMap.latitude.toFixed(4) + ", " + travelMap.longitude.toFixed(4),
                                latitude: travelMap.latitude,
                                longitude: travelMap.longitude,
                                timezone: ""
                            }
                            root.selectLocation(loc)
                        }
                    }
                }

                Rectangle {
                    visible: !root.settings.location
                    width: parent.width
                    height: 200
                    radius: 6
                    color: Qt.lighter(root.bg, 1.03)
                    border.color: root.border
                    Text {
                        anchors.centerIn: parent
                        color: root.secondary
                        text: "Set a location to see the map"
                    }
                }

                Text {
                    visible: root.service && root.service.forecast
                    color: root.service && root.service.summary.level === "unsafe" ? root.urgent : root.fg
                    font.bold: true
                    text: root.service ? root.service.summary.label : ""
                }

                Grid {
                    visible: root.service && root.service.forecast
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 4
                    Text { text: "Weather"; color: root.secondary }
                    Text { text: root.service && root.service.forecast ? root.service.forecast.weatherLabel : ""; color: root.fg }
                    Text { text: "Temperature"; color: root.secondary }
                    Text {
                        text: root.service && root.service.forecast
                            ? Model.formatTemperature(root.service.forecast.temperatureC, root.settings.units === "imperial" ? "imperial" : "metric") : ""
                        color: root.fg
                    }
                    Text { text: "Wind"; color: root.secondary }
                    Text {
                        text: root.service && root.service.forecast
                            ? Model.formatWind(root.service.forecast.windKph, root.settings.units === "imperial" ? "imperial" : "metric")
                                + " " + root.service.forecast.windDirection : ""
                        color: root.fg
                    }
                    Text { text: "Pressure"; color: root.secondary }
                    Text {
                        text: root.service && root.service.forecast && root.service.forecast.pressureHpa !== null
                            ? Math.round(root.service.forecast.pressureHpa) + " hPa" : ""
                        color: root.fg
                    }
                    Text { text: "Sunrise / sunset"; color: root.secondary }
                    Text {
                        text: root.service && root.service.forecast
                            ? Model.formatSun(root.service.forecast.sunrise) + " / " + Model.formatSun(root.service.forecast.sunset) : ""
                        color: root.fg
                    }
                }

                Text {
                    visible: root.service && root.service.marine
                    color: root.accent
                    text: root.service && root.service.marine
                        ? "Marine: " + Model.formatWave(root.service.marine.waveHeightM, root.settings.units === "imperial" ? "imperial" : "metric")
                            + " waves" + (root.service.marine.waveDirection ? " " + root.service.marine.waveDirection : "")
                            + (root.service.marine.wavePeriodS ? " · " + root.service.marine.wavePeriodS + " s" : "")
                            + (root.service.marine.waterTemperatureC !== null
                                ? " · " + Model.formatTemperature(root.service.marine.waterTemperatureC, root.settings.units === "imperial" ? "imperial" : "metric") + " water" : "")
                        : ""
                }
                Text {
                    visible: root.service && root.service.marineError !== ""
                    color: root.secondary
                    text: root.service ? root.service.marineError : ""
                }
                Text {
                    visible: root.service && root.service.error !== ""
                    color: root.urgent
                    text: root.service ? root.service.error : ""
                }

                Text {
                    visible: root.service && root.service.summary.factors && root.service.summary.factors.length > 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: root.secondary
                    text: root.service ? root.service.summary.factors.join(" ") : ""
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: root.secondary
                    font.pixelSize: 11
                    text: "Conditions are advisory, not a fish-activity or safety prediction. "
                        + "Weather: Open-Meteo."
                }
            }

            Loader {
                active: root.pickerOpen
                anchors.fill: parent
                z: 1
                source: Qt.resolvedUrl("LocationPicker.qml")
                onLoaded: {
                    item.service = root.service
                    item.bar = root.bar
                    item.selected.connect(root.selectLocation)
                    item.dismissed.connect(function() { root.pickerOpen = false })
                }
            }
        }
    }
}


import QtQuick
import QtQuick.Controls
import qs.Ui
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
    property int waterRadiusKm: 5
    readonly property var barIdentity: hostWidget || root

    function open() {
        root.controller.show()
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

    function closeForPopoutSwitch() {
        root.close()
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
    }

    function saveCurrentLocation() {
        if (!root.settings.location)
            return
        var saved = Array.isArray(root.settings.savedLocations) ? root.settings.savedLocations.slice() : []
        saved.push(root.settings.location)
        root.save(Object.assign({}, root.settings, { savedLocations: saved }))
    }

    KeyboardPanel {
        id: keyboardPanel
        anchorItem: root.anchorItem
        bar: root.bar
        owner: root.barIdentity
        open: root.opened
        centerOnBar: true
        contentWidth: 510
        contentHeight: 610

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 10
            border.color: "#585b70"

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                Row {
                    width: parent.width
                    Text {
                        text: "Fishing conditions"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 20
                    }
                    Item { width: Math.max(0, parent.width - 300); height: 1 }
                    Button {
                        text: "Change location"
                        onClicked: root.pickerOpen = true
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: "#cdd6f4"
                    text: root.settings.location
                        ? root.settings.location.name + (root.service && root.service.ageLabel
                            ? " · updated " + root.service.ageLabel : "")
                        : "Choose a fishing location to load conditions."
                }

                Row {
                    visible: !!root.settings.location
                    spacing: 8
                    Button {
                        text: "Refresh"
                        onClicked: {
                            if (root.service)
                                root.service.refresh(true)
                        }
                    }
                    Button {
                        text: "Save location"
                        onClicked: root.saveCurrentLocation()
                    }
                    Button {
                        text: "Find water nearby"
                        onClicked: {
                            if (root.service)
                                root.service.findNearbyWaters(root.waterRadiusKm)
                        }
                    }
                    ComboBox {
                        model: [5, 10]
                        currentIndex: [5, 10].indexOf(root.waterRadiusKm)
                        onActivated: root.waterRadiusKm = Number(currentText)
                    }
                    Text { text: "km"; color: "#cdd6f4"; anchors.verticalCenter: parent.verticalCenter }
                }

                Text {
                    visible: root.service && root.service.forecast
                    color: root.service && root.service.summary.level === "unsafe" ? "#f38ba8" : "#a6e3a1"
                    font.bold: true
                    text: root.service ? root.service.summary.label : ""
                }

                Grid {
                    visible: root.service && root.service.forecast
                    columns: 2
                    columnSpacing: 30
                    rowSpacing: 4
                    Text { text: "Weather"; color: "#bac2de" }
                    Text { text: root.service && root.service.forecast ? root.service.forecast.weatherLabel : ""; color: "white" }
                    Text { text: "Temperature"; color: "#bac2de" }
                    Text {
                        text: root.service && root.service.forecast
                            ? Model.formatTemperature(root.service.forecast.temperatureC, root.settings.units === "imperial" ? "imperial" : "metric") : ""
                        color: "white"
                    }
                    Text { text: "Wind"; color: "#bac2de" }
                    Text {
                        text: root.service && root.service.forecast
                            ? Model.formatWind(root.service.forecast.windKph, root.settings.units === "imperial" ? "imperial" : "metric")
                                + " " + root.service.forecast.windDirection : ""
                        color: "white"
                    }
                    Text { text: "Sunrise / sunset"; color: "#bac2de" }
                    Text {
                        text: root.service && root.service.forecast
                            ? root.service.forecast.sunrise + " / " + root.service.forecast.sunset : ""
                        color: "white"
                    }
                }

                Text {
                    visible: root.service && root.service.marine
                    color: "#89dceb"
                    text: root.service && root.service.marine
                        ? "Marine: " + Model.formatWave(root.service.marine.waveHeightM, root.settings.units === "imperial" ? "imperial" : "metric")
                            + " waves" + (root.service.marine.waveDirection ? " " + root.service.marine.waveDirection : "")
                        : ""
                }
                Text {
                    visible: root.service && root.service.marineError !== ""
                    color: "#bac2de"
                    text: root.service ? root.service.marineError : ""
                }
                Text {
                    visible: root.service && root.service.error !== ""
                    color: "#f38ba8"
                    text: root.service ? root.service.error : ""
                }

                Text {
                    visible: root.service && root.service.summary.factors && root.service.summary.factors.length > 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: "#cdd6f4"
                    text: root.service ? root.service.summary.factors.join(" ") : ""
                }

                Text {
                    visible: root.service && root.service.findingWater
                    text: "Searching nearby mapped waters…"
                    color: "#cdd6f4"
                }
                Text {
                    visible: root.service && root.service.waterError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.service ? root.service.waterError : ""
                    color: "#f38ba8"
                }
                ListView {
                    visible: root.service && root.service.waterFeatures.length > 0
                    width: parent.width
                    height: 95
                    clip: true
                    model: root.service ? root.service.waterFeatures : []
                    delegate: Button {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name + " · " + modelData.kind + " · "
                            + (modelData.distanceM / 1000).toFixed(1) + " km"
                        onClicked: root.selectLocation({
                            name: modelData.name,
                            latitude: modelData.latitude,
                            longitude: modelData.longitude,
                            timezone: "",
                            source: "openstreetmap"
                        })
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: "#a6adc8"
                    font.pixelSize: 11
                    text: "Forecast-based conditions are advisory, not a fish-activity or safety prediction. "
                        + "Nearby waters are map data, not evidence of access, legality, safety, or fish stock. "
                        + "Weather: Open-Meteo. Map data: © OpenStreetMap contributors."
                }
            }

            Loader {
                active: root.pickerOpen
                anchors.fill: parent
                z: 1
                source: Qt.resolvedUrl("LocationPicker.qml")
                onLoaded: {
                    item.service = root.service
                    item.selected.connect(root.selectLocation)
                    item.dismissed.connect(function() { root.pickerOpen = false })
                }
            }
        }
    }
}

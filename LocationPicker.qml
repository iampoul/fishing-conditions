import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var service: null
    property var selectedLocation: null
    signal selected(var location)
    signal dismissed()

    function choose(candidate) {
        autocompleteTimer.stop()
        if (service)
            service.cancelPlaceSearch()
        root.selected({
            name: candidate.label,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            timezone: candidate.timezone || "",
            source: "place-search"
        })
    }

    Timer {
        id: autocompleteTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.service)
                root.service.searchPlaces(searchField.text)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 8
        border.color: "#585b70"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "Choose fishing location"
            color: "white"
            font.bold: true
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            color: "#cdd6f4"
            text: "Search a city, town, or named place with Open-Meteo, then select a result."
        }

        Row {
            spacing: 8
            TextField {
                id: searchField
                width: Math.max(220, root.width - 32)
                placeholderText: "City or place"
                onTextEdited: {
                    if (root.service)
                        root.service.cancelPlaceSearch()
                    autocompleteTimer.restart()
                }
                onAccepted: {
                    autocompleteTimer.stop()
                    if (root.service)
                        root.service.searchPlaces(text)
                }
            }
        }

        Row {
            spacing: 8
            Button {
                text: "Use coordinates"
                onClicked: coordinates.visible = !coordinates.visible
            }
            Button {
                text: "Close"
                onClicked: root.dismissed()
            }
        }

        Column {
            id: coordinates
            visible: false
            spacing: 6
            TextField {
                id: latitude
                width: 180
                placeholderText: "Latitude (-90 to 90)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            TextField {
                id: longitude
                width: 180
                placeholderText: "Longitude (-180 to 180)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            Button {
                text: "Use these coordinates"
                onClicked: {
                    var lat = Number(latitude.text)
                    var lon = Number(longitude.text)
                    if (Number.isFinite(lat) && Number.isFinite(lon)
                            && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                        root.selected({
                            name: lat.toFixed(4) + ", " + lon.toFixed(4),
                            latitude: lat,
                            longitude: lon,
                            timezone: "",
                            source: "coordinates"
                        })
                    }
                }
            }
        }

        Text {
            visible: root.service && root.service.geocoding
            text: "Searching…"
            color: "#cdd6f4"
        }
        Text {
            visible: root.service && root.service.geocodeError !== ""
            text: root.service ? root.service.geocodeError : ""
            color: "#f38ba8"
            wrapMode: Text.Wrap
            width: parent.width
        }

        ListView {
            width: parent.width
            height: Math.max(0, parent.height - 230)
            clip: true
            model: root.service ? root.service.geocodeResults : []
            delegate: Button {
                required property var modelData
                width: ListView.view.width
                text: modelData.label
                onClicked: root.choose(modelData)
            }
        }
    }
}

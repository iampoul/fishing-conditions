import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property var service: null
    property var bar: null
    property var selectedLocation: null
    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property color bg: root.bar ? root.bar.background : Color.background
    readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
    readonly property color secondary: Color.muted
    readonly property color border: Color.popups.border
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
            timezone: candidate.timezone || ""
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
        color: root.bg
        border.color: root.border
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "Choose fishing location"
            color: root.fg
            font.bold: true
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            color: root.secondary
            text: "Search a street address, city, or place, then select a result."
        }

        RowLayout {
            width: parent.width
            spacing: 8
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Address or place"
                maximumLength: 200
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
            Button {
                text: "Close"
                onClicked: root.dismissed()
            }
        }

        Text {
            visible: root.service && root.service.geocoding
            text: "Searching…"
            color: root.secondary
        }
        Text {
            visible: root.service && root.service.geocodeError !== ""
            text: root.service ? root.service.geocodeError : ""
            color: root.urgent
            wrapMode: Text.Wrap
            width: parent.width
        }

        ListView {
            width: parent.width
            height: Math.max(0, parent.height - 120)
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


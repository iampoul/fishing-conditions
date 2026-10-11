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

            Item {
                id: searchFieldFrame
                Layout.fillWidth: true
                implicitHeight: 32

                Rectangle {
                    anchors.fill: parent
                    color: root.bg
                    border.color: root.border
                    radius: 4
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Address or place"
                    color: root.secondary
                    elide: Text.ElideRight
                    visible: searchField.text.length === 0
                }

                // Plain QtQuick TextEdit, not QtQuick.Controls TextField.
                // TextInput/TextField connect their canPaste check to the
                // global QClipboard::dataChanged signal and eagerly call
                // mimeData->text() on *every* clipboard owner change system-
                // wide, with no size cap on the native Wayland read — a
                // streaming foreign clipboard offer can stall the shell or
                // exhaust memory even if this field is never pasted into.
                // TextEdit's QQuickTextControl only reads the clipboard on
                // an explicit user action (paste shortcut), never from a
                // background signal, and onTextChanged below bounds the
                // result of that explicit read the same way maximumLength
                // bounded TextField.
                TextEdit {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    wrapMode: TextEdit.NoWrap
                    textFormat: TextEdit.PlainText
                    color: root.fg
                    selectByMouse: true
                    persistentSelection: false
                    font.pixelSize: 13
                    readonly property int maxLength: 200

                    Keys.onReturnPressed: (event) => {
                        event.accepted = true
                        autocompleteTimer.stop()
                        if (root.service)
                            root.service.searchPlaces(text)
                    }
                    Keys.onEnterPressed: (event) => {
                        event.accepted = true
                        autocompleteTimer.stop()
                        if (root.service)
                            root.service.searchPlaces(text)
                    }

                    onTextChanged: {
                        if (text.length > maxLength) {
                            var pos = cursorPosition
                            text = text.slice(0, maxLength)
                            cursorPosition = Math.min(pos, text.length)
                            return
                        }
                        if (root.service)
                            root.service.cancelPlaceSearch()
                        autocompleteTimer.restart()
                    }
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


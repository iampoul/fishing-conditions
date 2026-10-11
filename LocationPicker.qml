import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var service: null
    property var bar: null
    property var selectedLocation: null
    property string pasteNotice: ""
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

    // Explicit, bounded clipboard read for the search field's paste action.
    //
    // TextEdit's own paste()/insertFromMimeData() calls QMimeData::text()
    // directly with no size cap or deadline (qquicktextcontrol.cpp), so a
    // slow-drip or oversized foreign clipboard offer could still stall or
    // balloon memory during an explicit paste, even though the read is no
    // longer eager/background (that part was fixed by using TextEdit over
    // TextField/TextInput). Keys.onPressed below intercepts the paste
    // shortcut before TextEdit's own handler ever runs, and reads the
    // clipboard ourselves through `wl-paste`, wrapped in both a wall-clock
    // deadline (`timeout --signal=KILL`) and a byte ceiling
    // (BoundedCollector, same fail-closed helper the HTTP requests use).
    function startBoundedPaste() {
        if (pasteRequest.running)
            return
        root.pasteNotice = ""
        pasteRequest.command = ["timeout", "--signal=KILL", "2", "wl-paste", "--no-newline"]
        pasteRequest.running = true
    }

    Process {
        id: pasteRequest
        stdout: BoundedCollector { id: pasteBody; process: pasteRequest; maxBytes: 4096 }
        stderr: BoundedCollector { id: pasteStderr; process: pasteRequest; maxBytes: 1024 }
        onRunningChanged: if (running) {
            pasteBody.reset()
            pasteStderr.reset()
        }
        onExited: (exitCode) => {
            if (pasteBody.overflowed || exitCode === 124 || exitCode === 137) {
                root.pasteNotice = "Clipboard content was too large to paste."
                return
            }
            if (exitCode !== 0)
                return // nothing text-like on the clipboard; silently no-op, same as an empty paste
            if (pasteBody.text.length === 0)
                return
            searchField.insertBounded(pasteBody.text)
        }
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
                // background signal. Ctrl+V/Shift+Insert are intercepted
                // below and routed through startBoundedPaste() instead of
                // TextEdit's own unbounded paste(); middle-click (primary
                // selection paste) is swallowed by the MouseArea below.
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

                    function insertBounded(str) {
                        if (selectionStart !== selectionEnd)
                            remove(selectionStart, selectionEnd)
                        insert(cursorPosition, str)
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true
                            autocompleteTimer.stop()
                            if (root.service)
                                root.service.searchPlaces(text)
                            return
                        }
                        if (event.matches(StandardKey.Paste)) {
                            event.accepted = true
                            root.startBoundedPaste()
                            return
                        }
                    }

                    onTextChanged: {
                        root.pasteNotice = ""
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

                // Blocks middle-click (primary-selection) paste from ever
                // reaching the TextEdit below, so the only paste path is
                // the bounded one above.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    onClicked: {}
                }
            }

            Button {
                text: "Close"
                onClicked: root.dismissed()
            }
        }

        Text {
            visible: root.pasteNotice !== ""
            text: root.pasteNotice
            color: root.urgent
            wrapMode: Text.Wrap
            width: parent.width
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
            // A plain MouseArea + Text delegate, not a Controls.Button: the
            // label text comes verbatim from a third-party geocoder (OSM
            // Nominatim / Esri) and is untrusted. Text defaults to
            // textFormat: Text.AutoText, which will parse and render HTML —
            // including <img src="..."> — if the string looks like markup,
            // and QtQuick's rich-text image support fetches that src over
            // the network with no byte cap or collector, bypassing the
            // bounded curl requests entirely. textFormat: Text.PlainText
            // below forces the string to always render as literal text.
            delegate: Rectangle {
                id: resultRow
                required property var modelData
                width: ListView.view.width
                implicitHeight: resultLabel.implicitHeight + 12
                height: implicitHeight
                color: resultMouse.containsMouse ? Qt.darker(root.bg, 1.15) : root.bg
                border.color: root.border

                Text {
                    id: resultLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 6
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.fg
                    text: resultRow.modelData.label
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.choose(resultRow.modelData)
                }
            }
        }
    }
}


import QtQuick

Item {
    id: root
    clip: true

    property double latitude: 0
    property double longitude: 0
    property int zoom: 16
    property real markerLatitude: latitude
    property real markerLongitude: longitude
    property bool centered: false

    readonly property int tileSize: 256
    readonly property double worldSize: tileSize * Math.pow(2, zoom)
    readonly property double centerXPx: lon2x(longitude)
    readonly property double centerYPx: lat2y(latitude)
    readonly property int centerTileX: Math.floor(centerXPx / tileSize)
    readonly property int centerTileY: Math.floor(centerYPx / tileSize)

    function lon2x(lon) {
        return (lon + 180) / 360 * worldSize
    }

    function lat2y(lat) {
        var rad = lat * Math.PI / 180
        return (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * worldSize
    }

    function x2lon(x) {
        return x / worldSize * 360 - 180
    }

    function y2lat(y) {
        var n = Math.PI - 2 * Math.PI * y / worldSize
        return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)))
    }

    function ensureCentered() {
        if (centered)
            return
        if (markerLatitude === 0 && markerLongitude === 0)
            return
        centered = true
        recenter()
    }

    function recenter() {
        latitude = markerLatitude
        longitude = markerLongitude
    }

    function wake() {
        centered = true
        recenter()
    }

    Timer {
        id: wakeTimer
        interval: 500
        repeat: false
        onTriggered: root.ensureCentered()
    }

    Component.onCompleted: wakeTimer.start()

    Rectangle {
        color: "#313244"
        anchors.fill: parent
    }

    Item {
        id: tilesLayer
        x: root.width / 2 - root.centerXPx
        y: root.height / 2 - root.centerYPx

        Repeater {
            model: 25

            delegate: Image {
                required property int index
                readonly property int gx: index % 5 - 2
                readonly property int gy: Math.floor(index / 5) - 2
                readonly property int tx: root.centerTileX + gx
                readonly property int ty: root.centerTileY + gy
                readonly property bool inBounds: {
                    var n = Math.pow(2, root.zoom)
                    return tx >= 0 && ty >= 0 && tx < n && ty < n
                }
                readonly property string esriSource: inBounds
                    ? "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/"
                        + root.zoom + "/" + ty + "/" + tx
                    : ""

                x: tx * root.tileSize
                y: ty * root.tileSize
                width: root.tileSize
                height: root.tileSize
                source: esriSource
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Error)
                        console.warn("Esri tile failed: " + esriSource + " (" + root.zoom + "/" + tx + "/" + ty + ")")
                }
            }
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        border.width: 2
        border.color: "white"
        color: "#f38ba8"
        anchors.centerIn: parent
    }

    Rectangle {
        width: 3
        height: 8
        color: "#f38ba8"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -6
    }

    MouseArea {
        id: panArea
        anchors.fill: parent
        cursorShape: Qt.OpenHandCursor
        property bool dragging: false
        property real pressX: 0
        property real pressY: 0
        property real pressLon: 0
        property real pressLat: 0
        onPressed: (mouse) => {
            pressX = mouse.x
            pressY = mouse.y
            pressLon = root.longitude
            pressLat = root.latitude
            dragging = true
            cursorShape = Qt.ClosedHandCursor
        }
        onPositionChanged: (mouse) => {
            if (!dragging)
                return
            var cx = root.lon2x(pressLon) + (pressX - mouse.x)
            var cy = root.lat2y(pressLat) + (pressY - mouse.y)
            root.longitude = root.x2lon(cx)
            root.latitude = root.y2lat(cy)
        }
        onReleased: {
            dragging = false
            cursorShape = Qt.OpenHandCursor
        }
        onWheel: (wheel) => {
            if (dragging)
                return
            root.zoom = Math.max(2, Math.min(19, root.zoom + (wheel.angleDelta.y > 0 ? 1 : -1)))
        }
    }

    onMarkerLatitudeChanged: ensureCentered()
    onMarkerLongitudeChanged: ensureCentered()

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 4

        Rectangle {
            width: 22; height: 22; radius: 4
            color: "#e6ffffff"; border.color: "#00000022"
            Text { anchors.centerIn: parent; text: "+"; color: "#1e1e2e"; font.bold: true; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; onClicked: root.zoom = Math.min(19, root.zoom + 1) }
        }
        Rectangle {
            width: 22; height: 22; radius: 4
            color: "#e6ffffff"; border.color: "#00000022"
            Text { anchors.centerIn: parent; text: "\u2212"; color: "#1e1e2e"; font.bold: true; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; onClicked: root.zoom = Math.max(2, root.zoom - 1) }
        }
        Rectangle {
            width: 22; height: 22; radius: 4
            color: "#e6ffffff"; border.color: "#00000022"
            Text { anchors.centerIn: parent; text: "\u25CE"; color: "#1e1e2e"; font.bold: true; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; onClicked: root.recenter() }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        color: "#00000066"
        style: Text.Outline
        styleColor: "white"
        font.pixelSize: 9
        text: "\u00A9 Esri, OSM"
    }
}

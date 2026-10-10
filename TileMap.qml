import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    clip: true

    signal tileReady(string key)

    property double latitude: 0
    property double longitude: 0
    property int zoom: 16
    property real markerLatitude: latitude
    property real markerLongitude: longitude
    property bool centered: false
    property var downloaded: ({})

    readonly property int tileSize: 256
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/omarchy-fishing/tiles"
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

    function tileKey(tx, ty) {
        return zoom + "/" + tx + "/" + ty
    }

    function tilePath(tx, ty) {
        return cacheDir + "/" + tileKey(tx, ty) + ".png"
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

    property var tileQueue: []
    property var queued: ({})
    property var failed: ({})

    function requestTile(tx, ty) {
        var key = tileKey(tx, ty)
        if (downloaded[key] || queued[key])
            return
        if (failed[key] && Date.now() - failed[key] < 15000)
            return
        queued[key] = true
        tileQueue.push({
            key: key,
            url: "https://tile.openstreetmap.org/" + zoom + "/" + tx + "/" + ty + ".png",
            path: tilePath(tx, ty)
        })
        tileWorker1.tryPull()
        tileWorker2.tryPull()
        tileWorker3.tryPull()
    }

    function onWorkerExit(key, path, exitCode) {
        delete queued[key]
        if (exitCode === 0) {
            downloaded[key] = true
            tileReady(key)
        } else {
            failed[key] = Date.now()
        }
    }

    component TileWorker: Process {
        id: worker
        property var owner: null
        property string currentKey: ""
        property string currentPath: ""
        property string currentUrl: ""

        function tryPull() {
            if (owner === null || currentKey !== "" || owner.tileQueue.length === 0)
                return
            var item = owner.tileQueue.shift()
            currentKey = item.key
            currentPath = item.path
            currentUrl = item.url
            exec([
                "curl", "--fail", "--silent", "--show-error",
                "--connect-timeout", "3", "--max-time", "10",
                "--max-filesize", "262144",
                "--retry", "2", "--retry-delay", "1", "--retry-all-errors",
                "--create-dirs",
                "--user-agent", "OmarchyFishing/0.2 (+https://github.com/iampoul/fishing-conditions)",
                "--output", currentPath, currentUrl
            ])
        }

        onExited: (exitCode) => {
            var key = currentKey
            var path = currentPath
            currentKey = ""
            currentPath = ""
            currentUrl = ""
            if (owner === null)
                return
            owner.onWorkerExit(key, path, exitCode)
            tryPull()
        }
    }

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
                readonly property string myKey: root.tileKey(tx, ty)
                readonly property string myPath: root.tilePath(tx, ty)

                x: tx * root.tileSize
                y: ty * root.tileSize
                width: root.tileSize
                height: root.tileSize

                function refreshSource() {
                    var n = Math.pow(2, root.zoom)
                    if (tx < 0 || ty < 0 || tx >= n || ty >= n) {
                        source = ""
                        return
                    }
                    source = root.downloaded[myKey] ? "file://" + myPath : ""
                }

                Component.onCompleted: {
                    refreshSource()
                    var n = Math.pow(2, root.zoom)
                    if (tx >= 0 && ty >= 0 && tx < n && ty < n)
                        root.requestTile(tx, ty)
                }

                onMyKeyChanged: {
                    refreshSource()
                    var n = Math.pow(2, root.zoom)
                    if (tx >= 0 && ty >= 0 && tx < n && ty < n)
                        root.requestTile(tx, ty)
                }

                Connections {
                    target: root
                    function onTileReady(key) {
                        if (key === myKey)
                            refreshSource()
                    }
                }
            }
        }
    }

    TileWorker { id: tileWorker1; owner: root }
    TileWorker { id: tileWorker2; owner: root }
    TileWorker { id: tileWorker3; owner: root }

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

    onMarkerLatitudeChanged: ensureCentered()
    onMarkerLongitudeChanged: ensureCentered()

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        color: "#00000066"
        style: Text.Outline
        styleColor: "white"
        font.pixelSize: 9
        text: "\u00A9 OpenStreetMap"
    }
}

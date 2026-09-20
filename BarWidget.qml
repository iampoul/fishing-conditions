import QtQuick
import qs.Ui
import "ConditionsModel.js" as Model

BarWidget {
    id: root

    moduleName: "io.github.iampoul.fishing-conditions"
    readonly property var fishingService: bar && bar.shell
        ? bar.shell.serviceFor(moduleName) : null
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    implicitWidth: label.implicitWidth + 16
    implicitHeight: Math.max(label.implicitHeight + 8, barSize)

    function open() {
        if (panelLoader.item)
            panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item)
            panelLoader.item.close()
    }

    function togglePanel() {
        if (panelLoader.item)
            panelLoader.item.toggle()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
            panelLoader.item.closeForPopoutSwitch()
    }

    function updateSettings(next) {
        if (!bar || !bar.shell)
            return
        bar.shell.updateEntryInline(moduleName, next)
    }

    function injectPanel() {
        if (!panelLoader.item)
            return
        panelLoader.item.bar = bar
        panelLoader.item.settings = settings
        panelLoader.item.anchorItem = clickArea
        panelLoader.item.hostWidget = root
        panelLoader.item.service = fishingService
        panelLoader.item.persistSettings = updateSettings
    }

    onBarChanged: injectPanel()
    onSettingsChanged: {
        if (fishingService)
            fishingService.configure(settings)
        injectPanel()
    }
    onFishingServiceChanged: {
        if (fishingService)
            fishingService.configure(settings)
        injectPanel()
    }
    Component.onCompleted: {
        if (fishingService)
            fishingService.configure(settings)
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: root.fishingService && root.fishingService.summary.level === "unsafe"
            ? "#ffb4ab" : "white"
        text: {
            if (!root.fishingService)
                return "🎣 Loading"
            if (!root.fishingService.hasLocation)
                return "🎣 Set location"
            if (!root.fishingService.forecast)
                return root.fishingService.loading ? "🎣 Loading" : "🎣 Unavailable"
            var forecast = root.fishingService.forecast
            var units = root.settings.units === "imperial" ? "imperial" : "metric"
            var staleMark = root.fishingService.stale ? " · stale" : ""
            return "🎣 " + root.fishingService.summary.label
                + " · " + Model.formatWind(forecast.windKph, units) + staleMark
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (root.fishingService)
                    root.fishingService.refresh(true)
            } else {
                root.togglePanel()
            }
        }
    }

    Loader {
        id: panelLoader
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }
}

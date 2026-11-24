import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../Widgets"
import "../../Services/core" as Core

PanelWindow {
    id: root

    visible: false
    implicitWidth: (root.screen ? root.screen.width / 3 : 680)
    implicitHeight: (root.screen ? root.screen.height / 2 : 500)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:app-launcher"

    property var apps: []
    property var filteredApps: []
    property string query: ""
    property int selectedIndex: 0
    property bool loading: false

    readonly property string helperPath: Core.PathService.configPath("scripts/app_launcher.py")

    function open() {
        root.visible = true
        root.query = ""
        root.selectedIndex = 0
        root.reload()
        Qt.callLater(function() { searchField.forceActiveFocus(); searchField.selectAll(); })
    }

    function close() { root.visible = false }
    function toggle() { root.visible ? root.close() : root.open() }

    function reload() {
        if (listProc.running) return
        root.loading = true
        listProc.buffer = ""
        listProc.command = ["python3", root.helperPath, "list"]
        listProc.running = true
    }

    function applyFilter() {
        var needle = root.query.toLowerCase().trim()
        if (!needle) {
            root.filteredApps = root.apps
        } else {
            root.filteredApps = root.apps.filter(function(app) {
                return String(app.name).toLowerCase().indexOf(needle) !== -1
                    || String(app.comment || "").toLowerCase().indexOf(needle) !== -1
            })
        }
        root.selectedIndex = 0
        appList.positionViewAtBeginning()
    }

    function selectedApp() {
        return root.filteredApps.length > 0
            ? root.filteredApps[Math.max(0, Math.min(root.selectedIndex, root.filteredApps.length - 1))]
            : null
    }

    function launchApp(app) {
        if (!app) return
        launchProc.buffer = ""
        launchProc.command = ["python3", root.helperPath, "launch", "--exec", app.exec]
        launchProc.running = true
        root.close()
    }

    function moveSelection(delta) {
        if (!root.filteredApps.length) return
        root.selectedIndex = (root.selectedIndex + delta + root.filteredApps.length) % root.filteredApps.length
        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    IpcHandler {
        target: "app-launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        function search(query: string): void {
            root.open()
            root.query = query
            root.applyFilter()
        }
    }

    Process {
        id: listProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => listProc.buffer += data }
        onExited: {
            root.loading = false
            try {
                var result = JSON.parse(listProc.buffer.trim())
                if (result.ok) root.apps = result.items || []
            } catch (e) {}
            listProc.buffer = ""
            root.applyFilter()
        }
    }

    Process {
        id: launchProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => launchProc.buffer += data }
    }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: root.visible; onActivated: root.close() }
    Shortcut { sequence: "Return"; enabled: root.visible; onActivated: root.launchApp(root.selectedApp()) }
    Shortcut { sequence: "Enter"; enabled: root.visible; onActivated: root.launchApp(root.selectedApp()) }
    Shortcut { sequence: "Up"; enabled: root.visible; onActivated: root.moveSelection(-1) }
    Shortcut { sequence: "Down"; enabled: root.visible; onActivated: root.moveSelection(1) }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(70, (root.screen ? root.screen.height : 900) * 0.12)
        width: parent.width
        height: parent.height
        radius: Theme.radius
        color: Theme.withAlpha(Theme.background, 0.96)
        border.width: 1
        border.color: Theme.withAlpha(Theme.text, 0.14)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radius
                color: Theme.withAlpha(Theme.surface, 0.9)
                border.width: 1
                border.color: searchField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.text, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        text: "⌕"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                        color: Theme.primary
                    }

                    Controls.TextField {
                        id: searchField
                        Layout.fillWidth: true
                        text: root.query
                        placeholderText: root.loading ? "Loading applications…" : "Search applications"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: Theme.text
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        background: Item {}
                        onTextChanged: {
                            root.query = text
                            root.applyFilter()
                        }
                        Keys.onUpPressed: function(event) { event.accepted = true; root.moveSelection(-1) }
                        Keys.onDownPressed: function(event) { event.accepted = true; root.moveSelection(1) }
                        Keys.onReturnPressed: function(event) { event.accepted = true; root.launchApp(root.selectedApp()) }
                        Keys.onEnterPressed: function(event) { event.accepted = true; root.launchApp(root.selectedApp()) }
                        Keys.onEscapePressed: function(event) { event.accepted = true; root.close() }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.withAlpha(Theme.surface, 0.44)
                clip: true

                Controls.ScrollView {
                    anchors.fill: parent
                    Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded

                    ListView {
                        id: appList
                        anchors.fill: parent
                        model: root.filteredApps
                        currentIndex: root.selectedIndex
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 4

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: appList.width
                            height: 64
                            radius: Theme.radius
                            color: index === root.selectedIndex
                                ? Theme.primary
                                : (delegateMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : "transparent")

                            MouseArea {
                                id: delegateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: root.selectedIndex = index
                                onClicked: root.launchApp(modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    sourceSize: Qt.size(38, 38)
                                    source: modelData.icon
                                        ? "image://icon/" + modelData.icon
                                        : "image://icon/application-x-executable"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: index === root.selectedIndex ? Theme.withAlpha(Theme.background, 0.96) : Theme.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: modelData.comment || modelData.id
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: index === root.selectedIndex
                                            ? Theme.withAlpha(Theme.background, 0.72)
                                            : Theme.withAlpha(Theme.text, 0.68)
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.loading && root.filteredApps.length === 0
                            text: root.apps.length === 0 ? "No applications found" : "No matches"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.withAlpha(Theme.text, 0.68)
                        }
                    }
                }
            }
        }
    }
}

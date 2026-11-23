import QtQuick
import Quickshell.Io
import "../../../Services/core/Log.js" as Log

Item {
    id: service

    visible: false
    width: 0
    height: 0

    property var diskName: ["/", "D"]
    property var diskUsed: ["0G"]
    property var diskTotal: ["0G"]
    property var diskPercent: ["0%"]

    property var total: []

    function refresh() {
        if (diskProc.running) return;
        diskProc.output = "";
        diskProc.running = true;
    }

    function parseDiskStats(text) {
        const rows = String(text || "").trim().split('#').map(fila => fila.split('|'));
        const matrix = rows[0].map((_, columna) => rows.map(fila => fila[columna]));

        service.diskUsed = matrix[0];
        service.diskTotal = matrix[1];
        service.diskPercent = matrix[2];
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h / /mnt/windows/Pablo_D | awk 'NR>1 {print $3 \"|\" $2 \"|\" $5 \"#\"}'"]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => { diskProc.output += data; } }
        onExited: {
            try {
                service.parseDiskStats(diskProc.output);
            } catch (e) {
                Log.warn("DiskService", "Disk stats parse error: " + e);
            }
            diskProc.output = "";
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}

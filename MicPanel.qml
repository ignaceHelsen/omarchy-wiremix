import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Quattro's omarchy.audio panel lists source *nodes*, but a laptop exposes its
// internal / headset / jack mics as *ports* on one node — so that picker shows
// a single entry and no real choice. This panel drives the ports directly.
Panel {
  id: root
  moduleName: "ignace.wiremix"
  ipcTarget: "ignace.wiremix"

  property var ports: []
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property string helper: Qt.resolvedUrl("mic-ports").toString().replace("file://", "")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { if (!listProc.running) listProc.running = true }

  function applyPorts(out) {
    var list = []
    var lines = String(out).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length < 3) continue
      list.push({ name: parts[0], description: parts[1], active: parts[2] === "1" })
    }
    root.ports = list
    if (root.cursorIndex >= list.length) root.cursorIndex = 0
  }

  function setPort(name) {
    setProc.command = [root.helper, "set", name]
    setProc.running = true
  }

  function openWiremix() {
    if (root.bar) root.bar.run("omarchy-launch-or-focus-tui wiremix")
  }

  Process {
    id: listProc
    command: [root.helper, "list"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyPorts(text) }
  }

  Process {
    id: setProc
    onExited: root.refresh()
  }

  // Ports change when a jack is plugged in, so re-read while the panel is open.
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍬"
    slotSize: Style.bar.iconSlot
    tooltipText: "Microphone input"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.openWiremix()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (root.ports.length === 0) return
        var d = dy !== 0 ? dy : dx
        root.cursorIndex = (root.cursorIndex + d + root.ports.length) % root.ports.length
      }
      onActivateRequested: {
        var p = root.ports[root.cursorIndex]
        if (root.cursorActive && p) root.setPort(p.name)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "MICROPHONE"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Repeater {
          model: root.ports

          Button {
            required property var modelData
            required property int index

            width: column.width
            text: modelData.description
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
            leftAlign: true
            bordered: true
            active: modelData.active
            hasCursor: root.cursorActive && root.cursorIndex === index
            onClicked: root.setPort(modelData.name)
            onHovered: function(h) {
              if (h) {
                root.cursorActive = true
                root.cursorIndex = index
              }
            }
          }
        }

        Text {
          visible: root.ports.length === 0
          width: column.width
          text: "No microphone ports found"
          color: root.bar.foreground
          opacity: 0.6
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator {}

        Button {
          width: column.width
          text: "Full mixer (wiremix)"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          leftAlign: true
          bordered: true
          onClicked: {
            root.close()
            root.openWiremix()
          }
        }
      }
    }
  }
}

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// owin's preset flyout: the presets of the focused workspace, with
// restore on click, a favorite star, delete with confirm, and a save row
// that captures the current layout under a new name.
Panel {
  id: root
  moduleName: "owin"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string cliPath: ""
  readonly property var barIdentity: hostWidget || root

  readonly property int workspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  property var presets: []
  property string statusText: ""
  property string confirmDelete: ""
  readonly property bool busy: actionProc.running || restoreProc.running

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.55)

  onWorkspaceChanged: if (root.opened) refresh()

  function open() {
    root.statusText = ""
    root.confirmDelete = ""
    refresh()
    root.controller.show()
  }

  function close() {
    nameField.text = ""
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function refresh() {
    if (cliPath === "" || listProc.running) return
    listProc.command = [cliPath, "list", "--json", "--ws", String(root.workspace)]
    listProc.running = true
  }

  function restorePreset(name) {
    if (restoreProc.running) return
    root.statusText = "restoring " + name + "…"
    restoreProc.command = [cliPath, "restore", name, "--ws", String(root.workspace)]
    restoreProc.running = true
  }

  function runAction(args) {
    if (actionProc.running) return
    actionProc.command = [cliPath].concat(args)
    actionProc.running = true
  }

  function saveCurrent() {
    var name = nameField.text.trim()
    if (name === "") return
    root.statusText = "capturing " + name + "…"
    runAction(["capture", name, "--ws", String(root.workspace)])
    nameField.text = ""
  }

  Process {
    id: listProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "{}"))
          root.presets = parsed.presets || []
        } catch (e) {
          root.presets = []
        }
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      root.statusText = ""
      root.confirmDelete = ""
      root.refresh()
    }
  }

  Process {
    id: restoreProc
    stdout: StdioCollector {
      id: restoreOut
      waitForEnd: true
    }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      root.statusText = String(restoreOut.text || "").trim()
      root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: nameField.activeFocus
      onCloseRequested: root.close()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
          text: "OWIN — WORKSPACE " + root.workspace
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        Text {
          visible: root.presets.length === 0
          width: parent.width
          text: "No presets yet. Lay out your windows,\nname it below, and save."
          color: root.dim
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.presets

          Row {
            required property var modelData
            width: content.width
            spacing: Style.space(4)

            Button {
              iconText: modelData.favorite ? "󰓎" : "󰓒"
              foreground: modelData.favorite ? root.contentForeground : root.dim
              tooltipText: modelData.favorite ? "Favorite (left click on the bar runs this)" : "Make favorite"
              onClicked: root.runAction(["favorite", modelData.name, "--ws", String(root.workspace)])
            }

            Button {
              width: parent.width - Style.space(88)
              leftAlign: true
              text: modelData.name
              tooltipText: "Restore this layout (" + modelData.windows + " windows"
                + (modelData.floating > 0 ? ", " + modelData.floating + " floating)" : ")")
              onClicked: root.restorePreset(modelData.name)

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.windows
                color: root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              iconText: root.confirmDelete === modelData.name ? "󰀦" : "󰆴"
              foreground: root.confirmDelete === modelData.name
                ? (bar ? bar.urgent : Color.urgent) : root.dim
              tooltipText: root.confirmDelete === modelData.name ? "Click again to delete" : "Delete preset"
              onClicked: {
                if (root.confirmDelete === modelData.name)
                  root.runAction(["delete", modelData.name, "--ws", String(root.workspace)])
                else
                  root.confirmDelete = modelData.name
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.darker(root.contentForeground, 2.2)
        }

        Row {
          width: parent.width
          spacing: Style.space(4)

          TextField {
            id: nameField
            width: parent.width - saveButton.implicitWidth - Style.space(4)
            placeholderText: "Save current layout as…"
            foreground: root.contentForeground
            onAccepted: root.saveCurrent()
          }

          Button {
            id: saveButton
            text: "Save"
            bordered: true
            anchors.verticalCenter: nameField.verticalCenter
            onClicked: root.saveCurrent()
          }
        }

        Text {
          visible: root.statusText !== ""
          width: parent.width
          text: root.statusText
          color: root.dim
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}

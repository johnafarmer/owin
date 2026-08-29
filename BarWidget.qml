import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// owin bar button. Left click restores the favorite preset for the
// focused workspace; right click opens the preset flyout. All the actual
// window work happens in bin/owin.
BarWidget {
  id: root
  moduleName: "owin"

  readonly property string cliPath: Qt.resolvedUrl("bin/owin").toString().replace("file://", "")
  readonly property int currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property bool busy: restoreProc.running

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("cliPath" in target) target.cliPath = root.cliPath
  }

  function restoreFavorite() {
    if (restoreProc.running) return
    restoreProc.command = [cliPath, "restore", "--notify", "--ws", String(currentWorkspace)]
    restoreProc.running = true
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: restoreProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
    }
  }

  IpcHandler {
    target: "owin"

    function restore(): void { root.restoreFavorite() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.busy ? "󰑓" : "󱂬"
    tooltipText: "owin — workspace " + root.currentWorkspace

    onPressed: function(b) {
      if (b === Qt.RightButton || b === Qt.MiddleButton) root.togglePanel()
      else root.restoreFavorite()
    }
  }
}

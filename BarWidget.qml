import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Compliantish bar entry:
// BarWidget loads nested Panel.qml via Loader. kinds: ["bar-widget"] only.
BarWidget {
  id: root
  moduleName: "kenhara.compliantish"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : "monospace"

  property int refreshIntervalSec: {
    var n = 900
    try {
      if (root.settings && root.settings.refreshIntervalSec !== undefined)
        n = Number(root.settings.refreshIntervalSec)
      else if (typeof root.setting === "function")
        n = Number(root.setting("refreshIntervalSec", 900))
    } catch (e) {}
    if (!isFinite(n)) n = 900
    return Math.max(60, Math.min(86400, Math.round(n)))
  }

  property int screenLockMaxSec: {
    var n = 900
    try {
      if (root.settings && root.settings.screenLockMaxSec !== undefined)
        n = Number(root.settings.screenLockMaxSec)
      else if (typeof root.setting === "function")
        n = Number(root.setting("screenLockMaxSec", 900))
    } catch (e) {}
    if (!isFinite(n)) n = 900
    return Math.max(60, Math.min(86400, Math.round(n)))
  }

  property bool notifyOnFail: {
    try {
      if (root.settings && root.settings.notifyOnFail !== undefined)
        return !!root.settings.notifyOnFail
      if (typeof root.setting === "function")
        return !!root.setting("notifyOnFail", false)
    } catch (e) {}
    return false
  }

  property bool enableDiskEncryption: {
    try {
      if (root.settings && root.settings.enableDiskEncryption !== undefined)
        return !!root.settings.enableDiskEncryption
      if (typeof root.setting === "function")
        return !!root.setting("enableDiskEncryption", true)
    } catch (e) {}
    return true
  }

  property bool enableScreenLock: {
    try {
      if (root.settings && root.settings.enableScreenLock !== undefined)
        return !!root.settings.enableScreenLock
      if (typeof root.setting === "function")
        return !!root.setting("enableScreenLock", true)
    } catch (e) {}
    return true
  }

  property bool enableAntivirus: {
    try {
      if (root.settings && root.settings.enableAntivirus !== undefined)
        return !!root.settings.enableAntivirus
      if (typeof root.setting === "function")
        return !!root.setting("enableAntivirus", true)
    } catch (e) {}
    return true
  }

  property bool enablePasswordManager: {
    try {
      if (root.settings && root.settings.enablePasswordManager !== undefined)
        return !!root.settings.enablePasswordManager
      if (typeof root.setting === "function")
        return !!root.setting("enablePasswordManager", true)
    } catch (e) {}
    return true
  }

  property bool enableAutoUpdates: {
    try {
      if (root.settings && root.settings.enableAutoUpdates !== undefined)
        return !!root.settings.enableAutoUpdates
      if (typeof root.setting === "function")
        return !!root.setting("enableAutoUpdates", true)
    } catch (e) {}
    return true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function handleSummonPayload(obj) {
    return complianceStore.handleSummonPayload(obj)
  }

  function open(payloadJson) {
    if (payloadJson !== undefined && payloadJson !== null && String(payloadJson).length)
      root.handleSummonPayload(payloadJson)
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function onBarMiddleClick() {
    complianceStore.refresh()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("store" in target) target.store = complianceStore
  }

  function syncStoreSettings() {
    complianceStore.applySettings({
      refreshIntervalSec: root.refreshIntervalSec,
      screenLockMaxSec: root.screenLockMaxSec,
      notifyOnFail: root.notifyOnFail,
      enableDiskEncryption: root.enableDiskEncryption,
      enableScreenLock: root.enableScreenLock,
      enableAntivirus: root.enableAntivirus,
      enablePasswordManager: root.enablePasswordManager,
      enableAutoUpdates: root.enableAutoUpdates
    })
    complianceStore.panelOpen = root.opened
  }

  function worstAccent() {
    var w = complianceStore.worstStatus
    if (w === "fail") return Color.urgent
    if (w === "unknown") return Qt.rgba(1.0, 0.82, 0.48, 1.0)
    return Color.accent
  }

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    syncStoreSettings()
  }
  onOpenedChanged: complianceStore.panelOpen = root.opened
  onRefreshIntervalSecChanged: syncStoreSettings()
  onScreenLockMaxSecChanged: syncStoreSettings()
  onNotifyOnFailChanged: syncStoreSettings()
  onEnableDiskEncryptionChanged: syncStoreSettings()
  onEnableScreenLockChanged: syncStoreSettings()
  onEnableAntivirusChanged: syncStoreSettings()
  onEnablePasswordManagerChanged: syncStoreSettings()
  onEnableAutoUpdatesChanged: syncStoreSettings()

  function mirrorSettingsEnable(code, enabled) {
    // Best-effort write-back into mutable settings; ignore if read-only.
    if (!root.settings) return
    var key = ""
    if (code === "HD") key = "enableDiskEncryption"
    else if (code === "SL") key = "enableScreenLock"
    else if (code === "AV") key = "enableAntivirus"
    else if (code === "PW") key = "enablePasswordManager"
    else if (code === "AU") key = "enableAutoUpdates"
    else return
    try {
      root.settings[key] = !!enabled
    } catch (e) {}
  }

  ComplianceStore {
    id: complianceStore
    onCheckEnableChanged: function(code, enabled) {
      root.mirrorSettingsEnable(code, enabled)
    }
  }

  Component.onCompleted: {
    syncStoreSettings()
  }

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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // ● N/M — no shields, no letter codes (dot tint lives in panel rows)
    text: complianceStore.barLabel || "● —"
    horizontalMargin: 8.5
    tooltipText: {
      var tot = complianceStore.totalCount
      var tip = "Compliantish — " + (tot
        ? (complianceStore.passCount + "/" + tot + " pass")
        : "no checks enabled")
      if (complianceStore.barTooltipDetail)
        tip += " · " + complianceStore.barTooltipDetail
      if (complianceStore.lastUpdatedText)
        tip += " · refreshed " + complianceStore.lastUpdatedText
      tip += " · middle: refresh · right: close"
      return tip
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.onBarMiddleClick()
      else if (buttonCode === Qt.RightButton) root.close()
    }
  }
}

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Nested details panel for Compliantish (loaded by BarWidget — not a separate kind).
// KeyboardPanel shell matches rocketlauncher Panel.qml (oracle).
Panel {
  id: root
  moduleName: "kenhara.compliantish"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var store: null
  property bool checksMenuOpen: false

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : "monospace"
  readonly property color themeBackground: {
    try {
      if (typeof Color !== "undefined" && Color.popups && Color.popups.background)
        return Color.popups.background
      if (typeof Color !== "undefined" && Color.background)
        return Color.background
    } catch (e) {}
    return Qt.rgba(0.1, 0.1, 0.12, 1)
  }
  readonly property color surfaceColor: Qt.rgba(
    contentForeground.r, contentForeground.g, contentForeground.b, 0.06)
  readonly property color dimForeground: Qt.darker(contentForeground, 1.45)
  readonly property color fainterForeground: Qt.darker(contentForeground, 1.7)

  readonly property var liveStore: store
  readonly property int panelBaseHeight: Style.space(520)

  onOpenedChanged: {
    if (root.opened && liveStore)
      liveStore.refresh()
    if (!root.opened)
      root.checksMenuOpen = false
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function handleSummonPayload(obj) {
    if (!liveStore) return false
    var acted = liveStore.handleSummonPayload(obj)
    if (acted && !root.opened)
      root.open()
    return acted
  }

  function worstColor() {
    if (!liveStore) return Qt.rgba(1.0, 0.82, 0.48, 1.0)
    var w = liveStore.worstStatus
    if (w === "fail") return Color.urgent
    if (w === "unknown") return Qt.rgba(1.0, 0.82, 0.48, 1.0)
    return Color.accent
  }

  function checkEnabledFor(code) {
    if (!liveStore) return true
    return liveStore.isCheckEnabled(code)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(root.panelBaseHeight)
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Style.space(16)
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: contentCol
          width: flick.width
          spacing: Style.space(14)
          opacity: liveStore && liveStore.loading ? 0.72 : 1.0

          Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
          }

          // Header — full-width title plane; Checks + Refresh on their own row
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              spacing: Style.space(8)
              Text {
                text: "\uf023"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "COMPLIANTISH"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                font.letterSpacing: 2.4
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Text {
              text: {
                if (!liveStore) return "device checks"
                if (liveStore.loading) return "device checks · probing…"
                if (liveStore.lastError) return liveStore.lastError
                return "device checks · refreshed " + (liveStore.lastUpdatedText || "—")
              }
              textFormat: Text.PlainText
              color: root.contentForeground
              opacity: 0.45
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: Math.max(0, parent.width - checksBtn.width - refreshBtn.width - parent.spacing * 2)
                height: 1
              }

              Rectangle {
                id: checksBtn
                width: checksLabel.implicitWidth + Style.space(14)
                height: Style.space(26)
                radius: 6
                color: (root.checksMenuOpen || checksMa.containsMouse)
                  ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  : root.surfaceColor
                border.width: 1
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Text {
                  id: checksLabel
                  anchors.centerIn: parent
                  text: root.checksMenuOpen ? "Checks ▴" : "Checks ▾"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: checksMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.checksMenuOpen = !root.checksMenuOpen
                }
              }

              Rectangle {
                id: refreshBtn
                width: refreshLabel.implicitWidth + Style.space(14)
                height: Style.space(26)
                radius: 6
                color: refreshMa.containsMouse
                  ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  : root.surfaceColor
                border.width: 1
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Text {
                  id: refreshLabel
                  anchors.centerIn: parent
                  text: liveStore && liveStore.loading ? "…" : "Refresh"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: refreshMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (liveStore) liveStore.refresh()
                }
              }
            }
          }

          // Checks menu — enable/disable each of the five agent lights
          Rectangle {
            visible: root.checksMenuOpen
            width: parent.width
            height: checksMenuCol.implicitHeight + Style.space(16)
            radius: 8
            color: root.surfaceColor
            border.width: 1
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

            Column {
              id: checksMenuCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(12)
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: "Enable or disable each check"
                color: root.contentForeground
                opacity: 0.55
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: liveStore ? liveStore.allCheckDefs : []
                delegate: Row {
                  width: checksMenuCol.width
                  spacing: Style.space(10)

                  Column {
                    width: parent.width - toggleWell.width - Style.space(10)
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      width: parent.width
                      text: modelData.label || modelData.code || "?"
                      textFormat: Text.PlainText
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: root.checkEnabledFor(modelData.code) ? "On — shown in checklist" : "Off — hidden from checklist"
                      color: root.contentForeground
                      opacity: 0.4
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  Rectangle {
                    id: toggleWell
                    width: Style.space(46)
                    height: Style.space(24)
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.checkEnabledFor(modelData.code)
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)

                    Rectangle {
                      width: Style.space(18)
                      height: Style.space(18)
                      radius: width / 2
                      anchors.verticalCenter: parent.verticalCenter
                      x: root.checkEnabledFor(modelData.code)
                        ? parent.width - width - Style.space(3)
                        : Style.space(3)
                      color: root.contentForeground

                      Behavior on x {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      text: root.checkEnabledFor(modelData.code) ? "On" : "Off"
                      color: root.contentForeground
                      opacity: 0.0
                      font.pixelSize: 1
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (!liveStore) return
                        var code = modelData.code
                        liveStore.setCheckEnabled(code, !liveStore.isCheckEnabled(code))
                      }
                    }
                  }
                }
              }

              Text {
                width: parent.width
                text: "Widget settings remain a secondary way to change the same flags."
                color: root.contentForeground
                opacity: 0.28
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }
            }
          }

          // Summary strip — passCount from actual statuses only
          Rectangle {
            width: parent.width
            height: summaryRow.implicitHeight + Style.space(14)
            radius: 8
            color: root.surfaceColor
            border.width: 1
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

            Row {
              id: summaryRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                text: "●"
                color: root.worstColor()
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(28)
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  text: {
                    if (!liveStore) return "—"
                    var tot = liveStore.totalCount
                    if (!tot) return "no checks enabled"
                    return liveStore.passCount + " of " + tot + " pass"
                  }
                  textFormat: Text.PlainText
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  width: parent.width
                  text: {
                    if (!liveStore) return ""
                    var autoLbl = liveStore.refreshIntervalLabel || "15m"
                    var bits = ["auto every " + autoLbl]
                    if (liveStore.failCount > 0)
                      bits.push("fail " + liveStore.failListText)
                    else if (liveStore.unknownCount > 0)
                      bits.push("unknown " + liveStore.unknownListText)
                    else
                      bits.push("local workstation checks")
                    return bits.join(" · ")
                  }
                  textFormat: Text.PlainText
                  color: root.contentForeground
                  opacity: 0.45
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
              }
            }
          }

          // Faint section divider
          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
          }

          // Enabled check rows only (inline CheckRowDelegate — no qmldir sibling type)
          Column {
            width: parent.width
            spacing: Style.space(8)

            Text {
              visible: !!(liveStore && liveStore.totalCount === 0)
              width: parent.width
              text: "All checks are Off — open Checks to enable any."
              color: root.contentForeground
              opacity: 0.4
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
            }

            Repeater {
              model: liveStore ? liveStore.enabledChecks : []
              delegate: CheckRowDelegate {
                width: parent.width
                check: modelData
                store: root.liveStore
                contentForeground: root.contentForeground
                dimForeground: root.dimForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
              }
            }
          }

          // Footer actions
          Row {
            width: parent.width
            spacing: Style.space(8)

            Rectangle {
              width: summaryBtnLabel.implicitWidth + Style.space(14)
              height: Style.space(28)
              radius: 6
              color: summaryMa.containsMouse
                ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                : root.surfaceColor
              border.width: 1
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

              Text {
                id: summaryBtnLabel
                anchors.centerIn: parent
                text: "Copy summary"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: summaryMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (liveStore) liveStore.copySummary()
              }
            }

            Text {
              visible: !!(liveStore && liveStore.toastText)
              text: liveStore ? liveStore.toastText : ""
              textFormat: Text.PlainText
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Meta + quieter unofficial line
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              width: parent.width
              visible: !!(liveStore && liveStore.meta && liveStore.meta.osPretty)
              text: {
                if (!liveStore || !liveStore.meta) return ""
                var m = liveStore.meta
                return (m.hostname || "") + " · " + (m.osPretty || "") + " · " + (m.kernel || "")
              }
              textFormat: Text.PlainText
              color: root.contentForeground
              opacity: 0.35
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: "Unofficial · not Drata or Vanta · Unknown ≠ fail"
              color: root.contentForeground
              opacity: 0.22
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }

  // Inlined from CheckRow.qml so Panel has zero dependency on qmldir sibling types
  // under Loader (matches structural safety of a single Panel file).
  component CheckRowDelegate : Item {
    id: rowRoot

    property var check: null
    property var store: null
    property color contentForeground: Color.foreground
    property color dimForeground: Qt.darker(contentForeground, 1.45)
    property color surfaceColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.06)
    property string fontFamily: "monospace"

    readonly property string code: check ? String(check.code || "") : ""
    readonly property string label: check ? String(check.label || "") : ""
    readonly property string status: check ? String(check.status || "unknown").toLowerCase() : "unknown"
    readonly property string detail: check ? String(check.detail || "") : ""
    readonly property bool hasFix: !!(check && check.fixCommand && String(check.fixCommand).length)
    readonly property bool hasConfig: !!(check && check.configPath && String(check.configPath).length)
    readonly property bool showActions: status === "fail" || status === "unknown"
    readonly property bool isScreenLock: code === "SL"

    // Per-check FA/Nerd glyph (tintable via Text.color, like bar lock \uf023)
    readonly property string statusGlyph: {
      if (code === "HD") return "\uf0a0"   // hdd
      if (code === "SL") return "\uf023"   // lock
      if (code === "AV") return "\uf132"   // shield
      if (code === "PW") return "\uf084"   // key
      if (code === "AU") return "\uf021"   // sync/refresh
      return "\uf128"                     // question
    }

    readonly property color statusColor: {
      if (status === "pass") return Color.accent
      if (status === "fail") return Color.urgent
      return Qt.rgba(1.0, 0.82, 0.48, 1.0)
    }

    readonly property color statusWell: {
      if (status === "pass")
        return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
      if (status === "fail")
        return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.22)
      return Qt.rgba(1.0, 0.82, 0.48, 0.16)
    }

    implicitHeight: card.implicitHeight
    implicitWidth: parent ? parent.width : 320

    Rectangle {
      id: card
      width: parent.width
      implicitHeight: col.implicitHeight + Style.space(16)
      radius: Math.max(6, Style.cornerRadius - 2)
      color: rowRoot.surfaceColor
      border.width: 1
      border.color: Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.08)

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: rowRoot.statusGlyph
            color: rowRoot.statusColor
            font.family: rowRoot.fontFamily
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(14) - statusBadge.width - Style.space(20)
            spacing: 2

            Text {
              width: parent.width
              text: rowRoot.label
              textFormat: Text.PlainText
              color: rowRoot.contentForeground
              font.family: rowRoot.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: rowRoot.detail
              textFormat: Text.PlainText
              color: rowRoot.contentForeground
              opacity: 0.45
              font.family: rowRoot.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
            }
          }

          Rectangle {
            id: statusBadge
            anchors.verticalCenter: parent.verticalCenter
            width: statusLabel.implicitWidth + Style.space(12)
            height: Style.space(22)
            radius: Math.max(4, Style.cornerRadius - 4)
            color: rowRoot.statusWell

            Text {
              id: statusLabel
              anchors.centerIn: parent
              text: rowRoot.status.toUpperCase()
              textFormat: Text.PlainText
              color: rowRoot.statusColor
              font.family: rowRoot.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.5
            }
          }
        }

        Rectangle {
          visible: rowRoot.showActions && (rowRoot.hasFix || (rowRoot.isScreenLock && rowRoot.hasConfig))
          width: parent.width
          height: 1
          color: Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.08)
        }

        Row {
          visible: rowRoot.showActions && (rowRoot.hasFix || (rowRoot.isScreenLock && rowRoot.hasConfig))
          spacing: Style.space(8)
          leftPadding: Style.space(14) + Style.space(10)

          Rectangle {
            visible: rowRoot.hasFix
            width: copyFixLabel.implicitWidth + Style.space(14)
            height: Style.space(24)
            radius: 6
            color: copyFixMa.containsMouse
              ? Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.12)
              : Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.12)

            Text {
              id: copyFixLabel
              anchors.centerIn: parent
              text: "Copy fix"
              color: rowRoot.contentForeground
              font.family: rowRoot.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: copyFixMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (rowRoot.store) rowRoot.store.copyFix(rowRoot.check)
            }
          }

          Rectangle {
            visible: rowRoot.isScreenLock && rowRoot.hasConfig
            width: openCfgLabel.implicitWidth + Style.space(14)
            height: Style.space(24)
            radius: 6
            color: openCfgMa.containsMouse
              ? Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.12)
              : Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(rowRoot.contentForeground.r, rowRoot.contentForeground.g, rowRoot.contentForeground.b, 0.12)

            Text {
              id: openCfgLabel
              anchors.centerIn: parent
              text: "Open config"
              color: rowRoot.contentForeground
              font.family: rowRoot.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: openCfgMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (rowRoot.store) rowRoot.store.openConfig(rowRoot.check)
            }
          }
        }
      }
    }
  }
}

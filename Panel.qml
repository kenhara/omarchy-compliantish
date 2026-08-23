import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Nested details panel for Security Theater (loaded by BarWidget — not a separate kind).
Panel {
  id: root
  moduleName: "harris.security-theater"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var store: null
  property bool checksMenuOpen: false

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
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

  implicitWidth: Style.space(390)
  implicitHeight: Math.min(Style.space(720), contentCol.implicitHeight + Style.space(36))

  Rectangle {
    anchors.fill: parent
    color: root.themeBackground
    radius: Style.space(12)

    Column {
      id: contentCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(16)
      spacing: Style.space(14)
      opacity: liveStore && liveStore.loading ? 0.72 : 1.0

      Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      // Header — title + Checks + Refresh
      Row {
        width: parent.width
        spacing: Style.space(8)

        Column {
          width: parent.width - checksBtn.width - refreshBtn.width - Style.space(16)
          spacing: Style.space(4)

          Text {
            text: "SECURITY THEATER"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.size(13)
            font.bold: true
            font.letterSpacing: 2.4
          }

          Text {
            text: {
              if (!liveStore) return "no store"
              var s = "refreshed " + (liveStore.lastUpdatedText || "—")
              if (liveStore.loading) s = "probing…"
              else if (liveStore.lastError) s = liveStore.lastError
              return s
            }
            color: root.contentForeground
            opacity: 0.45
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.size(11)
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Rectangle {
          id: checksBtn
          width: checksLabel.implicitWidth + Style.space(14)
          height: Style.space(26)
          radius: 6
          color: root.checksMenuOpen
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
            font.pixelSize: Style.font.size(11)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.checksMenuOpen = !root.checksMenuOpen
          }
        }

        Rectangle {
          id: refreshBtn
          width: refreshLabel.implicitWidth + Style.space(14)
          height: Style.space(26)
          radius: 6
          color: root.surfaceColor
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Text {
            id: refreshLabel
            anchors.centerIn: parent
            text: liveStore && liveStore.loading ? "…" : "Refresh"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.size(11)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (liveStore) liveStore.refresh()
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
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: "Enable or disable each check"
            color: root.contentForeground
            opacity: 0.55
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.size(10)
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
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.size(12)
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: root.checkEnabledFor(modelData.code) ? "On — shown in checklist" : "Off — hidden from checklist"
                  color: root.contentForeground
                  opacity: 0.4
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.size(10)
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
            font.pixelSize: Style.font.size(9)
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
            font.pixelSize: Style.font.size(16)
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
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.size(12)
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
              color: root.contentForeground
              opacity: 0.45
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.size(10)
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

      // Enabled check rows only
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
          font.pixelSize: Style.font.size(11)
          wrapMode: Text.Wrap
        }

        Repeater {
          model: liveStore ? liveStore.enabledChecks : []
          delegate: CheckRow {
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
          color: root.surfaceColor
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Text {
            id: summaryBtnLabel
            anchors.centerIn: parent
            text: "Copy summary"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.size(11)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (liveStore) liveStore.copySummary()
          }
        }

        Text {
          visible: !!(liveStore && liveStore.toastText)
          text: liveStore ? liveStore.toastText : ""
          color: Color.accent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.size(11)
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
          color: root.contentForeground
          opacity: 0.35
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.size(10)
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: "Unofficial · not affiliated with Drata or Vanta · Unknown ≠ fail"
          color: root.contentForeground
          opacity: 0.22
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.size(10)
          wrapMode: Text.Wrap
        }
      }
    }
  }
}

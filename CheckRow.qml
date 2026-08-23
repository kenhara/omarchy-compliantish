import QtQuick
import qs.Commons
import qs.Ui

// One workstation check row + Tier A actions (pointer only on buttons).
Item {
  id: root

  property var check: null
  property var store: null
  property color contentForeground: Color.foreground
  property color dimForeground: Qt.darker(contentForeground, 1.45)
  property color surfaceColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.06)
  property string fontFamily: Style.font.family

  readonly property string code: check ? String(check.code || "") : ""
  readonly property string label: check ? String(check.label || "") : ""
  readonly property string status: check ? String(check.status || "unknown").toLowerCase() : "unknown"
  readonly property string detail: check ? String(check.detail || "") : ""
  readonly property bool hasFix: !!(check && check.fixCommand && String(check.fixCommand).length)
  readonly property bool hasConfig: !!(check && check.configPath && String(check.configPath).length)
  readonly property bool showActions: status === "fail" || status === "unknown"
  readonly property bool isScreenLock: code === "SL"

  // pass=accent, fail=urgent, unknown=muted amber
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
    color: root.surfaceColor
    border.width: 1
    border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

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

        // Status dot — ● (U+25CF), tinted by status
        Text {
          text: "●"
          color: root.statusColor
          font.pixelSize: Style.font.size(11)
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(14) - statusBadge.width - Style.space(20)
          spacing: 2

          Text {
            width: parent.width
            text: root.label
            color: root.contentForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.size(12)
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.detail
            color: root.contentForeground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.size(11)
            wrapMode: Text.Wrap
          }
        }

        Rectangle {
          id: statusBadge
          anchors.verticalCenter: parent.verticalCenter
          width: statusLabel.implicitWidth + Style.space(12)
          height: Style.space(22)
          radius: Math.max(4, Style.cornerRadius - 4)
          color: root.statusWell

          Text {
            id: statusLabel
            anchors.centerIn: parent
            text: root.status.toUpperCase()
            color: root.statusColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.size(10)
            font.bold: true
            font.letterSpacing: 0.5
          }
        }
      }

      // Faint divider before Tier A actions
      Rectangle {
        visible: root.showActions && (root.hasFix || (root.isScreenLock && root.hasConfig))
        width: parent.width
        height: 1
        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
      }

      Row {
        visible: root.showActions && (root.hasFix || (root.isScreenLock && root.hasConfig))
        spacing: Style.space(8)
        leftPadding: Style.space(14) + Style.space(10)

        Rectangle {
          visible: root.hasFix
          width: copyFixLabel.implicitWidth + Style.space(14)
          height: Style.space(24)
          radius: 6
          color: copyFixMa.containsMouse
            ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
            : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Text {
            id: copyFixLabel
            anchors.centerIn: parent
            text: "Copy fix"
            color: root.contentForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.size(11)
          }

          MouseArea {
            id: copyFixMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.store) root.store.copyFix(root.check)
          }
        }

        Rectangle {
          visible: root.isScreenLock && root.hasConfig
          width: openCfgLabel.implicitWidth + Style.space(14)
          height: Style.space(24)
          radius: 6
          color: openCfgMa.containsMouse
            ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
            : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Text {
            id: openCfgLabel
            anchors.centerIn: parent
            text: "Open config"
            color: root.contentForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.size(11)
          }

          MouseArea {
            id: openCfgMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.store) root.store.openConfig(root.check)
          }
        }
      }
    }
  }
}

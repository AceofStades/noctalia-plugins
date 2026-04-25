import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
  id: bottomBar

  property bool expanded: false
  property bool hideHelp: true
  required property real shearFactor

  color: Color.mSurface
  height: shortcutRow.height + Style.marginM
  radius: Style.radiusS
  width: expanded ? shortcutRow.width + Style.margin2L : !hideHelp ? collapsedRow.width + Style.margin2L : 0

  transform: Matrix4x4 {
    property real s: bottomBar.shearFactor

    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
  }

  // TODO
  Behavior on width {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  Row {
    id: collapsedRow

    anchors.centerIn: parent
    spacing: Style.marginS
    visible: !bottomBar.expanded && !bottomBar.hideHelp

    ShortcutHint {
      keys: "?"
      label: "Shortcuts"
    }
  }
  Row {
    id: shortcutRow

    anchors.centerIn: parent
    spacing: Style.marginL
    visible: bottomBar.expanded

    ShortcutHint {
      keys: "J / K"
      label: "Navigate"
    }
    ShortcutHint {
      keys: "H / L"
      label: "Jump"
    }
    ShortcutHint {
      keys: "T"
      label: "Top Bar"
    }
    ShortcutHint {
      keys: "Enter"
      label: "Apply"
    }
    ShortcutHint {
      keys: "ESC"
      label: "Quit"
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.6
      width: 1
    }
    ShortcutHint {
      keys: "SHIFT / H + L"
      label: "Center Height"
    }
    ShortcutHint {
      keys: "SHIFT / J + K"
      label: "Center Width"
    }
    ShortcutHint {
      keys: "SHIFT / N + P"
      label: "Cards Shown"
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.6
      width: 1
    }
    ShortcutHint {
      keys: "CTRL / J + K"
      label: "Spacing"
    }
    ShortcutHint {
      keys: "CTRL / H + L"
      label: "Cards Width"
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.6
      width: 1
    }
    ShortcutHint {
      keys: "CTRL / S"
      label: "Save"
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.6
      width: 1
    }
    ShortcutHint {
      keys: "?"
      label: "Hide"
    }
  }
}

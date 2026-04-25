import qs.Commons
import qs.Widgets

import QtQuick

Rectangle {
  id: topBar

  required property int animationDuration
  required property int currentIndex
  property real entryOffset: parent.width / 2
  required property int filteredCount
  required property bool livePreview
  required property var pluginApi
  required property string selectedFilter
  required property real shearFactor

  signal filterSelected(string key)
  signal livePreviewToggled
  signal shuffleRequested

  function flashShuffle() {
    shuffleBtn.flash();
  }

  color: Color.mSurface

  Behavior on entryOffset {
    NumberAnimation {
      duration: topBar.animationDuration
      easing.overshoot: 1.0
      easing.type: Easing.OutBack
    }
  }

  transform: Matrix4x4 {
    property real s: topBar.shearFactor

    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
  }

  Component.onCompleted: entryOffset = 0

  // Left
  NText {
    anchors.left: parent.left
    anchors.leftMargin: Style.marginL
    anchors.verticalCenter: parent.verticalCenter
    text: (topBar.currentIndex + 1) + " / " + topBar.filteredCount
  }

  // Center
  Row {
    anchors.centerIn: parent
    spacing: Style.marginXXXS

    Repeater {
      model: [
        {
          key: "all",
          label: "All",
          icon: "wallpaper",
          hotkey: "A"
        },
        {
          key: "images",
          label: "Images",
          icon: "image",
          hotkey: "I"
        },
        {
          key: "videos",
          label: "Videos",
          icon: "video",
          hotkey: "V"
        }
      ]

      TopBarButton {
        required property var modelData

        active: topBar.selectedFilter === modelData.key
        hotkey: modelData.hotkey
        icon: modelData.icon
        label: modelData.label

        onClicked: topBar.filterSelected(modelData.key)
      }
    }
  }

  // Right
  Row {
    anchors.right: parent.right
    anchors.rightMargin: Style.marginL
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.marginXS

    TopBarButton {
      id: shuffleBtn

      function flash() {
        shuffleAnim.restart();
      }

      hotkey: "R"
      icon: "arrows-random"
      label: "Shuffle"
      scale: 1.0

      onClicked: {
        topBar.shuffleRequested();
        shuffleBtn.flash();
      }

      Rectangle {
        id: flashOverlay

        anchors.fill: parent
        color: Color.mPrimary
        opacity: 0
        radius: parent.radius
      }

      SequentialAnimation {
        id: shuffleAnim

        NumberAnimation {
          duration: 80
          easing.type: Easing.OutCubic
          property: "opacity"
          target: flashOverlay
          to: 0.3
        }

        NumberAnimation {
          duration: 300
          easing.type: Easing.OutCubic
          property: "opacity"
          target: flashOverlay
          to: 0
        }
      }
    }

    TopBarButton {
      accentColor: topBar.livePreview ? Color.mTertiary : Color.mOnSurfaceVariant
      active: topBar.livePreview
      hotkey: "P"
      label: topBar.pluginApi?.tr("buttons.live-preview")
      pulsing: topBar.livePreview

      onClicked: topBar.livePreviewToggled()
    }
  }
}

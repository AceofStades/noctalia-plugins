import qs.Commons
import qs.Widgets

import QtQuick

Rectangle {
  id: topBar

  required property int animationDuration
  required property var availableColors
  required property var colorOrder
  required property var colorOrderColors
  required property string currentCardColor
  required property int currentIndex
  property real entryOffset: parent.width / 2
  required property int filteredCount
  required property bool livePreview
  required property var pluginApi
  required property string selectedColorFilter
  required property string selectedFilter
  required property real shearFactor

  signal colorFilterSelected(string key)
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
    spacing: Style.marginXS

    Repeater {
      model: [
        {
          key: "all",
          label: topBar.pluginApi?.tr("buttons.all"),
          icon: "wallpaper",
          hotkey: "A"
        },
        {
          key: "images",
          label: topBar.pluginApi?.tr("buttons.images"),
          icon: "image",
          hotkey: "I"
        },
        {
          key: "videos",
          label: topBar.pluginApi?.tr("buttons.videos"),
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

    // Separator
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.5
      width: 1
    }

    Repeater {
      model: topBar.colorOrder

      Rectangle {
        required property int index
        required property string modelData

        property bool active: topBar.selectedColorFilter === modelData
        property bool available: topBar.availableColors.indexOf(modelData) !== -1
        property bool current: topBar.selectedColorFilter === "" && topBar.currentCardColor === modelData

        anchors.verticalCenter: parent.verticalCenter
        border.color: active ? Color.mOnSurface : Qt.alpha(Color.mOutline, 0.3)
        border.width: Style.borderS
        color: topBar.colorOrderColors[index]
        height: Style.margin2L
        opacity: active ? 1.0 : available ? 0.4 : 0.12
        radius: Style.radiusM
        width: height

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animationFast
          }
        }
        Behavior on border.color {
          ColorAnimation {
            duration: Style.animationFast
          }
        }

        // Current card indicator
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: -height - 2
          anchors.horizontalCenter: parent.horizontalCenter
          color: parent.current ? topBar.colorOrderColors[parent.index] : "transparent"
          height: 3
          radius: height / 2
          width: parent.current ? parent.width * 0.6 : 0

          Behavior on width {
            NumberAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }

        // Unavailable indicator
        NText {
          anchors.centerIn: parent
          color: Color.mOnSurface
          font.bold: true
          font.pointSize: Style.fontSizeS
          text: topBar.pluginApi?.tr("buttons.color-na")
          visible: !parent.available
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
          enabled: parent.available

          onClicked: {
            if (parent.active)
              topBar.colorFilterSelected("");
            else
              topBar.colorFilterSelected(parent.modelData);
          }
        }
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
      label: topBar.pluginApi?.tr("buttons.shuffle")
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

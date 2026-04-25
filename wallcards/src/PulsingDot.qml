import qs.Commons
import QtQuick

Rectangle {
  id: root

  property color dotColor: Color.mError
  property bool pulsing: false

  color: dotColor
  height: Style.marginS
  radius: Style.marginXXXS
  width: Style.marginS

  SequentialAnimation {
    id: pulseAnimation

    loops: Animation.Infinite
    running: root.pulsing

    onRunningChanged: {
      if (!running)
        root.opacity = 1.0;
    }

    NumberAnimation {
      duration: 800
      easing.type: Easing.InOutSine
      from: 1.0
      property: "opacity"
      target: root
      to: 0.3
    }
    NumberAnimation {
      duration: 800
      easing.type: Easing.InOutSine
      from: 0.3
      property: "opacity"
      target: root
      to: 1.0
    }
  }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  width: 300 * Style.uiScaleRatio
  height: 400 * Style.uiScaleRatio

  property var currentTasks: pluginApi?.mainInstance?.currentTasks || []

  NBox {
    anchors.fill: parent
    padding: Style.marginM
    color: Color.mSurface

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        
        NIcon {
          icon: "check-all"
          color: Color.mPrimary
        }
        
        NText {
          text: pluginApi?.tr("widget.tasks_today") || "Tasks"
          font.bold: true
          Layout.fillWidth: true
        }

        NText {
          text: root.currentTasks.length.toString()
          color: Color.mOnSurfaceVariant
        }
      }

      NDivider { Layout.fillWidth: true }

      ListView {
        id: taskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.marginS
        model: root.currentTasks

        delegate: RowLayout {
          width: taskListView.width
          spacing: Style.marginS

          NIcon {
            icon: modelData.status === "completed" ? "check-circle" : "circle-outline"
            color: modelData.status === "completed" ? Color.mSuccess : Color.mOnSurfaceVariant
            Layout.preferredWidth: Style.iconSizeS
            Layout.preferredHeight: Style.iconSizeS
          }

          NText {
            Layout.fillWidth: true
            text: modelData.title || ""
            color: modelData.status === "completed" ? Color.mOnSurfaceVariant : Color.mOnSurface
            font.strikeout: modelData.status === "completed"
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}

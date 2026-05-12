import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 400 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  property var taskLists: pluginApi?.mainInstance?.taskLists || []
  property var currentTasks: pluginApi?.mainInstance?.currentTasks || []
  property string currentListId: pluginApi?.mainInstance?.currentListId || ""

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      // Header: List Selection
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.title") || "Google Tasks"
          font.pointSize: Style.fontL
          font.bold: true
          Layout.fillWidth: true
        }

        NComboBox {
          Layout.fillWidth: true
          model: root.taskLists.map(list => list.title)
          currentIndex: {
            for (var i = 0; i < root.taskLists.length; i++) {
              if (root.taskLists[i].id === root.currentListId) return i;
            }
            return -1;
          }
          onActivated: index => {
            if (index >= 0 && index < root.taskLists.length) {
              if (pluginApi && pluginApi.mainInstance) {
                pluginApi.mainInstance.fetchTasks(root.taskLists[index].id);
              }
            }
          }
        }
      }

      NDivider { Layout.fillWidth: true }

      // Task List
      ListView {
        id: taskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.marginS
        model: root.currentTasks

        delegate: NBox {
          width: taskListView.width
          padding: Style.marginM
          color: Color.mSurfaceContainer
          
          ColumnLayout {
            anchors.fill: parent
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              
              NIconButton {
                icon: modelData.status === "completed" ? "check-circle" : "circle-outline"
                color: modelData.status === "completed" ? Color.mSuccess : Color.mOnSurfaceVariant
                onClicked: {
                   if (modelData.status !== "completed" && pluginApi && pluginApi.mainInstance) {
                     pluginApi.mainInstance.completeTask(modelData.id);
                   }
                }
              }

              NText {
                Layout.fillWidth: true
                text: modelData.title || ""
                color: modelData.status === "completed" ? Color.mOnSurfaceVariant : Color.mOnSurface
                font.strikeout: modelData.status === "completed"
                wrapMode: Text.Wrap
              }

              NIcon {
                icon: "calendar"
                visible: modelData.due !== undefined && modelData.due !== null && modelData.due !== ""
                color: Color.mPrimary
                Layout.preferredWidth: Style.iconSizeS
                Layout.preferredHeight: Style.iconSizeS
              }
            }

            NText {
              Layout.fillWidth: true
              Layout.leftMargin: Style.iconSizeM + Style.marginM
              text: modelData.notes || ""
              visible: text !== ""
              color: Color.mOnSurfaceVariant
              font.pixelSize: Style.fontSizeS
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }
}

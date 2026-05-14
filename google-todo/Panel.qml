import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 450 * Style.uiScaleRatio
  property real contentPreferredHeight: 600 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  property var taskLists: pluginApi?.mainInstance?.taskLists || []
  property var currentTasks: pluginApi?.mainInstance?.currentTasks || []
  property string currentListId: pluginApi?.mainInstance?.currentListId || ""
  property bool isLoggedIn: pluginApi?.mainInstance?.isLoggedIn ?? false

  property int currentTabIndex: 0 // 0 = Pending, 1 = Completed

  // Filter tasks based on tab
  property var filteredTasks: {
    if (!currentTasks) return [];
    return currentTasks.filter(t => currentTabIndex === 0 ? (t.status !== "completed") : (t.status === "completed"));
  }

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL
      visible: root.isLoggedIn

      // Header: List Selection
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.title") || "Google Tasks"
          font.pointSize: Style.fontSizeL
          font.bold: true
          Layout.fillWidth: true
        }

        NComboBox {
          Layout.fillWidth: true
          model: root.taskLists.map(list => ({ name: list.title, value: list.id }))
          currentKey: root.currentListId
          onSelected: key => {
            if (pluginApi && pluginApi.mainInstance) {
              pluginApi.mainInstance.fetchTasks(key);
            }
          }
        }
      }

      // Tabs
      NTabBar {
        Layout.fillWidth: true
        currentIndex: root.currentTabIndex
        
        NTabButton {
          text: pluginApi?.tr("panel.tab_pending") || "Pending"
          onClicked: root.currentTabIndex = 0
        }
        NTabButton {
          text: pluginApi?.tr("panel.tab_completed") || "Completed"
          onClicked: root.currentTabIndex = 1
        }
      }

      // Task List
      ListView {
        id: taskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.marginS
        model: root.filteredTasks

        delegate: Rectangle {
          width: taskListView.width - (modelData.parent ? (Style.marginL * 2) : 0)
          anchors.right: parent.right
          implicitHeight: taskLayout.implicitHeight + (Style.marginM * 2)
          color: Color.mSurface // Fixes dark/light mode issue
          radius: Style.radiusM
          border.color: Color.mOutlineVariant
          border.width: 1
          
          ColumnLayout {
            id: taskLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              
              NIconButton {
                icon: modelData.status === "completed" ? "clipboard-check" : "circle"
                color: modelData.status === "completed" ? Color.mPrimary : Color.mOnSurfaceVariant
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

              NText {
                text: modelData.due ? modelData.due.substring(0, 10) : ""
                visible: modelData.due !== undefined && modelData.due !== null && modelData.due !== ""
                color: Color.mPrimary
                font.pixelSize: Style.fontSizeS
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

      NDivider { Layout.fillWidth: true }

      // Add Task Area
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
          id: newTaskInput
          Layout.fillWidth: true
          placeholderText: pluginApi?.tr("panel.add_task_placeholder") || "Add a new task..."
          onAccepted: {
            if (text.trim() !== "" && pluginApi && pluginApi.mainInstance) {
              pluginApi.mainInstance.addTask(text.trim(), newTaskDueInput.text.trim() ? (newTaskDueInput.text.trim() + "T00:00:00.000Z") : "");
              text = "";
              newTaskDueInput.text = "";
            }
          }
        }

        NTextInput {
          id: newTaskDueInput
          Layout.preferredWidth: 120 * Style.uiScaleRatio
          placeholderText: "YYYY-MM-DD"
        }

        NButton {
          icon: "plus"
          onClicked: {
            if (newTaskInput.text.trim() !== "" && pluginApi && pluginApi.mainInstance) {
              pluginApi.mainInstance.addTask(newTaskInput.text.trim(), newTaskDueInput.text.trim() ? (newTaskDueInput.text.trim() + "T00:00:00.000Z") : "");
              newTaskInput.text = "";
              newTaskDueInput.text = "";
            }
          }
        }
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginM
      visible: !root.isLoggedIn

      NText {
        text: "G"
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignHCenter
        font.pointSize: Style.fontSizeXL
        font.bold: true
      }

      NText {
        text: pluginApi?.tr("settings.not_logged_in") || "Not logged in to Google Tasks"
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignHCenter
      }

      NButton {
        text: pluginApi?.tr("settings.login_button") || "Login with Google"
        Layout.alignment: Qt.AlignHCenter
        onClicked: {
          if (pluginApi && pluginApi.mainInstance) {
             pluginApi.mainInstance.triggerLogin();
          }
        }
      }
    }
  }
}

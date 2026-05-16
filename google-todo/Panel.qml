import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import Quickshell

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
  property string activeParentTaskId: "" // For adding subtasks

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
      anchors.margins: Style.marginM
      spacing: Style.marginM
      visible: root.isLoggedIn

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.5)
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // Header: List Selection
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "clipboard-check"
              baseSize: Style.fontSizeXL
            }

            NText {
              text: pluginApi?.tr("panel.title") || "Google Tasks"
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NComboBox {
              Layout.preferredWidth: 150 * Style.uiScaleRatio
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
            Layout.topMargin: Style.marginS
            distributeEvenly: true
            currentIndex: root.currentTabIndex
            
            NTabButton {
              text: pluginApi?.tr("panel.tab_pending") || "Pending"
              checked: root.currentTabIndex === 0
              onClicked: root.currentTabIndex = 0
              
              Component.onCompleted: {
                topLeftRadius = Style.iRadiusM;
                bottomLeftRadius = Style.iRadiusM;
                topRightRadius = Style.iRadiusM;
                bottomRightRadius = Style.iRadiusM;
              }
            }
            NTabButton {
              text: pluginApi?.tr("panel.tab_completed") || "Completed"
              checked: root.currentTabIndex === 1
              onClicked: root.currentTabIndex = 1

              Component.onCompleted: {
                topLeftRadius = Style.iRadiusM;
                bottomLeftRadius = Style.iRadiusM;
                topRightRadius = Style.iRadiusM;
                bottomRightRadius = Style.iRadiusM;
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Add Task Area
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS
              Layout.bottomMargin: Style.marginM

              NTextInput {
                id: newTaskInput
                Layout.fillWidth: true
                placeholderText: pluginApi?.tr("panel.add_task_placeholder") || "Add a new task..."
                onAccepted: addTask()
              }

              NTextInput {
                id: newTaskDueInput
                Layout.preferredWidth: 120 * Style.uiScaleRatio
                placeholderText: "YYYY-MM-DD"
              }

              NIconButton {
                icon: "plus"
                baseSize: Style.baseWidgetSize * 1.2
                customRadius: Style.iRadiusS
                onClicked: addTask()
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
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick

              delegate: Item {
                id: delegateItem
                width: ListView.view.width - (modelData.parent ? (Style.marginL * 2) : 0)
                anchors.right: parent.right
                height: taskLayout.implicitHeight + (Style.marginS * 2)

                Rectangle {
                  anchors.fill: parent
                  color: Color.mSurface 
                  radius: Style.radiusM
                  border.color: Color.mOutlineVariant
                  border.width: 1
                  
                  RowLayout {
                    id: taskLayout
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    spacing: Style.marginS

                    // Custom Checkbox like @todo
                    Item {
                      Layout.preferredWidth: Style.baseWidgetSize * 0.7
                      Layout.preferredHeight: Style.baseWidgetSize * 0.7
                      Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

                      Rectangle {
                        id: box
                        anchors.fill: parent
                        radius: Style.iRadiusXS
                        color: modelData.status === "completed" ? Color.mPrimary : Color.mSurface
                        border.color: Color.mOutline
                        border.width: Style.borderS

                        Behavior on color {
                          ColorAnimation { duration: Style.animationFast }
                        }

                        NIcon {
                          visible: modelData.status === "completed"
                          anchors.centerIn: parent
                          anchors.horizontalCenterOffset: -1
                          icon: "check"
                          color: Color.mOnPrimary
                          baseSize: Math.max(Style.fontSizeXS, Style.baseWidgetSize * 0.7 * 0.5)
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (modelData.status !== "completed" && pluginApi && pluginApi.mainInstance) {
                              pluginApi.mainInstance.completeTask(modelData.id);
                            }
                          }
                        }
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0

                      NText {
                        Layout.fillWidth: true
                        text: modelData.title || ""
                        color: modelData.status === "completed" ? Color.mOnSurfaceVariant : Color.mOnSurface
                        font.strikeout: modelData.status === "completed"
                        wrapMode: Text.Wrap
                      }
                      
                      NText {
                        Layout.fillWidth: true
                        text: modelData.notes || ""
                        visible: text !== ""
                        color: Color.mOnSurfaceVariant
                        font.pixelSize: Style.fontSizeS
                        wrapMode: Text.Wrap
                      }

                      RowLayout {
                        visible: modelData.due !== undefined && modelData.due !== null && modelData.due !== ""
                        spacing: 4
                        NIcon {
                          icon: "calendar"
                          color: Color.mPrimary
                          baseSize: Style.iconSizeS
                        }
                        NText {
                          text: modelData.due ? modelData.due.substring(0, 10) : ""
                          color: Color.mPrimary
                          font.pixelSize: Style.fontSizeS
                        }
                      }
                    }

                    // Hover Actions (Hamburger menu / 3 dots)
                    Item {
                      Layout.preferredWidth: actionsRow.implicitWidth
                      Layout.preferredHeight: parent.height

                      RowLayout {
                        id: actionsRow
                        anchors.centerIn: parent
                        spacing: 2
                        opacity: taskMouseArea.containsMouse ? 1.0 : 0.0

                        Behavior on opacity {
                          NumberAnimation { duration: 150 }
                        }

                        NIconButton {
                          icon: "clock"
                          tooltipText: "Add Deadline"
                          baseSize: Style.baseWidgetSize * 0.8
                          colorFg: Color.mOnSurfaceVariant
                          onClicked: {
                            deadlinePopup.taskId = modelData.id;
                            deadlinePopup.open();
                          }
                        }

                        NIconButton {
                          icon: "list-tree"
                          tooltipText: "Add Subtask"
                          baseSize: Style.baseWidgetSize * 0.8
                          colorFg: Color.mOnSurfaceVariant
                          onClicked: {
                            subtaskPopup.parentTaskId = modelData.id;
                            subtaskPopup.open();
                          }
                        }

                        NIconButton {
                          icon: "trash"
                          tooltipText: "Delete Task"
                          baseSize: Style.baseWidgetSize * 0.8
                          colorFg: Color.mError
                          onClicked: {
                             if (pluginApi && pluginApi.mainInstance) {
                               pluginApi.mainInstance.deleteTask(modelData.id);
                             }
                          }
                        }
                      }
                    }
                  }

                  MouseArea {
                    id: taskMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    // prevent stealing so it doesn't block the buttons
                    propagateComposedEvents: true
                    z: -1 
                  }
                }
              }
            }

            // Empty state overlay
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignCenter
              visible: root.filteredTodosModel.length === 0

              NText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -50
                text: pluginApi?.tr("panel.empty_state.message") || "No tasks here."
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeM
                font.weight: Font.Normal
              }
            }
          }
        }
      }
    }

    Popup {
      id: subtaskPopup
      property string parentTaskId: ""
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      width: 300 * Style.uiScaleRatio
      height: 150 * Style.uiScaleRatio
      modal: true
      focus: true
      padding: Style.marginM

      background: Rectangle {
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1
      }

      contentItem: ColumnLayout {
        spacing: Style.marginM

        NText {
          text: "Add Subtask"
          font.pointSize: Style.fontSizeM
          font.bold: true
        }

        NTextInput {
          id: subtaskInput
          Layout.fillWidth: true
          placeholderText: "Subtask title..."
          onAccepted: {
             if (subtaskPopup.parentTaskId !== "" && text.trim() !== "" && pluginApi && pluginApi.mainInstance) {
                pluginApi.mainInstance.addTask(text.trim(), "", subtaskPopup.parentTaskId);
                text = "";
             }
             subtaskPopup.close();
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          NButton {
             text: "Cancel"
             onClicked: subtaskPopup.close()
          }
          NButton {
             text: "Add"
             backgroundColor: Color.mPrimary
             textColor: Color.mOnPrimary
             onClicked: {
                 if (subtaskPopup.parentTaskId !== "" && subtaskInput.text.trim() !== "" && pluginApi && pluginApi.mainInstance) {
                    pluginApi.mainInstance.addTask(subtaskInput.text.trim(), "", subtaskPopup.parentTaskId);
                    subtaskInput.text = "";
                 }
                 subtaskPopup.close();
             }
          }
        }
      }
    }

    Popup {
      id: deadlinePopup
      property string taskId: ""
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      width: 300 * Style.uiScaleRatio
      height: 150 * Style.uiScaleRatio
      modal: true
      focus: true
      padding: Style.marginM

      background: Rectangle {
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1
      }

      contentItem: ColumnLayout {
        spacing: Style.marginM

        NText {
          text: "Set Deadline"
          font.pointSize: Style.fontSizeM
          font.bold: true
        }

        NTextInput {
          id: deadlineInput
          Layout.fillWidth: true
          placeholderText: "YYYY-MM-DD"
          onAccepted: {
             if (deadlinePopup.taskId !== "" && pluginApi && pluginApi.mainInstance) {
                var due = text.trim() ? (text.trim() + "T00:00:00.000Z") : "";
                pluginApi.mainInstance.updateTaskDue(deadlinePopup.taskId, due);
             }
             deadlinePopup.close();
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          NButton {
             text: "Cancel"
             onClicked: deadlinePopup.close()
          }
          NButton {
             text: "Save"
             backgroundColor: Color.mPrimary
             textColor: Color.mOnPrimary
             onClicked: {
                 if (deadlinePopup.taskId !== "" && pluginApi && pluginApi.mainInstance) {
                    var due = deadlineInput.text.trim() ? (deadlineInput.text.trim() + "T00:00:00.000Z") : "";
                    pluginApi.mainInstance.updateTaskDue(deadlinePopup.taskId, due);
                 }
                 deadlinePopup.close();
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

  function addTask() {
    if (newTaskInput.text.trim() !== "" && pluginApi && pluginApi.mainInstance) {
      pluginApi.mainInstance.addTask(newTaskInput.text.trim(), newTaskDueInput.text.trim() ? (newTaskDueInput.text.trim() + "T00:00:00.000Z") : "", "");
      newTaskInput.text = "";
      newTaskDueInput.text = "";
    }
  }
}
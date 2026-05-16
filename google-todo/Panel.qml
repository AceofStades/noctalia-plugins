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
              pointSize: Style.fontSizeXL
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
                Keys.onReturnPressed: addTask()
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
                          pointSize: Math.max(Style.fontSizeXS, Style.baseWidgetSize * 0.7 * 0.5)
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
                          Layout.preferredWidth: Style.iconSizeS
                          Layout.preferredHeight: Style.iconSizeS
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
                             // Will be implemented via detail dialog or input
                             ToastService.showNotice("Add Deadline clicked");
                          }
                        }

                        NIconButton {
                          icon: "list-tree"
                          tooltipText: "Add Subtask"
                          baseSize: Style.baseWidgetSize * 0.8
                          colorFg: Color.mOnSurfaceVariant
                          onClicked: {
                             ToastService.showNotice("Add Subtask clicked");
                          }
                        }

                        NIconButton {
                          icon: "trash"
                          tooltipText: "Delete Task"
                          baseSize: Style.baseWidgetSize * 0.8
                          colorFg: Color.mError
                          onClicked: {
                             ToastService.showNotice("Delete clicked (Requires backend implementation)");
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
      pluginApi.mainInstance.addTask(newTaskInput.text.trim(), "");
      newTaskInput.text = "";
    }
  }
}

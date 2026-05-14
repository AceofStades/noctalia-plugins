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
  property bool isLoggedIn: pluginApi?.mainInstance?.isLoggedIn ?? false

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

      NDivider { Layout.fillWidth: true }

      // Task List
      ListView {
        id: taskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.marginS
        model: root.currentTasks

        delegate: Rectangle {
          width: taskListView.width
          implicitHeight: taskLayout.implicitHeight + (Style.marginM * 2)
          color: Color.mSurfaceContainer
          radius: Style.radiusL
          
          ColumnLayout {
            id: taskLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              
              NIconButton {
                icon: modelData.status === "completed" ? "clipboard-check" : "circle-outline"
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
        icon: "google"
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
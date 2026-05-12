import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property int editSyncInterval: cfg.syncInterval ?? defaults.syncInterval ?? 300
  property bool editShowCompleted: cfg.showCompleted ?? defaults.showCompleted ?? true
  property bool editAutoStartSync: cfg.autoStartSync ?? defaults.autoStartSync ?? false

  spacing: Style.marginL

  NBox {
    Layout.fillWidth: true
    padding: Style.marginL

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.account") || "Account"
        font.bold: true
      }

      NText {
        text: pluginApi?.mainInstance?.isLoggedIn ? (pluginApi?.tr("settings.logged_in") || "Logged in to Google Tasks") : (pluginApi?.tr("settings.not_logged_in") || "Not logged in")
        color: pluginApi?.mainInstance?.isLoggedIn ? Color.mSuccess : Color.mError
      }

      NButton {
        text: pluginApi?.tr("settings.login_button") || "Login with Google"
        icon: "google"
        visible: !pluginApi?.mainInstance?.isLoggedIn
        onClicked: {
          loginProcess.running = true;
        }
      }
      
      NButton {
        text: pluginApi?.tr("settings.refresh_lists") || "Refresh Lists"
        icon: "refresh"
        visible: pluginApi?.mainInstance?.isLoggedIn
        onClicked: {
          if (pluginApi && pluginApi.mainInstance) {
            pluginApi.mainInstance.fetchLists();
          }
        }
      }
    }
  }

  NDivider { Layout.fillWidth: true }

  NSpinBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.sync_interval.label") || "Sync Interval (seconds)"
    description: pluginApi?.tr("settings.sync_interval.desc") || "How often to automatically sync tasks"
    value: root.editSyncInterval
    from: 60
    to: 3600
    onValueChanged: root.editSyncInterval = value
  }

  NSwitch {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.auto_sync.label") || "Auto-start Sync"
    description: pluginApi?.tr("settings.auto_sync.desc") || "Start sync timer automatically"
    checked: root.editAutoStartSync
    onCheckedChanged: root.editAutoStartSync = checked
  }

  NSwitch {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show_completed.label") || "Show Completed Tasks"
    checked: root.editShowCompleted
    onCheckedChanged: root.editShowCompleted = checked
  }

  // Process to run login
  Process {
    id: loginProcess
    property string buffer: ""
    command: pluginApi ? [pluginApi.pluginDir + "/google-todo-sync", "login"] : []
    running: false
    onStdout: function(data) {
      if (data) buffer += data;
    }
    onExited: function(code) {
      if (code === 0 && buffer.length > 0) {
        try {
          var response = JSON.parse(buffer);
          if (response.success) {
            if (pluginApi && pluginApi.mainInstance) {
               pluginApi.mainInstance.fetchLists();
            }
          } else if (response.error) {
            Logger.e("Google Todo Login Error: " + response.error);
          }
        } catch(e) {
          Logger.e("Google Todo Login Parse Error: " + e);
        }
      }
      buffer = "";
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.syncInterval = root.editSyncInterval;
    pluginApi.pluginSettings.showCompleted = root.editShowCompleted;
    pluginApi.pluginSettings.autoStartSync = root.editAutoStartSync;
    pluginApi.saveSettings();
  }
}

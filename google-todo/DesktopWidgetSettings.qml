import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  spacing: Style.marginL

  NBox {
    Layout.fillWidth: true
    padding: Style.marginL

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("widget.desktop_settings_desc") || "Desktop widget settings. For more settings, right-click the bar widget or open plugin settings."
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }
      
      NButton {
        text: pluginApi?.tr("menu.settings") || "Open Full Settings"
        icon: "settings"
        onClicked: {
          if (pluginApi) {
            pluginApi.withCurrentScreen(screen => {
              if (screen) {
                // Call full settings from desktop widget settings
                qs.Services.UI.BarService.openPluginSettings(screen, pluginApi.manifest);
              }
            });
          }
        }
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.saveSettings();
  }
}

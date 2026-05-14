import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  property var taskLists: []
  property var currentTasks: []
  property string currentListId: ""
  property bool isLoggedIn: false
  property bool isSyncing: false

  // Settings
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property int syncInterval: cfg.syncInterval ?? defaults.syncInterval ?? 300
  property bool _initialized: false

  // Timer for periodic sync
  Timer {
    id: syncTimer
    interval: syncInterval * 1000
    repeat: true
    running: cfg.autoStartSync ?? defaults.autoStartSync ?? false
    onTriggered: {
      if (isLoggedIn && currentListId !== "") {
        fetchTasksProcess.buffer = "";
        fetchTasksProcess.listId = currentListId;
        fetchTasksProcess.running = true;
      }
    }
  }

  function runCommand() {
    if (!pluginApi) return "";
    return pluginApi.pluginDir + "/google-todo-sync";
  }

  // Fetch lists
  Process {
    id: fetchListsProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string buffer: ""
    command: [root.runCommand(), "get-lists"]
    running: false
    onExited: function(code) {
      buffer = String(fetchListsProcess.stdout.text || "").trim();
      if (code === 0 && buffer.length > 0) {
        try {
          var response = JSON.parse(buffer);
          if (response.error) {
            if (response.error === "Not logged in") {
              isLoggedIn = false;
            } else {
              Logger.e("Google Todo: Error fetching lists: " + response.error);
            }
          } else if (response.items) {
            isLoggedIn = true;
            taskLists = response.items;
            if (taskLists.length > 0 && currentListId === "") {
              currentListId = taskLists[0].id;
              fetchTasksProcess.buffer = "";
              fetchTasksProcess.listId = currentListId;
              fetchTasksProcess.running = true;
            }
          }
        } catch (e) {
          Logger.e("Google Todo: Parse error lists: " + e);
        }
      }
      buffer = "";
    }
  }

  // Fetch tasks
  Process {
    id: fetchTasksProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string buffer: ""
    property string listId: ""
    command: [root.runCommand(), "get-tasks", "--list-id", listId]
    running: false
    onExited: function(code) {
      buffer = String(fetchTasksProcess.stdout.text || "").trim();
      if (code === 0 && buffer.length > 0) {
        try {
          var response = JSON.parse(buffer);
          if (!response.error) {
            if (response.items) {
              currentTasks = response.items;
            } else {
              currentTasks = [];
            }
          }
        } catch (e) {
          Logger.e("Google Todo: Parse error tasks: " + e);
        }
      }
      buffer = "";
    }
  }

  // Complete a task
  Process {
    id: completeTaskProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string listId: ""
    property string taskId: ""
    command: [root.runCommand(), "complete-task", "--list-id", listId, "--task-id", taskId]
    running: false
    onExited: function(code) {
      if (code === 0) {
        fetchTasksProcess.buffer = "";
        fetchTasksProcess.running = true; // refresh after completion
      }
    }
  }

  // IPC Handlers
  IpcHandler {
    target: "plugin:google-todo"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }
  }

  function triggerLogin() {
    loginProcess.buffer = "";
    loginProcess.running = true;
  }

  function completeTask(taskId) {
    if (currentListId !== "") {
      completeTaskProcess.listId = currentListId;
      completeTaskProcess.taskId = taskId;
      completeTaskProcess.running = true;
    }
  }

  function fetchLists() {
    fetchListsProcess.buffer = "";
    fetchListsProcess.running = true;
  }

  function fetchTasks(listId) {
    if (listId !== "") {
      currentListId = listId;
      fetchTasksProcess.buffer = "";
      fetchTasksProcess.listId = listId;
      fetchTasksProcess.running = true;
    }
  }

  onPluginApiChanged: {
    if (pluginApi && !_initialized) {
      _initialized = true;
      if (pluginApi.pluginSettings && !pluginApi.pluginSettings.addedToBar) {
        try {
          pluginApi.withCurrentScreen(screen => {
            if (screen && screen.name) {
              var screenName = screen.name;
              var widgetId = "plugin:" + pluginApi.pluginId;
              var currentWidgets = Settings.getBarWidgetsForScreen(screenName) || {};
              var widgets = {
                "left": JSON.parse(JSON.stringify(currentWidgets.left || [])),
                "center": JSON.parse(JSON.stringify(currentWidgets.center || [])),
                "right": JSON.parse(JSON.stringify(currentWidgets.right || []))
              };
              
              var found = false;
              var sections = ["left", "center", "right"];
              for (var s = 0; s < sections.length; s++) {
                var arr = widgets[sections[s]];
                for (var i = 0; i < arr.length; i++) {
                  if (arr[i] && arr[i].id === widgetId) found = true;
                }
              }

              if (!found) {
                widgets["right"].push({ "id": widgetId });
                Settings.setScreenOverride(screenName, "widgets", widgets);
                BarService.widgetsRevision++;
              }
            }
          });
        } catch (e) {
          Logger.w("GoogleTodo", "Failed to auto-add widget to bar:", e);
        }
        
        pluginApi.pluginSettings.addedToBar = true;
        pluginApi.saveSettings();
      }

      // Initial fetch to check login status and get lists
      fetchListsProcess.running = true;
    }
  }

  Component.onCompleted: {
    // Moved logic to onPluginApiChanged since pluginApi is null during onCompleted
  }
}

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

  // Process to run login
  Process {
    id: loginProcess
    command: [root.runCommand(), "login"]
    running: false
    stdout: StdioCollector {
      id: loginStdout
    }
    onExited: function(code) {
      if (code === 0) {
        var strData = String(loginStdout.text || "").trim();
        var lines = strData.split('\n');
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line.startsWith('{')) {
            try {
              var response = JSON.parse(line);
              if (response.success) {
                root.fetchLists();
              } else if (response.error) {
                Logger.e("Google Todo Login Error: " + response.error);
              }
            } catch(e) {
              // Ignore partial JSON parses
            }
          }
        }
      }
    }
  }

  // Add a task
  Process {
    id: addTaskProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string buffer: ""
    property string listId: ""
    property string title: ""
    property string due: ""
    property string parent: ""
    
    // Using a dynamic command array to safely pass empty args if needed
    command: (function() {
      var args = [root.runCommand(), "add-task", "--list-id", listId, "--title", title];
      if (due !== "") {
        args.push("--due");
        args.push(due);
      }
      if (parent !== "") {
        args.push("--parent");
        args.push(parent);
      }
      return args;
    })()
    running: false
    onExited: function(code) {
      if (code === 0) {
        fetchTasksProcess.buffer = "";
        fetchTasksProcess.running = true; // refresh
      }
    }
  }

  // Delete a task
  Process {
    id: deleteTaskProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string listId: ""
    property string taskId: ""
    command: [root.runCommand(), "delete-task", "--list-id", listId, "--task-id", taskId]
    running: false
    onExited: function(code) {
      if (code === 0) {
        fetchTasksProcess.buffer = "";
        fetchTasksProcess.running = true; // refresh after deletion
      }
    }
  }

  // Update a task (deadline)
  Process {
    id: updateTaskProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    property string listId: ""
    property string taskId: ""
    property string due: ""
    command: [root.runCommand(), "update-task", "--list-id", listId, "--task-id", taskId, "--due", due]
    running: false
    onExited: function(code) {
      if (code === 0) {
        fetchTasksProcess.buffer = "";
        fetchTasksProcess.running = true; // refresh after update
      }
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
    var clientId = "393145303655-qg81bpk1rl814rqc2cl584kp12eogc3f.apps.googleusercontent.com";
    var redirectUri = "http://127.0.0.1:8080";
    var url = "https://accounts.google.com/o/oauth2/v2/auth?client_id=" + clientId + "&redirect_uri=" + redirectUri + "&response_type=code&scope=https://www.googleapis.com/auth/tasks";
    
    // 1. Open the URL natively in QML to bypass all stdout buffering issues
    Quickshell.execDetached(["xdg-open", url]);

    // 2. Start the Rust binary to spin up the local server and catch the token
    loginProcess.running = true;
  }

  // Logout process to delete token
  Process {
    id: logoutProcess
    command: ["sh", "-c", "rm -f ~/.config/noctalia/google-todo/token.json ~/.config/google-todo/token.json"]
    running: false
  }

  function logout() {
    isLoggedIn = false;
    currentListId = "";
    taskLists = [];
    currentTasks = [];
    logoutProcess.running = true;
  }

  function addTask(title, due, parent) {
    if (currentListId !== "" && title.trim() !== "") {
      addTaskProcess.listId = currentListId;
      addTaskProcess.title = title;
      addTaskProcess.due = due || "";
      addTaskProcess.parent = parent || "";
      addTaskProcess.buffer = "";
      addTaskProcess.running = true;
    }
  }

  function deleteTask(taskId) {
    if (currentListId !== "") {
      deleteTaskProcess.listId = currentListId;
      deleteTaskProcess.taskId = taskId;
      deleteTaskProcess.running = true;
    }
  }

  function updateTaskDue(taskId, due) {
    if (currentListId !== "") {
      updateTaskProcess.listId = currentListId;
      updateTaskProcess.taskId = taskId;
      updateTaskProcess.due = due;
      updateTaskProcess.running = true;
    }
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
}
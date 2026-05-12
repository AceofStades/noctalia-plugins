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

  // Timer for periodic sync
  Timer {
    id: syncTimer
    interval: syncInterval * 1000
    repeat: true
    running: cfg.autoStartSync ?? defaults.autoStartSync ?? false
    onTriggered: {
      if (isLoggedIn && currentListId !== "") {
        fetchTasksProcess.listId = currentListId;
        fetchTasksProcess.running = true;
      }
    }
  }

  // Helper to run commands
  function runCommand(commandArgs) {
    if (!pluginApi) return;
    return pluginApi.pluginDir + "/google-todo-sync";
  }

  // Fetch lists
  Process {
    id: fetchListsProcess
    command: [root.runCommand(), "get-lists"]
    running: false
    stdout: Process.Buffer
    onExited: function(code) {
      if (code === 0 && stdoutData.length > 0) {
        try {
          var response = JSON.parse(stdoutData);
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
              fetchTasksProcess.listId = currentListId;
              fetchTasksProcess.running = true;
            }
          }
        } catch (e) {
          Logger.e("Google Todo: Parse error lists: " + e);
        }
      }
    }
  }

  // Fetch tasks
  Process {
    id: fetchTasksProcess
    property string listId: ""
    command: [root.runCommand(), "get-tasks", "--list-id", listId]
    running: false
    stdout: Process.Buffer
    onExited: function(code) {
      if (code === 0 && stdoutData.length > 0) {
        try {
          var response = JSON.parse(stdoutData);
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
    }
  }

  // Complete a task
  Process {
    id: completeTaskProcess
    property string listId: ""
    property string taskId: ""
    command: [root.runCommand(), "complete-task", "--list-id", listId, "--task-id", taskId]
    running: false
    onExited: function(code) {
      if (code === 0) {
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

  function completeTask(taskId) {
    if (currentListId !== "") {
      completeTaskProcess.listId = currentListId;
      completeTaskProcess.taskId = taskId;
      completeTaskProcess.running = true;
    }
  }

  function fetchLists() {
    fetchListsProcess.running = true;
  }

  function fetchTasks(listId) {
    if (listId !== "") {
      currentListId = listId;
      fetchTasksProcess.listId = listId;
      fetchTasksProcess.running = true;
    }
  }

  Component.onCompleted: {
    // Initial fetch to check login status and get lists
    fetchLists();
  }
}

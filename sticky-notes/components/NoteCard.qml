import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

import "../utils/markdown.js" as Markdown

Rectangle {
  id: noteCard

  // Model roles — auto-bound by Repeater
  required property int index
  required property string noteId
  required property string content
  required property string noteColor
  required property string modifiedStr

  // Parent-provided state
  property int editingIndex: -1
  property string editingContent: ""
  property var pluginApi: null

  // Computed
  property bool isEditing: editingIndex === index
  property bool confirmingDelete: false
  property string renderedContent: ""
  readonly property real footerHeight: 28 * Style.uiScaleRatio
  readonly property real footerActionWidth: (28 * 4 + 2 * 3) * Style.uiScaleRatio

  onContentChanged: updateRendered()
  onNoteColorChanged: updateRendered()
  Component.onCompleted: updateRendered()

  function updateRendered() {
    renderedContent = Markdown.render(noteCard.content || "", { noteColor: noteCard.noteColor || "#FFF9C4" });
  }

  // Signals
  signal saveClicked(string editedContent, string editedColor)
  signal editClicked()
  signal deleteClicked()
  signal cancelClicked()
  signal expandClicked()

  HoverHandler { id: cardHover }

  width: parent ? parent.width : 200
  height: isEditing
    ? 200 * Style.uiScaleRatio
    : Math.min(
        Math.max(
          100 * Style.uiScaleRatio,
          noteContent.contentHeight + noteCard.footerHeight + (Style.marginM * 2) + Style.marginXS
        ),
        300 * Style.uiScaleRatio
      )
  color: noteCard.noteColor || "#FFF9C4"
  radius: Style.radiusM
  border.color: isEditing
    ? (editTextArea.activeFocus ? Qt.darker(Color.mPrimary, 1.35) : Color.mPrimary)
    : Qt.darker(noteCard.noteColor || "#FFF9C4", 1.06)
  border.width: isEditing ? Style.borderM : Style.borderS

  Behavior on border.color { ColorAnimation { duration: 150 } }
  Behavior on border.width { NumberAnimation { duration: 150 } }
  Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

  // Shadow
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 2
    anchors.leftMargin: 2
    z: -1
    color: Qt.rgba(0, 0, 0, 0.08)
    radius: Style.radiusM
  }

  // ── Display mode ──
  ColumnLayout {
    id: noteContentCol
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginXS
    visible: !noteCard.isEditing && !noteCard.confirmingDelete

    Flickable {
      id: noteFlickable
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      contentWidth: width
      contentHeight: Math.ceil(noteContent.contentHeight) + 1
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      TextEdit {
        id: noteContent
        width: parent.width
        height: contentHeight
        text: noteCard.renderedContent
        textFormat: TextEdit.RichText
        font.pointSize: Style.fontSizeS * Style.uiScaleRatio
        color: "#37474F"
        wrapMode: TextEdit.Wrap
        readOnly: true
        selectByMouse: true
        activeFocusOnTab: false
        visible: (noteCard.content || "").length > 0

        onLinkActivated: (link) => Qt.openUrlExternally(link)
      }
    }

    RowLayout {
      id: footerRow
      Layout.fillWidth: true
      Layout.minimumHeight: noteCard.footerHeight
      Layout.preferredHeight: noteCard.footerHeight
      Layout.maximumHeight: noteCard.footerHeight
      Layout.rightMargin: Style.marginXS
      spacing: Style.marginXS

      Item { Layout.fillWidth: true }

      Item {
        id: footerRightSlot
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: noteCard.footerActionWidth
        Layout.preferredWidth: noteCard.footerActionWidth
        Layout.maximumWidth: noteCard.footerActionWidth
        Layout.fillHeight: true

        NText {
          id: timestampLabel
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: noteCard.modifiedStr || ""
          font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
          color: Qt.rgba(0, 0, 0, 0.35)
          opacity: cardHover.hovered ? 0.0 : 1.0
          Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        TextEdit {
          id: hiddenCopyHelper
          visible: false
          text: noteCard.content
        }

        Row {
          id: actionRow
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          opacity: cardHover.hovered ? 1.0 : 0.0
          enabled: cardHover.hovered
          Behavior on opacity { NumberAnimation { duration: 120 } }

          NIconButton {
            icon: "arrow-up-left"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.expandClicked()
          }

          NIconButton {
            id: copyBtn
            icon: "copy"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: {
              hiddenCopyHelper.selectAll();
              hiddenCopyHelper.copy();
              hiddenCopyHelper.deselect();
              copyBtn.icon = "copy-check";
              resetCopyIconTimer.start();
              ToastService.showNotice(noteCard.pluginApi?.tr("notes.copied"));
            }

            Timer {
              id: resetCopyIconTimer
              interval: 1500
              onTriggered: copyBtn.icon = "copy"
            }
          }

          NIconButton {
            icon: "pencil"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.editClicked()
          }

          NIconButton {
            icon: "trash"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0.8, 0, 0, 0.15)
            colorFg: "#C62828"
            colorFgHover: "#C62828"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.confirmingDelete = true
          }
        }
      }
    }
  }

  // ── Delete confirmation overlay (#5) ──
  Rectangle {
    anchors.fill: parent
    visible: noteCard.confirmingDelete
    color: Qt.rgba(0, 0, 0, 0.55)
    radius: noteCard.radius
    z: 200

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginM

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: noteCard.pluginApi?.tr("notes.delete-confirm")
        color: "white"
        font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM

        NButton {
          width: 64 * Style.uiScaleRatio
          height: 30 * Style.uiScaleRatio
          buttonRadius: Style.radiusS
          backgroundColor: Qt.rgba(1, 1, 1, 0.15)
          hoverColor: Qt.rgba(1, 1, 1, 0.3)
          textColor: "white"
          textHoverColor: "white"
          text: noteCard.pluginApi?.tr("notes.cancel")
          fontSize: Style.fontSizeS * Style.uiScaleRatio

          onClicked: noteCard.confirmingDelete = false
        }

        NButton {
          width: 64 * Style.uiScaleRatio
          height: 30 * Style.uiScaleRatio
          buttonRadius: Style.radiusS
          backgroundColor: "#C62828"
          hoverColor: "#E53935"
          textColor: "white"
          textHoverColor: "white"
          text: noteCard.pluginApi?.tr("editor.delete")
          fontSize: Style.fontSizeS * Style.uiScaleRatio

          onClicked: {
            noteCard.confirmingDelete = false;
            noteCard.deleteClicked();
          }
        }
      }
    }
  }

  // ── Edit mode overlay ──
  Item {
    anchors.fill: parent
    visible: noteCard.isEditing

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: 2

      Flickable {
        id: editFlickable
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: Math.max(editFlickable.height, Math.ceil(editTextArea.contentHeight) + 1)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        TextEdit {
          id: editTextArea
          width: editFlickable.width
          height: editFlickable.contentHeight
          color: "#3E2723"
          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          selectByKeyboard: true
          persistentSelection: true

          Shortcut {
            sequences: [StandardKey.Copy]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.copy()
          }

          Shortcut {
            sequences: [StandardKey.Cut]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.cut()
          }

          Shortcut {
            sequences: [StandardKey.Paste]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.paste()
          }

          Shortcut {
            sequences: [StandardKey.SelectAll]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.selectAll()
          }

          Shortcut {
            sequences: [StandardKey.Undo]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.undo()
          }

          Shortcut {
            sequences: [StandardKey.Redo]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.redo()
          }

          Keys.onShortcutOverride: (event) => {
            if (event.key === Qt.Key_Escape) {
              noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
              event.accepted = true;
            }
          }

          Keys.onPressed: (event) => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                       (event.modifiers & Qt.ControlModifier)) {
              noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
              event.accepted = true;
            } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
              noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
              event.accepted = true;
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        Item {
          Layout.fillWidth: true
        }

        // Shortcut hint (#13)
        NText {
          Layout.alignment: Qt.AlignVCenter
          text: noteCard.pluginApi?.tr("editor.hint")
          font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
          color: Qt.rgba(0, 0, 0, 0.3)
        }

        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "check"
          baseSize: 28 * Style.uiScaleRatio
          customRadius: Style.iRadiusL
          colorBg: Qt.rgba(0, 0, 0, 0.06)
          colorBgHover: Qt.rgba(0, 0, 0, 0.12)
          colorFg: "#37474F"
          colorFgHover: "#37474F"
          colorBorder: "transparent"
          colorBorderHover: "transparent"

          onClicked: noteCard.saveClicked(editTextArea.text, noteCard.noteColor)
        }
      }
    }
  }

  // Focus text area when entering edit mode
  onIsEditingChanged: {
    if (isEditing) {
      editTextArea.text = noteCard.editingContent;
      editTextArea.forceActiveFocus();
      editTextArea.cursorPosition = editTextArea.text.length;
    }
    confirmingDelete = false;
  }

  // Background double-click to edit
  MouseArea {
    anchors.fill: parent
    z: -1
    onDoubleClicked: noteCard.editClicked()
  }

  function getEditedText() {
    return editTextArea.text;
  }

  function saveCurrent() {
    noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
  }
}

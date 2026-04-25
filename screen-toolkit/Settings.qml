import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
ColumnLayout {
    id: root
    property var pluginApi: null
    spacing: Style.marginL
    property string screenshotPath:         ""
    property string videoPath:              ""
    property string filenameFormat:         ""
    property bool   recordSkipConfirmation: false
    property bool   recordCopyToClipboard:  false
    property int    gifMaxSeconds:          30
    property bool   _loaded: false
    property string _previewNow: ""
    Timer {
        id: previewClock
        interval: 1000; repeat: true; running: root.visible
        onTriggered: root._previewNow = new Date().toString()
    }
    function _load() {
        if (!pluginApi?.pluginSettings) return
        _loaded = false
        screenshotPath         = pluginApi.pluginSettings.screenshotPath         || ""
        videoPath              = pluginApi.pluginSettings.videoPath              || ""
        filenameFormat         = pluginApi.pluginSettings.filenameFormat         || ""
        recordSkipConfirmation = pluginApi.pluginSettings.recordSkipConfirmation ?? false
        recordCopyToClipboard  = pluginApi.pluginSettings.recordCopyToClipboard  ?? false
        gifMaxSeconds          = pluginApi.pluginSettings.gifMaxSeconds          ?? 30
        _loaded = true
    }
    Component.onCompleted: _load()
    onPluginApiChanged:    _load()
    function saveSettings() {
        if (!pluginApi || !_loaded) return
        pluginApi.pluginSettings.screenshotPath         = root.screenshotPath
        pluginApi.pluginSettings.videoPath              = root.videoPath
        pluginApi.pluginSettings.filenameFormat         = root.filenameFormat
        pluginApi.pluginSettings.recordSkipConfirmation = root.recordSkipConfirmation
        pluginApi.pluginSettings.recordCopyToClipboard  = root.recordCopyToClipboard
        pluginApi.pluginSettings.gifMaxSeconds          = root.gifMaxSeconds
        pluginApi.saveSettings()
    }
    function buildPreview(fmt) {
        var _ = root._previewNow
        var now = new Date()
        if (!fmt || fmt.trim() === "")
            return Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return fmt
            .replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
            .replace(/%m/g, Qt.formatDateTime(now, "MM"))
            .replace(/%d/g, Qt.formatDateTime(now, "dd"))
            .replace(/%H/g, Qt.formatDateTime(now, "HH"))
            .replace(/%M/g, Qt.formatDateTime(now, "mm"))
            .replace(/%S/g, Qt.formatDateTime(now, "ss"))
    }
    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.screenshotPath")
        description:     pluginApi?.tr("settings.screenshotPathDesc")
        placeholderText: "~/Pictures/Screenshots"
        text:            root.screenshotPath
        onTextChanged: { root.screenshotPath = text; saveSettings() }
    }
    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.videoPath")
        description:     pluginApi?.tr("settings.videoPathDesc")
        placeholderText: "~/Videos"
        text:            root.videoPath
        onTextChanged: { root.videoPath = text; saveSettings() }
    }
    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        ColumnLayout {
            spacing: Style.marginXS
            NLabel { label: pluginApi?.tr("settings.filenameFormat") }
            NText {
                text:      pluginApi?.tr("settings.filenameFormatDesc")
                pointSize: Style.fontSizeXS
                color:     Color.mOnSurfaceVariant
                wrapMode:  Text.WordWrap
                Layout.fillWidth: true
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Style.marginS
            readonly property var tokens: [
                { label: pluginApi?.tr("settings.filenameTokens.year"),   value: "%Y" },
                { label: pluginApi?.tr("settings.filenameTokens.month"),  value: "%m" },
                { label: pluginApi?.tr("settings.filenameTokens.day"),    value: "%d" },
                { label: pluginApi?.tr("settings.filenameTokens.hour"),   value: "%H" },
                { label: pluginApi?.tr("settings.filenameTokens.minute"), value: "%M" },
                { label: pluginApi?.tr("settings.filenameTokens.second"), value: "%S" },
            ]
            Repeater {
                model: parent.tokens
                delegate: Rectangle {
                    height: 28
                    width:  tokenRow.implicitWidth + Style.marginM * 2
                    radius: Style.radiusM
                    color:  tokenMA.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        id: tokenRow; anchors.centerIn: parent; spacing: Style.marginXS
                        NText { text: modelData.label; pointSize: Style.fontSizeXS; font.weight: Font.Medium; color: tokenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter }
                        NText { text: modelData.value; pointSize: Style.fontSizeXS; color: tokenMA.containsMouse ? Qt.rgba(1,1,1,0.65) : Color.mOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: tokenMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!filenameInput.inputItem) return
                            var input = filenameInput.inputItem
                            var cur = input.cursorPosition; var txt = input.text
                            input.text = txt.substring(0, cur) + modelData.value + txt.substring(cur)
                            input.cursorPosition = cur + modelData.value.length
                            input.forceActiveFocus()
                        }
                    }
                }
            }
        }
        NTextInput {
            id: filenameInput
            Layout.fillWidth: true
            placeholderText: "%Y-%m-%dT%H-%M-%S"
            text: root.filenameFormat
            onTextChanged: { root.filenameFormat = text; saveSettings() }
        }
        Rectangle {
            Layout.fillWidth: true
            height: previewRow.implicitHeight + Style.marginM * 2
            radius: Style.radiusM; color: Color.mSurfaceVariant; opacity: 0.7
            Row {
                id: previewRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Style.marginM; rightMargin: Style.marginM }
                spacing: Style.marginS
                NIcon { icon: "file"; color: Color.mOnSurfaceVariant; scale: 0.85; anchors.verticalCenter: parent.verticalCenter }
                NText { text: root.buildPreview(root.filenameFormat) + ".ext"; pointSize: Style.fontSizeXS; color: Color.mOnSurface; font.family: "monospace"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - (Style.marginM * 2) }
            }
        }
    }
    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }
    NLabel { label: pluginApi?.tr("settings.recordingSection") }
    SettingToggle {
        Layout.fillWidth: true
        labelText: pluginApi?.tr("settings.recordSkipConfirmation")
        descText:  pluginApi?.tr("settings.recordSkipConfirmationDesc")
        checked:   root.recordSkipConfirmation
        onToggled: (v) => { root.recordSkipConfirmation = v; saveSettings() }
    }
    SettingToggle {
        Layout.fillWidth: true
        labelText: pluginApi?.tr("settings.recordCopyToClipboard")
        descText:  pluginApi?.tr("settings.recordCopyToClipboardDesc")
        checked:   root.recordCopyToClipboard
        onToggled: (v) => { root.recordCopyToClipboard = v; saveSettings() }
    }
    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.gifMaxSeconds")
        description:     pluginApi?.tr("settings.gifMaxSecondsDesc")
        placeholderText: "30"
        text:            root.gifMaxSeconds
        onTextChanged: {
            var val = parseInt(text)
            if (!isNaN(val)) {
                root.gifMaxSeconds = Math.max(5, Math.min(300, val))
                saveSettings()
            }
        }
    }
    component SettingToggle: RowLayout {
        id: _tog
        property string labelText: ""
        property string descText:  ""
        property bool   checked:   false
        signal toggled(bool value)
        spacing: Style.marginM
        ColumnLayout {
            Layout.fillWidth: true; spacing: Style.marginXXS
            NLabel { label: _tog.labelText }
            NText { text: _tog.descText; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
        Rectangle {
            width: Style.marginXL * 2 + Style.marginXS; height: Style.marginL + Style.marginM; radius: Math.round((Style.marginL + Style.marginM) / 2)
            color: _tog.checked ? Color.mPrimary : Color.mSurfaceVariant
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                id: _thumb; width: Style.marginXL; height: Style.marginXL; radius: Math.round(Style.marginXL / 2); color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: _tog.checked ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: _tog.toggled(!_tog.checked) }
        }
    }
}


import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var pluginApi:    null
    property var mainInstance: null
    implicitWidth:  parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    readonly property string pickedHex: {
        var v = mainInstance?.resultHex ?? ""
        return (typeof v === "string" && v.length === 7 && v.charAt(0) === "#") ? v : ""
    }
    readonly property string pickedRgb: {
        var v = mainInstance?.resultRgb ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsv: {
        var v = mainInstance?.resultHsv ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsl: {
        var v = mainInstance?.resultHsl ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string colorCapturePath: mainInstance?.colorCapturePath ?? ""
    readonly property int    colorCacheBust:   mainInstance?.colorCacheBust   ?? 0
    readonly property var colorHistory: mainInstance?.colorHistory ?? []
    Process { id: clipProc }
    function _copy(text) {
        if (!text || text === "") return
        clipProc.exec({ command: ["bash", "-c",
            "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function clear() {
        if (pluginApi) {
            pluginApi.pluginSettings.resultHex        = ""
            pluginApi.pluginSettings.resultRgb        = ""
            pluginApi.pluginSettings.resultHsv        = ""
            pluginApi.pluginSettings.resultHsl        = ""
            pluginApi.pluginSettings.colorCapturePath = ""
            pluginApi.saveSettings()
        }
        if (mainInstance) {
            mainInstance.resultHex        = ""
            mainInstance.resultRgb        = ""
            mainInstance.resultHsv        = ""
            mainInstance.resultHsl        = ""
            mainInstance.colorCapturePath = ""
            mainInstance.activeTool       = ""
        }
    }
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginM
        Rectangle {
            width: parent.width; height: 36; radius: Style.radiusM
            color: pickAgainBtn.containsMouse ? Color.mPrimary : Color.mSurface
            border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth || 1
            Row {
                anchors.centerIn: parent; spacing: Style.marginS
                NIcon {
                    icon: "color-picker"
                    color: pickAgainBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                }
                NText {
                    text: pluginApi?.tr("panel.pickAgain")
                    color: pickAgainBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                    pointSize: Style.fontSizeS
                }
            }
            MouseArea {
                id: pickAgainBtn; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: mainInstance?.runColorPicker()
            }
        }
        Column {
            visible: root.pickedHex !== ""
            width: parent.width
            spacing: Style.marginM
            Row {
                width: parent.width
                spacing: Style.marginM
                Rectangle {
                    width: 110; height: 110; radius: Style.radiusM
                    color: Color.mSurfaceVariant; clip: true
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    Image {
                        id: pixelImg; anchors.fill: parent
                        source: root.colorCapturePath !== ""
                            ? ("file://" + root.colorCapturePath + "?b=" + root.colorCacheBust) : ""
                        fillMode: Image.Stretch; smooth: false; cache: false
                        visible: status === Image.Ready
                        onStatusChanged: if (status === Image.Ready) visible = true
                    }
                    Rectangle {
                        anchors.centerIn: parent; width: 10; height: 10; radius: 5
                        color: "transparent"; border.color: "white"
                        border.width: Style.capsuleBorderWidth || 1
                        visible: pixelImg.status === Image.Ready
                    }
                    NText {
                        anchors.centerIn: parent
                        visible: pixelImg.status !== Image.Ready
                        text: "..."; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS
                    }
                }
                Column {
                    width: parent.width - 110 - Style.marginM
                    spacing: Style.marginS
                    Rectangle {
                        id: colorSwatch; width: parent.width; height: 72; radius: Style.radiusM
                        color: root.pickedHex !== "" ? root.pickedHex : "#888888"
                        border.color: Style.capsuleBorderColor || "transparent"
                        border.width: Style.capsuleBorderWidth || 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._copy(root.pickedHex)
                                ToastService.showNotice(pluginApi?.tr("panel.formatCopied", { label: "HEX" }))
                            }
                        }
                    }
                    NText {
                        width: parent.width
                        text: root.pickedHex.toUpperCase()
                        color: Color.mOnSurface; font.weight: Font.Bold
                        pointSize: Style.fontSizeM; horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            Repeater {
                model: [
                    { label: "HEX", value: root.pickedHex },
                    { label: "RGB", value: root.pickedRgb },
                    { label: "HSL", value: root.pickedHsl },
                    { label: "HSV", value: root.pickedHsv }
                ]
                delegate: Rectangle {
                    width: root.width; height: 36; radius: Style.radiusM
                    color: rh.containsMouse ? Color.mHover : Color.mSurface
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS; anchors.rightMargin: Style.marginS
                        spacing: Style.marginS
                        NText {
                            text: modelData.label; color: Color.mPrimary; font.weight: Font.Bold
                            pointSize: Style.fontSizeS; width: 36; height: parent.height
                            verticalAlignment: Text.AlignVCenter
                        }
                        NText {
                            text: modelData.value || "—"; color: Color.mOnSurface
                            pointSize: Style.fontSizeS; width: root.width - 90; height: parent.height
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                    NIcon {
                        icon: "copy"
                        color: rh.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                        anchors.right: parent.right; anchors.rightMargin: Style.marginS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        id: rh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._copy(modelData.value)
                            ToastService.showNotice(pluginApi?.tr("panel.formatCopied", { label: modelData.label }))
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginS
                Rectangle {
                    width: parent.width; height: 36; radius: Style.radiusM
                    color: cah.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "copy"; color: cah.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant }
                        NText {
                            text: pluginApi?.tr("panel.copyAll")
                            color: cah.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }
                    }
                    MouseArea {
                        id: cah; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._copy(root.pickedHex + "\n" + root.pickedRgb + "\n" + root.pickedHsl + "\n" + root.pickedHsv)
                            ToastService.showNotice(pluginApi?.tr("panel.allFormatsCopied"))
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: Style.radiusM
                    color: clrh.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
                    border.color: clrh.containsMouse ? Color.mError || "#f44336" : (Style.capsuleBorderColor || "transparent")
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon {
                            icon: "trash"
                            color: clrh.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant
                        }
                        NText {
                            text: pluginApi?.tr("panel.clearResult")
                            color: clrh.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }
                    }
                    MouseArea {
                        id: clrh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.clear()
                    }
                }
            }
        }
        Column {
            width: parent.width; spacing: Style.marginS
            visible: root.colorHistory.length > 0
            Row {
                width: parent.width; spacing: Style.marginS
                Rectangle { width: 40; height: 1; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter }
                NText { text: pluginApi?.tr("panel.history"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                Rectangle { height: 1; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120 }
                Rectangle {
                    width: 22; height: 22; radius: Style.radiusS || 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: hhc.containsMouse ? Color.mErrorContainer || "#ffcdd2" : "transparent"
                    NIcon {
                        anchors.centerIn: parent; icon: "trash"; scale: 0.75
                        color: hhc.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant
                    }
                    MouseArea {
                        id: hhc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pluginApi) {
                                pluginApi.pluginSettings.colorHistory = []
                                pluginApi.saveSettings()
                            }
                            if (mainInstance) mainInstance.colorHistory = []
                            ToastService.showNotice(pluginApi?.tr("panel.historyCleared"))
                        }
                    }
                }
            }
            Flow {
                width: parent.width; spacing: Style.marginS
                Repeater {
                    model: root.colorHistory
                    delegate: Rectangle {
                        width: 28; height: 28; radius: Style.radiusS || 6
                        border.color: hh.containsMouse ? Color.mPrimary : (Style.capsuleBorderColor || "transparent")
                        border.width: hh.containsMouse ? 2 : (Style.capsuleBorderWidth || 1)
                        Component.onCompleted: color = modelData
                        MouseArea {
                            id: hh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._copy(modelData)
                                ToastService.showNotice(pluginApi?.tr("panel.colorCopied", { color: modelData }))
                            }
                            onEntered: TooltipService.show(hh, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
                            onExited:  TooltipService.hide()
                        }
                    }
                }
            }
        }
    }
}


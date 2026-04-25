import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor
import "overlays"
import "widgets"
import "utils/utils.js" as U
Item {
    id: root
    property var pluginApi: null
    readonly property string _scriptsDir: Qt.resolvedUrl("scripts/").toString().replace("file://", "")
    readonly property string _home: Quickshell.env("HOME")
    property bool   isRunning:              false
    property string activeTool:             ""
    property string pendingLangStr:         "eng"
    property string pendingRecordFormat:    "gif"
    property bool   pendingRecordAudioOut:  false
    property bool   pendingRecordAudioIn:   false
    property bool   pendingRecordCursor:    false
    property string pendingTool:            ""
    property var    installedLangs:         []
    property bool   transAvailable:         false
    property string detectedRecorder:       ""
    readonly property string detectedCompositor: isHyprland ? "hyprland" : isNiri ? "niri" : "other"
    property string resultHex:        ""
    property string resultRgb:        ""
    property string resultHsv:        ""
    property string resultHsl:        ""
    property string colorCapturePath: ""
    property int    colorCacheBust:   0
    property string ocrResult:        ""
    property string ocrCapturePath:   ""
    property string qrResult:         ""
    property string qrCapturePath:    ""
    property string translateResult:  ""
    property var    paletteColors:    []
    property var    colorHistory:     []
    readonly property string recordState:  recordOverlay?.recordState  ?? ""
    readonly property string recordFormat: recordOverlay?.format       ?? "gif"
    readonly property string recordPath:   recordOverlay?.gifPath      ?? ""
    readonly property bool   mirrorVisible: mirrorOverlay.isVisible
    readonly property bool   hasPins:       pinOverlay.hasPins
    readonly property bool   isNiri:      CompositorService.isNiri
    readonly property bool   isHyprland:  CompositorService.isHyprland
    property int    _regionX:      0
    property int    _regionY:      0
    property int    _regionW:      0
    property int    _regionH:      0
    property var    _regionScreen: null
    property bool   _capsDetected:   false
    property bool   _sessionChecked: false
    property var    _detectedLangs:  []
    property string _grimGeometry: ""
    property int    _grimX:        0
    property int    _grimY:        0
    property int    _grimW:        0
    property int    _grimH:        0
    property int    _grimLocalX:   0
    property int    _grimLocalY:   0
    Component.onCompleted: {
        root.isRunning  = false
        root.activeTool = ""
        Logger.i("ScreenToolkit", "Scripts dir: " + root._scriptsDir)
        if (!_capsDetected) {
            detectCapabilities()
            _capsDetected = true
        }
    }
    onPluginApiChanged: {
        if (pluginApi) {
            _resolveMainInstance()
            mainInstancePoller.start()
            if (!root._sessionChecked) {
                root._sessionChecked = true
                _checkSession()
            }
        } else {
            mainInstancePoller.stop()
            root.mainInstance = null
        }
    }
    Process {
        id: sessionCheckProc
        stdout: StdioCollector {}
        onExited: {
            var isNewBoot = sessionCheckProc.stdout.text.trim() === "new"
            if (isNewBoot) {
                _clearStaleResults()
            } else {
                _restoreSavedState()
            }
        }
    }
    function _checkSession() {
        sessionCheckProc.exec({ command: ["bash", "-c",
            "[ -f /tmp/screen-toolkit-session ] && echo 'exists' || echo 'new'; " +
            "touch /tmp/screen-toolkit-session"
        ]})
    }
    function _clearStaleResults() {
        if (!pluginApi) return
        pluginApi.pluginSettings.resultHex        = ""
        pluginApi.pluginSettings.resultRgb        = ""
        pluginApi.pluginSettings.resultHsv        = ""
        pluginApi.pluginSettings.resultHsl        = ""
        pluginApi.pluginSettings.colorCapturePath = ""
        pluginApi.pluginSettings.colorCacheBust   = 0
        pluginApi.pluginSettings.ocrResult        = ""
        pluginApi.pluginSettings.ocrCapturePath   = ""
        pluginApi.pluginSettings.qrResult         = ""
        pluginApi.pluginSettings.qrCapturePath    = ""
        pluginApi.pluginSettings.paletteColors    = []
        pluginApi.pluginSettings.translateResult  = ""
        pluginApi.saveSettings()
        root.colorHistory = pluginApi.pluginSettings.colorHistory || []
    }
    function _restoreSavedState() {
        if (!pluginApi) return
        var s = pluginApi.pluginSettings
        if ((s.resultHex ?? "") !== "") {
            root.resultHex        = s.resultHex
            root.resultRgb        = s.resultRgb        ?? ""
            root.resultHsv        = s.resultHsv        ?? ""
            root.resultHsl        = s.resultHsl        ?? ""
            root.colorCapturePath = s.colorCapturePath ?? ""
            root.colorCacheBust   = s.colorCacheBust   ?? 0
        }
        if ((s.ocrResult ?? "") !== "") {
            root.ocrResult      = s.ocrResult
            root.ocrCapturePath = s.ocrCapturePath ?? ""
        }
        if ((s.qrResult ?? "") !== "") {
            root.qrResult      = s.qrResult
            root.qrCapturePath = s.qrCapturePath ?? ""
        }
        var pal = s.paletteColors ?? []
        if (pal.length > 0) root.paletteColors = pal
        root.colorHistory = s.colorHistory || []
    }
    property var mainInstance: null
    Connections {
        target: pluginApi
        ignoreUnknownSignals: true
        function onMainInstanceChanged() { root._resolveMainInstance() }
    }
    function _resolveMainInstance() {
        if (!pluginApi) { mainInstancePoller.stop(); return }
        if (pluginApi?.mainInstance) {
            root.mainInstance = pluginApi.mainInstance
            mainInstancePoller.stop()
        }
    }
    Timer {
        id: mainInstancePoller
        interval: 200; repeat: true
        property int _attempts: 0
        readonly property int _maxAttempts: 25
        onTriggered: {
            _attempts++
            root._resolveMainInstance()
            if (_attempts >= _maxAttempts && root.mainInstance === null) {
                console.warn("ScreenToolkit: mainInstance not resolved after 5s")
                stop()
            }
        }
        onRunningChanged: if (!running) _attempts = 0
    }
    Connections {
        target: recordOverlay
        function onRecordStateChanged() {
            if (!pluginApi) return
            var s = recordOverlay.recordState
            var skipConfirm = pluginApi.pluginSettings?.recordSkipConfirmation ?? false
            var toClipboard = pluginApi.pluginSettings?.recordCopyToClipboard  ?? false
            if (s === "converting" && !skipConfirm && !toClipboard) {
                var screen = recordOverlay._primaryScreen
                if (screen) pluginApi.openPanel(screen)
                else pluginApi.withCurrentScreen(sc => pluginApi.openPanel(sc))
            }
        }
        function onDismissed() {
            if (root.activeTool === "record") root.activeTool = ""
        }
    }
    RegionSelector {
        id: regionSelector
        pluginApi: root.pluginApi
        onRegionSelected: (x, y, w, h, screen) => {
            root._regionX      = x; root._regionY = y
            root._regionW      = w; root._regionH = h
            root._regionScreen = screen
            var scale          = screen?.devicePixelRatio ?? 1.0
            var sx             = screen?.x ?? 0
            var sy             = screen?.y ?? 0
            root._grimX        = sx + Math.round(x / scale)
            root._grimY        = sy + Math.round(y / scale)
            root._grimW        = Math.round(w / scale)
            root._grimH        = Math.round(h / scale)
            root._grimLocalX   = Math.round(x / scale)
            root._grimLocalY   = Math.round(y / scale)
            root._grimGeometry = root._grimX + "," + root._grimY + " " + root._grimW + "x" + root._grimH
            _dispatchPendingTool()
        }
        onCancelled: {
            root.isRunning  = false
            root.activeTool = ""
        }
    }
    Annotate { id: annotateOverlay; mainInstance: root }
    Measure  { id: measureOverlay;  mainInstance: root }
    Pin      { id: pinOverlay;      pluginApi: root.pluginApi }
    Record   { id: recordOverlay;   pluginApi: root.pluginApi }
    Mirror   { id: mirrorOverlay;   pluginApi: root.pluginApi }
    Process {
        id: detectLangsProc
        stdout: StdioCollector {}
        onExited: {
            var lines = detectLangsProc.stdout.text.trim().split("\n")
            root._detectedLangs = []
            for (var i = 0; i < lines.length; i++) {
                var lang = lines[i].trim()
                if (lang === "" || lang === "osd" || lang === "equ") continue
                if (!root._detectedLangs.includes(lang))
                    root._detectedLangs.push(lang)
            }
            if (pluginApi && root._detectedLangs.length > 0) {
                pluginApi.pluginSettings.installedLangs = root._detectedLangs.slice()
                pluginApi.saveSettings()
            }
            if (root._detectedLangs.length > 0)
                root.installedLangs = root._detectedLangs.slice()
        }
    }
    Process {
        id: detectTransProc
        stdout: StdioCollector {}
        onExited: {
            var path = detectTransProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.transAvailable = path !== "" && path.startsWith("/")
                pluginApi.saveSettings()
            }
            root.transAvailable = path !== "" && path.startsWith("/")
        }
    }
    Process {
        id: detectRecorderProc
        stdout: StdioCollector {}
        onExited: {
            var path = detectRecorderProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.detectedRecorder =
                    path.endsWith("wl-screenrec") ? "wl-screenrec" :
                    path.endsWith("wf-recorder")  ? "wf-recorder"  : ""
                pluginApi.saveSettings()
            }
            root.detectedRecorder =
                path.endsWith("wl-screenrec") ? "wl-screenrec" :
                path.endsWith("wf-recorder")  ? "wf-recorder"  : ""
        }
    }
    Process {
        id: colorPickerProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            if (code !== 0 || colorPickerProc.stdout.text.trim() === "") {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.picker-cancelled"))
                return
            }
            var output = colorPickerProc.stdout.text.trim()
            var parts  = output.split(/\s+/)
            if (parts.length < 3) {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.picker-cancelled"))
                return
            }
            var r = Math.max(0, Math.min(255, parseInt(parts[0])))
            var g = Math.max(0, Math.min(255, parseInt(parts[1])))
            var b = Math.max(0, Math.min(255, parseInt(parts[2])))
            var hex = "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1).toUpperCase()
            var rgb = "rgb(" + r + ", " + g + ", " + b + ")"
            var rn  = r / 255, gn = g / 255, bn = b / 255
            var max = Math.max(rn, gn, bn)
            var min = Math.min(rn, gn, bn)
            var d   = max - min
            var h = 0
            var s = max === 0 ? 0 : d / max
            var v = max
            if (d !== 0) {
                if      (max === rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) % 6
                else if (max === gn) h = (bn - rn) / d + 2
                else                 h = (rn - gn) / d + 4
                h = Math.round(h * 60)
            }
            var hsv = "hsv(" + h + ", " + Math.round(s * 100) + "%, " + Math.round(v * 100) + "%)"
            var l   = (max + min) / 2
            var sl  = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
            var hsl = "hsl(" + h + ", " + Math.round(sl * 100) + "%, " + Math.round(l * 100) + "%)"
            root.resultHex        = hex
            root.resultRgb        = rgb
            root.resultHsv        = hsv
            root.resultHsl        = hsl
            root.colorCapturePath = "/tmp/screen-toolkit-colorpicker.png"
            root.colorCacheBust   = Date.now()
            if (pluginApi) {
                pluginApi.pluginSettings.resultHex        = hex
                pluginApi.pluginSettings.resultRgb        = rgb
                pluginApi.pluginSettings.resultHsv        = hsv
                pluginApi.pluginSettings.resultHsl        = hsl
                pluginApi.pluginSettings.colorCapturePath = "/tmp/screen-toolkit-colorpicker.png"
                pluginApi.pluginSettings.colorCacheBust   = Date.now()
                var history = pluginApi.pluginSettings.colorHistory || []
                history = [hex].concat(history.filter(c => c !== hex)).slice(0, 8)
                pluginApi.pluginSettings.colorHistory = history
                pluginApi.saveSettings()
                root.colorHistory = history
            }
            root.activeTool = "colorpicker"
            if (pluginApi)
                pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
        }
    }
    Process {
        id: ocrProc
        stdout: StdioCollector {}
        onExited: {
            root.isRunning = false
            var text = ocrProc.stdout.text.trim()
            if (text !== "") {
                if (pluginApi) {
                    pluginApi.pluginSettings.ocrResult       = text
                    pluginApi.pluginSettings.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
                    pluginApi.pluginSettings.translateResult = ""
                    pluginApi.saveSettings()
                }
                root.ocrResult       = text
                root.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
                root.translateResult = ""
                root.activeTool      = "ocr"
                if (pluginApi)
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.no-text"))
            }
        }
    }
    Process {
        id: qrProc
        stdout: StdioCollector {}
        onExited: {
            root.isRunning = false
            var result = qrProc.stdout.text.trim()
            if (result !== "") {
                if (pluginApi) {
                    pluginApi.pluginSettings.qrResult      = result
                    pluginApi.pluginSettings.qrCapturePath = "/tmp/screen-toolkit-qr.png"
                    pluginApi.saveSettings()
                }
                root.qrResult      = result
                root.qrCapturePath = "/tmp/screen-toolkit-qr.png"
                root.activeTool    = "qr"
                if (pluginApi)
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.no-qr"))
            }
        }
    }
    Process {
        id: lensProc
        onExited: (code) => {
            root.isRunning  = false
            root.activeTool = ""
            if (code !== 0) ToastService.showError(pluginApi.tr("messages.lens-failed"))
        }
    }
    Process {
        id: annotateProc
        onExited: (code) => {
            root.isRunning = false
            if (code === 0) {
                root.activeTool = ""
                var region = annotateRegionState._pendingRegion
                var screen = annotateRegionState._pendingScreen
                annotateRegionState._pendingRegion = ""
                annotateRegionState._pendingScreen = null
                if (pluginApi) {
                    pluginApi.withCurrentScreen(s => {
                        pluginApi.closePanel(s)
                        annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", screen)
                    })
                } else {
                    annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", screen)
                }
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }
    QtObject {
        id: annotateRegionState
        property string _pendingRegion: ""
        property var    _pendingScreen: null
    }
    Process {
        id: annotateWinProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var geomStr = annotateWinProc.stdout.text.trim()
            if (code !== 0 || geomStr === "") {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
                return
            }
            var parts = geomStr.split(" ")
            if (parts.length < 2) { root.activeTool = ""; return }
            var xy = parts[0].split(",")
            var wh = parts[1].split("x")
            var gx = parseInt(xy[0]) || 0
            var gy = parseInt(xy[1]) || 0
            var gw = parseInt(wh[0]) || 400
            var gh = parseInt(wh[1]) || 300
            var screen    = root._findScreenForPoint(gx, gy)
            var regionStr = (gx - (screen?.x ?? 0)) + "," + (gy - (screen?.y ?? 0)) + " " + gw + "x" + gh
            root.activeTool = ""
            if (pluginApi) {
                pluginApi.withCurrentScreen(s => {
                    pluginApi.closePanel(s)
                    annotateOverlay.parseAndShow(regionStr, "/tmp/screen-toolkit-annotate.png", screen)
                })
            } else {
                annotateOverlay.parseAndShow(regionStr, "/tmp/screen-toolkit-annotate.png", screen)
            }
        }
    }
    Process {
        id: pinGrimProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var output = pinGrimProc.stdout.text.trim()
            if (code === 0 && output !== "") {
                var parts = output.split("|")
                if (parts.length === 2) {
                    var imgPath = parts[0]
                    var wh  = parts[1].split("x")
                    var pw  = parseInt(wh[0]) || 400
                    var ph  = parseInt(wh[1]) || 300
                    pinOverlay.addPin(imgPath, pw, ph, root._regionScreen)
                    ToastService.showNotice(pluginApi.tr("messages.pinned"))
                }
            } else if (code !== 0) {
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }
    Process {
        id: pinFileProc
        stdout: StdioCollector {}
        onExited: (code) => {
            var path = pinFileProc.stdout.text.trim()
            if (code === 0 && path !== "") {
                pinOverlay.addPin(path, 600, 400, root._regionScreen)
                ToastService.showNotice(pluginApi.tr("messages.pinned"))
            } else if (code === 2) {
                ToastService.showError(pluginApi.tr("messages.no-file-picker"))
            }
        }
    }
    Process {
        id: paletteProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var raw = paletteProc.stdout.text.trim()
            if (code === 0 && raw !== "") {
                var colors = raw.split("\n")
                    .map(function(c) { return c.trim() })
                    .filter(function(c) { return /^#[0-9a-fA-F]{6}$/.test(c) })
                    .filter(function(c, i, arr) { return arr.indexOf(c) === i })
                    .slice(0, 8)
                if (colors.length > 0) {
                    root.paletteColors = colors
                    root.activeTool    = "palette"
                    if (pluginApi) {
                        pluginApi.pluginSettings.paletteColors = colors
                        pluginApi.saveSettings()
                        pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
                    }
                } else {
                    root.activeTool = ""
                    ToastService.showError(pluginApi?.tr("messages.palette-failed"))
                }
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi?.tr("messages.palette-failed"))
            }
        }
    }
    Process {
        id: translateProc
        property bool isTranslating: false
        stdout: StdioCollector {}
        onExited: {
            translateProc.isTranslating = false
            var result = translateProc.stdout.text.trim()
            root.translateResult = result !== ""
                ? result : pluginApi?.tr("messages.translate-failed")
        }
    }
    Process { id: clipProc }
    Timer {
        id: launchColorPicker
        interval: 220; repeat: false
        onTriggered: {
            colorPickerProc.exec({ command: [
                root._scriptsDir + "color-picker.sh",
                "/tmp/screen-toolkit-colorpicker.png"
            ]})
        }
    }
    Timer {
        id: launchOcr
        interval: 50; repeat: false
        onTriggered: {
            var area        = root._grimW * root._grimH
            var upscale     = root._grimH < 30 ? "-resize 400%" : (area < 50000 || root._grimW < 200) ? "-resize 200%" : ""
            var aspectRatio = root._grimW / Math.max(root._grimH, 1)
            var psm         = aspectRatio > 8 ? "7" : area < 60000 ? "6" : root._grimH < 40 ? "7" : "3"
            ocrProc.exec({ command: [
                root._scriptsDir + "ocr.sh",
                String(root._grimX), String(root._grimY), String(root._grimW), String(root._grimH),
                root.pendingLangStr || "eng",
                upscale,
                psm
            ]})
        }
    }
    Timer {
        id: launchQr
        interval: 50; repeat: false
        onTriggered: {
            qrProc.exec({ command: ["bash", "-c",
                "grim -g \"" + root._grimGeometry + "\" /tmp/screen-toolkit-qr.png 2>/dev/null" +
                "; zbarimg -q --raw /tmp/screen-toolkit-qr.png 2>/dev/null"
            ]})
        }
    }
    Timer {
        id: launchLens
        interval: 50; repeat: false
        onTriggered: {
            lensProc.exec({ command: [
                root._scriptsDir + "lens-upload.sh",
                String(root._grimX), String(root._grimY), String(root._grimW), String(root._grimH)
            ]})
        }
    }
    Timer {
        id: launchAnnotate
        interval: 50; repeat: false
        onTriggered: {
            var regionStr = root._grimLocalX + "," + root._grimLocalY + " " + root._grimW + "x" + root._grimH
            annotateRegionState._pendingRegion = regionStr
            annotateRegionState._pendingScreen = root._regionScreen
            annotateProc.exec({ command: ["bash", "-c",
                "grim -g \"" + root._grimGeometry + "\" /tmp/screen-toolkit-annotate.png 2>/dev/null"
            ]})
        }
    }
    Timer {
        id: launchAnnotateActiveWindow
        interval: 360; repeat: false
        onTriggered: {
            annotateWinProc.exec({ command: ["bash", "-c",
                "WIN=$(hyprctl activewindow -j 2>/dev/null) || exit 1; " +
                "GEOM=$(printf '%s' \"$WIN\" | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"' 2>/dev/null); " +
                "[ -z \"$GEOM\" ] && exit 1; " +
                "grim -g \"$GEOM\" /tmp/screen-toolkit-annotate.png 2>/dev/null || exit 1; " +
                "printf '%s' \"$GEOM\""
            ]})
        }
    }
    Timer {
        id: launchAnnotateFullscreen
        interval: 380; repeat: false
        property var targetScreen: null
        onTriggered: {
            var name = targetScreen?.name ?? ""
            annotateProc.exec({ command: name !== ""
                ? ["grim", "-o", name, "/tmp/screen-toolkit-annotate.png"]
                : ["grim", "/tmp/screen-toolkit-annotate.png"]
            })
        }
    }
    Timer {
        id: launchPin
        interval: 50; repeat: false
        onTriggered: {
            pinGrimProc.exec({ command: ["bash", "-c",
                "FILE=/tmp/screen-toolkit-pin-$(date +%s%3N).png" +
                "; grim -s 2 -g \"" + root._grimGeometry + "\" \"$FILE\" 2>/dev/null || exit 1" +
                "; echo \"$FILE|" + root._grimW + "x" + root._grimH + "\""
            ]})
        }
    }
    Timer {
        id: launchPinFile
        interval: 200; repeat: false
        onTriggered: {
            pinFileProc.exec({ command: [root._scriptsDir + "pick-file.sh"] })
        }
    }
    Timer {
        id: launchPalette
        interval: 50; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-palette.png"
            paletteProc.exec({ command: ["bash", "-c",
                "grim -g \"" + root._grimGeometry + "\" " + file + " 2>/dev/null && " +
                "magick " + file + " -alpha off +dither -colors 8 -unique-colors txt:- 2>/dev/null" +
                " | grep -v '^#' | grep -oP '#[0-9a-fA-F]{6}' | head -8"
            ]})
        }
    }
    Timer {
        id: launchRecord
        interval: 50; repeat: false
        onTriggered: {
            root.isRunning  = false
            root.activeTool = "record"
            recordOverlay.startRecording(
                root._grimGeometry, root.pendingRecordFormat,
                root.pendingRecordAudioOut, root.pendingRecordAudioIn,
                root.pendingRecordCursor, root._grimLocalX, root._grimLocalY,
                root._regionScreen
            )
        }
    }
    Timer {
        id: launchRecordFullscreen
        interval: 50; repeat: false
        property var targetScreen: null
        onTriggered: {
            var screen = targetScreen ?? Quickshell.screens[0] ?? null
            if (!screen) return
            var scale  = screen.devicePixelRatio ?? 1.0
            var region = screen.x + "," + screen.y + " " +
                         Math.round(screen.width * scale) + "x" +
                         Math.round(screen.height * scale)
            root.isRunning  = false
            root.activeTool = "record"
            recordOverlay.startRecording(
                region, root.pendingRecordFormat,
                root.pendingRecordAudioOut, root.pendingRecordAudioIn,
                root.pendingRecordCursor, 0, 0, screen
            )
        }
    }
    Timer {
        id: launchRegionSelector
        interval: 220; repeat: false
        property var targetScreen: null
        onTriggered: regionSelector.show(targetScreen)
    }
    function _dispatchPendingTool() {
        switch (root.pendingTool) {
            case "ocr":      launchOcr.start();      break
            case "qr":       launchQr.start();       break
            case "lens":     launchLens.start();     break
            case "annotate": launchAnnotate.start(); break
            case "pin":      launchPin.start();      break
            case "palette":  launchPalette.start();  break
            case "record":   launchRecord.start();   break
            default:
                Logger.w("ScreenToolkit", "unknown pendingTool: " + root.pendingTool)
                root.isRunning = false
        }
    }
    function copyToClipboard(text) {
        if (!text || text === "") return
        clipProc.exec({ command: ["bash", "-c",
            "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function closeThenLaunch(timer) {
        if (!pluginApi) { timer.start(); return }
        pluginApi.withCurrentScreen(screen => {
            if (timer === launchRegionSelector) launchRegionSelector.targetScreen = screen
            pluginApi.closePanel(screen)
            timer.start()
        })
    }
    function runTranslate(text, targetLang) {
        if (!text || text === "" || translateProc.isTranslating) return
        translateProc.isTranslating = true
        root.translateResult = ""
        translateProc.exec({ command: ["bash", "-c",
            "trans -brief -to " + targetLang + " " + U.shellEscape(text)] })
    }
    function runColorPicker() {
        if (root.isRunning) return
        root.isRunning        = true
        root.activeTool       = ""
        root.resultHex        = ""
        root.resultRgb        = ""
        root.resultHsv        = ""
        root.resultHsl        = ""
        root.colorCapturePath = ""
        root.colorCacheBust   = 0
        closeThenLaunch(launchColorPicker)
    }
    function runOcr(langStr) {
        if (root.isRunning) return
        root.pendingLangStr = (langStr && langStr !== "") ? langStr : "eng"
        _runSlurpTool("ocr")
    }
    function runQr()       { _runSlurpTool("qr")      }
    function runLens()     { _runSlurpTool("lens")     }
    function runAnnotate() { _runSlurpTool("annotate") }
    function _findScreenForPoint(gx, gy) {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
                return s
        }
        return root._regionScreen ?? (screens.length > 0 ? screens[0] : null)
    }
    function runAnnotateFullscreen() {
        if (root.isRunning) return
        root.isRunning = true
        if (!pluginApi) { launchAnnotateFullscreen.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            root._regionScreen = screen
            root._regionX = 0; root._regionY = 0
            root._regionW = Math.round(screen.width  * (screen.devicePixelRatio ?? 1.0))
            root._regionH = Math.round(screen.height * (screen.devicePixelRatio ?? 1.0))
            annotateRegionState._pendingRegion = "0,0 " + screen.width + "x" + screen.height
            annotateRegionState._pendingScreen = screen
            launchAnnotateFullscreen.targetScreen = screen
            launchAnnotateFullscreen.start()
        })
    }
    function runAnnotateActiveWindow() {
        if (root.isRunning) return
        root.isRunning = true
        if (!pluginApi) { launchAnnotateActiveWindow.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            root._regionScreen = screen
            launchAnnotateActiveWindow.start()
        })
    }
    function runPalette() {
        if (root.isRunning) return
        if (pluginApi) { pluginApi.pluginSettings.paletteColors = []; pluginApi.saveSettings() }
        root.paletteColors = []
        _runSlurpTool("palette")
    }
    function runPin() { _runSlurpTool("pin") }
    function runPinFromFile() {
        if (!pluginApi) { launchPinFile.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            launchPinFile.start()
        })
    }
    function pinFile(path, screen) {
        if (!path || path === "") return
        pinOverlay.addPin(path, 600, 400, screen)
    }
    function runMeasure() {
        if (root.isRunning) return
        root.activeTool = "measure"
        if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen))
        measureOverlay.show()
    }
    function runRecordStop()    { recordOverlay.stopRecording() }
    function runRecordSave()    { recordOverlay._saveToFile() }
    function runRecordDiscard() {
        var screen = recordOverlay._primaryScreen
        recordOverlay.dismiss()
    }
    function runRecord(format, audioOut, audioIn, cursor) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        root.pendingRecordCursor   = cursor   === true
        _runSlurpTool("record")
    }
    function runRecordFullscreen(format, audioOut, audioIn, cursor) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        root.pendingRecordCursor   = cursor   === true
        if (!pluginApi) { launchRecordFullscreen.start(); return }
        pluginApi.withCurrentScreen(screen => {
            root.isRunning  = true
            root.activeTool = "record"
            pluginApi.closePanel(screen)
            launchRecordFullscreen.targetScreen = screen
            launchRecordFullscreen.start()
        })
    }
    function runMirror() {
        if (pluginApi) {
            pluginApi.withCurrentScreen(screen => {
                pluginApi.closePanel(screen)
                if (!mirrorOverlay.isVisible)
                    mirrorOverlay.show(screen)
            })
        } else {
            if (!mirrorOverlay.isVisible) mirrorOverlay.show()
        }
    }
    function runMirrorClose() {
        mirrorOverlay.hide()
    }
    function _runSlurpTool(tool) {
        if (root.isRunning) return
        root.pendingTool = tool
        root.isRunning   = true
        closeThenLaunch(launchRegionSelector)
    }
    function detectCapabilities() {
        root._detectedLangs = []
        detectLangsProc.exec({ command:    ["bash", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"] })
        detectTransProc.exec({ command:    ["bash", "-c", "which trans 2>/dev/null"] })
        detectRecorderProc.exec({ command: ["bash", "-c", "which wl-screenrec 2>/dev/null || which wf-recorder 2>/dev/null"] })
    }
    function annotateScreenshotCmd(overlayTmpFile) {
        var dir   = U.screenshotDir(root._home, pluginApi?.pluginSettings?.screenshotPath)
        var fname = U.buildFilename("annotate", ".png", pluginApi?.pluginSettings?.filenameFormat)
        var dest  = dir + "/" + fname
        return "mkdir -p " + U.shellEscape(dir) + " && " +
               "magick /tmp/screen-toolkit-annotate.png " + U.shellEscape(overlayTmpFile) +
               " -composite " + U.shellEscape(dest) + " && " +
               "rm -f " + U.shellEscape(overlayTmpFile) + " && " +
               "echo " + U.shellEscape(dest)
    }
    function annotateScreenshotZoomCmd(imgPath) {
        var dir   = U.screenshotDir(root._home, pluginApi?.pluginSettings?.screenshotPath)
        var fname = U.buildFilename("annotate", ".png", pluginApi?.pluginSettings?.filenameFormat)
        var dest  = dir + "/" + fname
        return "mkdir -p " + U.shellEscape(dir) + " && " +
               "cp " + U.shellEscape(imgPath) + " " + U.shellEscape(dest) + " && " +
               "echo " + U.shellEscape(dest)
    }
    IpcHandler {
        target: "plugin:screen-toolkit"
        function toggle()              { if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen)) }
        function mirror()              { root.runMirror() }
        function measure()             { root.runMeasure() }
        function colorPicker()         { root.runColorPicker() }
        function annotate()            { root.runAnnotate() }
        function annotateFullscreen()  { root.runAnnotateFullscreen() }
        function annotateWindow()      { if (root.isHyprland) root.runAnnotateActiveWindow() }
        function pin()                 { root.runPin() }
        function pinImage()            { root.runPinFromFile() }
        function ocr()                 { root.runOcr(pluginApi?.pluginSettings?.selectedOcrLang || "eng") }
        function qr()                  { root.runQr() }
        function palette()             { root.runPalette() }
        function lens()                { root.runLens() }
        function record()              { root.runRecord("gif") }
        function recordMp4()           { root.runRecord("mp4") }
        function recordFullscreen()    { root.runRecordFullscreen("gif") }
        function recordFullscreenMp4() { root.runRecordFullscreen("mp4") }
        function recordStop()          { if (recordOverlay.isRecording) recordOverlay.stopRecording() }
    }
}


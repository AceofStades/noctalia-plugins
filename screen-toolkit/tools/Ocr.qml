import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
    id: root
    property var    pluginApi:  null
    property string scriptsDir: ""

    property string ocrResult:      ""
    property string ocrCapturePath: ""
    property string translateResult: ""

    property bool isTranslating: false

    signal done()
    signal failed()

    function run(grimX, grimY, grimW, grimH, langStr) {
        var area        = grimW * grimH
        var upscale     = grimH < 30 ? "-resize 400%" : (area < 50000 || grimW < 200) ? "-resize 200%" : ""
        var aspectRatio = grimW / Math.max(grimH, 1)
        var psm         = aspectRatio > 8 ? "7" : area < 60000 ? "6" : grimH < 40 ? "7" : "3"
        ocrProc.exec({ command: [
            root.scriptsDir + "ocr.sh",
            String(grimX), String(grimY), String(grimW), String(grimH),
            langStr || "eng",
            upscale,
            psm
        ]})
    }

    function runTranslate(text, targetLang) {
        if (!text || text === "" || root.isTranslating) return
        root.isTranslating   = true
        root.translateResult = ""
        translateProc.exec({ command: ["bash", "-c",
            "trans -brief -to " + targetLang + " '" + text.replace(/'/g, "'\\''") + "'"
        ]})
    }

    function clearResults() {
        root.ocrResult      = ""
        root.ocrCapturePath = ""
        root.translateResult = ""
    }

    function loadState(s) {
        if ((s.ocrResult ?? "") === "") return
        root.ocrResult      = s.ocrResult
        root.ocrCapturePath = s.ocrCapturePath ?? ""
    }

    Process {
        id: ocrProc
        stdout: StdioCollector {}
        onExited: {
            var text = ocrProc.stdout.text.trim()
            if (text === "") { root.failed(); return }

            root.ocrResult       = text
            root.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
            root.translateResult = ""

            if (root.pluginApi) {
                root.pluginApi.pluginSettings.ocrResult       = text
                root.pluginApi.pluginSettings.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
                root.pluginApi.pluginSettings.translateResult = ""
                root.pluginApi.saveSettings()
            }

            root.done()
        }
    }

    Process {
        id: translateProc
        stdout: StdioCollector {}
        onExited: {
            root.isTranslating   = false
            var result           = translateProc.stdout.text.trim()
            root.translateResult = result !== ""
                ? result : root.pluginApi?.tr("messages.translate-failed")
        }
    }
}

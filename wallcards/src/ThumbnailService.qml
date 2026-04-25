import "Utils.js" as Utils
import QtQuick
import Quickshell.Io
import Qt.labs.folderlistmodel

Item {
  id: service

  required property string cacheDir
  required property var imageFilter
  required property var videoFilter
  required property string wallpaperDir
  property var colorOrder: ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]
  property var colorOrderColors: ["#FF4500", "#FFA500", "#FFD700", "#32CD32", "#1E90FF", "#8A2BE2", "#FF69B4", "#A9A9A9"]
  property int fileCount: files.length
  property var files: []
  property bool loading: true
  property int pendingProcesses: 0
  property int thumbnailRevision: 0

  signal ready

  FolderListModel {
    id: thumbnailModel

    folder: service.wallpaperDir ? Qt.resolvedUrl("file://" + service.wallpaperDir) : ""
    nameFilters: Utils.nameFilters(service.imageFilter, service.videoFilter)
    showDirs: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        service.createThumbnails();
        filesModel.running = true;
      }
    }
  }

  function createThumbnails() {
    var proc = processComponent.createObject(null, {
      command: ["mkdir", "-p", cacheDir]
    });
    proc.running = true;

    var items = [];
    for (var i = 0; i < thumbnailModel.count; i++) {
      (function (idx) {
          var filePath = thumbnailModel.get(idx, "filePath");
          var fileName = thumbnailModel.get(idx, "fileName");
          var thumbnailPath = cacheDir + "/" + fileName;

          var thumbnailCmd = Utils.isVideo(fileName, service.videoFilter)
            ? videoToThumnailCmd(filePath, thumbnailPath)
            : imageToThumbnailCmd(filePath, thumbnailPath);
          var hexCmd = thumbnailHexValueCmd(thumbnailPath);

          const script = `
            [ -f ${thumbnailPath}* ] && exit 0
            ${thumbnailCmd}
            mv ${thumbnailPath} ${thumbnailPath}__x$(${hexCmd})
          `;

          service.pendingProcesses++;
          var proc = processComponent.createObject(null, {
            command: ["bash", "-c", script]
          });

          proc.exited.connect(function () {
            service.pendingProcesses--;
            service.thumbnailRevision++;

            if (service.pendingProcesses === 0) {
              filesModel.starting;
            }

            proc.destroy();
          });

          proc.running = true;
          items.push({});
        })(i);
    }

    if (thumbnailModel.count === 0) {
      service.loading = false;
    }

    files = items;
  }

  function imageToThumbnailCmd(filePath, thumbnailPath) {
    return `magick ${filePath} \
      -resize x500 \
      -quality 95 \
      ${thumbnailPath}
    `;
  }

  function videoToThumnailCmd(filePath, thumbnailPath) {
    return `ffmpeg -y -i \
      ${filePath} \
      -vf select=eq(n\\,0),scale=-1:1080 \
      -frames:v 1 \
      -q:v 2 \
      ${thumbnailPath} </dev/null 2>/dev/null`;
  }

  function thumbnailHexValueCmd(thumbnailPath) {
    return `magick ${thumbnailPath} -modulate 100,200 \
      -resize "1x1^" \
      -gravity center \
      -extent 1x1 \
      -depth 8 \
      -format "%[hex:p{0,0}]" info:- 2>/dev/null \
      | grep -oE '[0-9A-Fa-f]{6}' \
      | head -n 1`;
  }

  FolderListModel {
    id: filesModel

    nameFilters: ["*__x*"]
    showDirs: false
    sortField: FolderListModel.Name

    property bool running: false

    onRunningChanged: {
      folder = running ? Qt.resolvedUrl("file://" + service.cacheDir) : "";
    }

    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        service.buildFileList();
      }
    }
  }

  function buildFileList() {
    var items = [];

    for (let i = 0; i < filesModel.count; i++) {
      const filePath = filesModel.get(i, "filePath");
      const fileName = filesModel.get(i, "fileName").substring(0, filePath.lastIndexOf("_x"));

      const idx = fileName.lastIndexOf("__x");
      const wallpaperName = fileName.substring(0, idx);
      const hexColor = fileName.substring(idx + 2);
      const filterColor = getFilterColor(hexColor);

      items.push({
        fileName: wallpaperName,
        filePath: wallpaperDir + "/" + wallpaperName,
        thumbnail: filePath,
        hexCode: hexColor,
        filterColor: getFilterColor(hexColor),
        isVideo: Utils.isVideo(wallpaperName, service.videoFilter)
      });
    }

    items.sort((a, b) => colorOrder.indexOf(a.filterColor) - colorOrder.indexOf(b.filterColor));

    files = items;
    service.loading = false;
    service.ready();
  }

  function getFilterColor(hexColor) {
    if (!hexColor)
      return "Monochrome";

    const cleaned = String(hexColor).trim().replace(/x/g, '').substring(0, 6);
    console.log(cleaned);
    if (cleaned.length !== 6)
      return "Monochrome";

    const r = parseInt(cleaned.substring(0, 2), 16) / 255;
    const g = parseInt(cleaned.substring(2, 4), 16) / 255;
    const b = parseInt(cleaned.substring(4, 6), 16) / 255;
    if ([r, g, b].some(isNaN))
      return "Monochrome";

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const d = max - min;

    let h = 0;
    let s = max === 0 ? 0 : d / max;
    let v = max;

    if (d !== 0) {
      if (max === r)
        h = (g - b) / d + (g < b ? 6 : 0);
      else if (max === g)
        h = (b - r) / d + 2;
      else
        h = (r - g) / d + 4;
      h = (h / 6) * 360;
    }

    if (s < 0.05 || v < 0.08)
      return "Monochrome";
    if (h >= 345 || h < 15)
      return "Red";
    if (h < 45)
      return "Orange";
    if (h < 75)
      return "Yellow";
    if (h < 165)
      return "Green";
    if (h < 260)
      return "Blue";
    if (h < 315)
      return "Purple";
    if (h < 345)
      return "Pink";

    return "Monochrome";
  }

  Component {
    id: processComponent

    Process {}
  }
}

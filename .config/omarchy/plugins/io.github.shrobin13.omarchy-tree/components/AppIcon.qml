import QtQuick
import Quickshell
import qs.Commons

Item {
  id: iconRoot
  property string appClass: ""
  property color accentColor: Color.accent
  width: 16
  height: 16

  readonly property string iconSource: {
    if (!appClass) return ""
    var path = Quickshell.iconPath(appClass.toLowerCase(), true)
    if (path && path.length > 0) return path.charAt(0) === "/" ? ("file://" + path) : path
    // Strip common reverse-DNS prefixes (e.g. org.gnome.Nautilus -> nautilus, com.microsoft.VSCode -> vscode)
    var parts = appClass.split(".")
    var last = parts[parts.length - 1].toLowerCase()
    path = Quickshell.iconPath(last, true)
    if (path && path.length > 0) return path.charAt(0) === "/" ? ("file://" + path) : path
    return ""
  }

  Image {
    id: img
    anchors.fill: parent
    source: iconRoot.iconSource
    sourceSize.width: 16
    sourceSize.height: 16
    visible: status === Image.Ready && source != ""
    smooth: true
  }

  // Two-letter monogram fallback per brief §7
  Rectangle {
    anchors.fill: parent
    visible: !img.visible
    radius: 4
    color: Qt.rgba(iconRoot.accentColor.r, iconRoot.accentColor.g, iconRoot.accentColor.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(iconRoot.accentColor.r, iconRoot.accentColor.g, iconRoot.accentColor.b, 0.4)

    Text {
      anchors.centerIn: parent
      text: (iconRoot.appClass ? iconRoot.appClass.substring(0, 2).toUpperCase() : "??")
      font.pixelSize: 8
      font.weight: 600
      font.family: "monospace"
      color: iconRoot.accentColor
    }
  }
}

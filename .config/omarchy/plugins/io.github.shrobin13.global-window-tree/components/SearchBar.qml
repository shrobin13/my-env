import QtQuick
import qs.Commons

Rectangle {
  id: searchBarRoot

  property bool searchMode: false
  property string searchText: ""
  property int matchCount: 0
  property color accentColor: Color.accent

  signal searchActivated()
  signal searchEscaped()
  signal searchSubmitted()
  signal nextMatchRequested()
  signal prevMatchRequested()

  width: parent.width
  height: 44
  radius: 22

  color: searchMode
    ? Qt.rgba(1, 1, 1, 0.07)
    : Qt.rgba(1, 1, 1, 0.055)

  border.width: searchMode ? 1 : 0
  border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.38)

  function forceFocus() {
    inputField.forceActiveFocus()
    inputField.cursorPosition = inputField.text.length
  }

  onSearchTextChanged: {
    if (inputField.text !== searchText) {
      inputField.text = searchText
    }
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 18
    anchors.rightMargin: 16
    spacing: 12
    anchors.verticalCenter: parent.verticalCenter

    // Magnifying glass icon
    Canvas {
      id: searchIcon
      width: 16
      height: 16
      anchors.verticalCenter: parent.verticalCenter
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = searchBarRoot.searchMode
          ? searchBarRoot.accentColor
          : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        ctx.lineWidth = 1.4
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(6.5, 6.5, 4.5, 0, Math.PI * 2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(10, 10)
        ctx.lineTo(13.5, 13.5)
        ctx.stroke()
      }
      Connections {
        target: searchBarRoot
        function onSearchModeChanged() { searchIcon.requestPaint() }
      }
    }

    // Slash prefix
    Text {
      textFormat: Text.PlainText
      text: "/"
      font.pixelSize: 15
      font.weight: 600
      font.family: "monospace"
      color: searchBarRoot.accentColor
      anchors.verticalCenter: parent.verticalCenter
    }

    // Input / Placeholder area
    Item {
      id: inputContainer
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      width: parent.width - searchIcon.width - 24 - escBadge.width - (matchBadge.visible ? matchBadge.width + 12 : 0) - 24

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !searchBarRoot.searchMode && searchBarRoot.searchText.length === 0
        text: "filter windows"
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        font.pixelSize: 14
        font.family: "monospace"
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !searchBarRoot.searchMode && searchBarRoot.searchText.length > 0
        text: searchBarRoot.searchText
        color: Color.foreground
        font.pixelSize: 14
        font.family: "monospace"
      }

      TextInput {
        id: inputField
        anchors.fill: parent
        verticalAlignment: TextInput.AlignVCenter
        visible: searchBarRoot.searchMode
        text: searchBarRoot.searchText
        color: Color.foreground
        font.pixelSize: 14
        font.family: "monospace"
        clip: true
        activeFocusOnTab: false

        onTextChanged: {
          searchBarRoot.searchText = text
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            searchBarRoot.searchEscaped()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            searchBarRoot.searchSubmitted()
            event.accepted = true
          } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
            searchBarRoot.nextMatchRequested()
            event.accepted = true
          } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            searchBarRoot.prevMatchRequested()
            event.accepted = true
          }
        }
      }
    }

    // Match count badge
    Item {
      id: matchBadge
      width: matchCountText.implicitWidth
      height: parent.height
      anchors.verticalCenter: parent.verticalCenter
      visible: searchBarRoot.searchText.length > 0

      Text {
        id: matchCountText
        anchors.verticalCenter: parent.verticalCenter
        text: searchBarRoot.matchCount === 1 ? "1 match" : (searchBarRoot.matchCount + " matches")
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        font.pixelSize: 12
        font.family: "sans-serif"
      }
    }

    // Esc keycap badge
    Rectangle {
      id: escBadge
      anchors.verticalCenter: parent.verticalCenter
      width: escText.implicitWidth + 16
      height: 22
      radius: 6
      color: Qt.rgba(255, 255, 255, 0.08)

      Text {
        id: escText
        anchors.centerIn: parent
        text: "esc"
        font.pixelSize: 11
        font.weight: 500
        font.family: "monospace"
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    visible: !searchBarRoot.searchMode
    onClicked: searchBarRoot.searchActivated()
  }
}

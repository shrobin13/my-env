import QtQuick

Rectangle {
  property color topColor: Qt.rgba(1, 1, 1, 0.7)
  property color bottomColor: Qt.rgba(1, 1, 1, 0.1)
  width: 2
  gradient: Gradient {
    GradientStop { position: 0.0; color: topColor }
    GradientStop { position: 1.0; color: bottomColor }
  }
}

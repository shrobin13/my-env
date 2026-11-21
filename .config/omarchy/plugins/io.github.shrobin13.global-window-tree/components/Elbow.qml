import QtQuick

Canvas {
  id: elbowCanvas
  property color strokeColor: Qt.rgba(1, 1, 1, 0.35)
  property real strokeWidth: 1.5
  property real radius: 10
  width: 17
  height: 19

  onStrokeColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.lineWidth = strokeWidth
    ctx.strokeStyle = strokeColor
    ctx.lineCap = "round"
    ctx.beginPath()
    ctx.moveTo(1, 0)
    var r = Math.min(radius, width - 2, height - 2)
    ctx.lineTo(1, height - r)
    ctx.arcTo(1, height - 1, r + 1, height - 1, r)
    ctx.lineTo(width, height - 1)
    ctx.stroke()
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.ol4vr.omacapy"
  ipcTarget: "io.github.ol4vr.omacapy"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string stateDir: stateHome + "/omarchy"
  readonly property string statePath: stateDir + "/omacapy.json"

  property var capy: Model.defaultState(Date.now())
  property real loadAvg: 0
  property real loadRatio: 0
  property int logicalCpuCount: 1
  property bool hydrateDone: false
  property int cursorIndex: 0
  property bool cursorActive: false
  property bool actionPop: false
  property real heroScale: 1
  property real heroSpin: 0
  property real toastOpacity: 0
  property string toastText: ""
  property string shownWisdom: ""
  property real wisdomOpacity: 0
  property var particles: []
  property int particleSeq: 0
  property real loungeOpacity: 0
  property real loungeSlide: 8

  readonly property var meta: Model.moodMeta(capy.mood)
  readonly property var meters: Model.meters(capy)
  readonly property var actions: Model.actions()
  readonly property string rank: Model.bondRank(capy.bond)
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.45)
  readonly property color moodColor: capy.mood === "fried"
    ? (bar ? bar.urgent : Color.urgent)
    : Color.accent
  function persist() {
    if (!hydrateDone) return
    stateFile.setText(Model.serializeState(capy))
  }

  function applyCpuOnline(raw) {
    logicalCpuCount = Model.parseCpuCount(raw)
    loadRatio = Model.normalizeLoad(loadAvg, logicalCpuCount)
  }

  function applyLoad(raw) {
    loadAvg = Model.parseLoad(raw)
    loadRatio = Model.normalizeLoad(loadAvg, logicalCpuCount)
  }

  function refreshLoad() {
    cpuOnlineFile.reload()
    loadFile.reload()
  }

  function runTick() {
    capy = Model.tick(capy, loadRatio, Date.now())
    if (hydrateDone) persist()
  }

  function showToast(text) {
    toastText = text || ""
    toastOpacity = toastText !== "" ? 1 : 0
    if (toastText !== "")
      toastFade.restart()
  }

  function burstColor(actionId) {
    if (actionId === "pet") return "#E8C9A0"
    if (actionId === "orange") return "#F08A24"
    if (actionId === "soak") return "#7EC8E3"
    return ""
  }

  function spawnParticles(actionId) {
    var tint = burstColor(actionId)
    var next = []
    var i
    for (i = 0; i < 7; i++) {
      particleSeq += 1
      next.push({
        id: particleSeq,
        x: 24 + i * 18,
        delay: i * 35,
        size: 5,
        drift: i % 2 === 0 ? -10 : 12,
        tint: tint,
      })
    }
    particles = next
    particleClear.restart()
  }

  function playActionMotion(actionId) {
    actionPop = true
    if (actionId === "pet") {
      heroScale = 1.12
      heroSpin = -4
    } else if (actionId === "orange") {
      heroScale = 1.10
      heroSpin = -8
    } else if (actionId === "soak") {
      heroScale = 1.08
      heroSpin = 3
    } else if (actionId === "wisdom") {
      heroScale = 1.10
      heroSpin = 8
    } else {
      heroScale = 1.08
      heroSpin = 0
    }
    popBack.restart()
    spawnParticles(actionId)
  }

  function flashWisdom(line) {
    shownWisdom = line || ""
    wisdomOpacity = shownWisdom !== "" ? 1 : 0
  }

  function doAction(id) {
    var ts = Date.now()
    if (id === "pet") capy = Model.pet(capy, loadRatio, ts)
    else if (id === "orange") capy = Model.orange(capy, loadRatio, ts)
    else if (id === "soak") capy = Model.soak(capy, loadRatio, ts)
    else if (id === "wisdom") capy = Model.wisdom(capy, loadRatio, ts)
    else return
    persist()
    if (id === "wisdom") flashWisdom(capy.lastWisdom || "")
    else flashWisdom("")
    showToast(capy.toast || "")
    playActionMotion(id)
  }

  function selectByDelta(dx, dy) {
    var n = actions.length
    if (!n) return
    var cols = 2
    var i = Math.max(0, Math.min(n - 1, cursorIndex))
    var col = i % cols
    var row = Math.floor(i / cols)
    var rows = Math.ceil(n / cols)
    col = Math.max(0, Math.min(cols - 1, col + (dx || 0)))
    row = Math.max(0, Math.min(rows - 1, row + (dy || 0)))
    var next = row * cols + col
    cursorIndex = Math.max(0, Math.min(n - 1, next))
  }

  function activateSelected() {
    if (cursorIndex < 0 || cursorIndex >= actions.length) return
    doAction(actions[cursorIndex].id)
  }

  function handleTextKey(text) {
    var id = Model.textKeyAction(text)
    if (!id) return
    var i
    for (i = 0; i < actions.length; i++) {
      if (actions[i].id === id) {
        cursorActive = true
        cursorIndex = i
        break
      }
    }
    doAction(id)
  }

  onOpenedChanged: {
    if (opened) {
      refreshLoad()
      runTick()
      cursorActive = false
      cursorIndex = 0
      heroScale = 1
      heroSpin = 0
      loungeOpacity = 0
      loungeSlide = 8
      flashWisdom(capy.lastAction === "wisdom" ? (capy.lastWisdom || "") : "")
      openAnim.restart()
    } else {
      loungeOpacity = 0
    }
  }

  Component.onCompleted: {
    mkdirProc.running = true
    refreshLoad()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: Qt.callLater(function() { stateFile.reload() })
  }

  FileView {
    id: cpuOnlineFile
    path: "/sys/devices/system/cpu/online"
    watchChanges: false
    printErrors: false
    onLoaded: root.applyCpuOnline(text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    watchChanges: false
    printErrors: false
    onLoaded: root.applyLoad(text())
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.hydrateDone) return
      root.capy = Model.parseState(text(), Date.now())
      root.hydrateDone = true
      root.runTick()
    }
    onLoadFailed: {
      if (root.hydrateDone) return
      root.capy = Model.defaultState(Date.now())
      root.hydrateDone = true
      root.persist()
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: {
      root.refreshLoad()
      root.runTick()
    }
  }

  Timer {
    id: popBack
    interval: 340
    running: false
    repeat: false
    onTriggered: {
      root.heroScale = 1
      root.heroSpin = 0
      root.actionPop = false
    }
  }

  Timer {
    id: toastFade
    interval: 2200
    running: false
    repeat: false
    onTriggered: root.toastOpacity = 0
  }

  Timer {
    id: particleClear
    interval: 980
    running: false
    repeat: false
    onTriggered: root.particles = []
  }

  SequentialAnimation {
    id: openAnim
    ParallelAnimation {
      NumberAnimation { target: root; property: "loungeOpacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "loungeSlide"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }
  }

  Behavior on heroScale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  Behavior on heroSpin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on toastOpacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on wisdomOpacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.meta.bar
    labelVisible: false
    active: root.capy.mood === "lonely" || root.capy.mood === "fried" || root.capy.mood === "hyped" || root.actionPop
    useActiveColor: root.capy.mood === "lonely" || root.capy.mood === "fried" || root.actionPop
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(58)
    fixedHeight: root.bar && root.bar.vertical ? Style.space(36) : -1
    horizontalMargin: 6
    tooltipText: Model.tooltip(root.capy, root.loadRatio)
    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        root.doAction("pet")
        return
      }
      if (b === Qt.RightButton) {
        root.doAction("wisdom")
        return
      }
      root.toggle()
    }
    onWheelMoved: function(delta) {
      if (delta > 0) root.doAction("pet")
      else root.doAction("orange")
    }

    Row {
      anchors.centerIn: parent
      spacing: Style.space(5)
      CapyFace {
        faceSize: Style.space(16)
        mood: root.capy.mood
        popped: root.actionPop
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        visible: !(root.bar && root.bar.vertical)
        text: root.meta.bar
        color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        root.selectByDelta(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { root.handleTextKey(t) }

      Flickable {
        id: loungeScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: loungeScroll.width
          spacing: Style.space(10)
          opacity: root.loungeOpacity
          y: root.loungeSlide

          Item {
            width: parent.width
            height: Math.max(heroFace.height, heroCopy.height)

            Repeater {
              model: root.particles
              delegate: Rectangle {
                required property var modelData
                width: modelData.size
                height: modelData.size
                radius: modelData.size / 2
                color: modelData.tint !== "" ? modelData.tint : Color.accent
                opacity: 0
                x: modelData.x
                y: 28

                SequentialAnimation on opacity {
                  running: true
                  PauseAnimation { duration: modelData.delay }
                  NumberAnimation { from: 0; to: 0.9; duration: 80 }
                  NumberAnimation { from: 0.9; to: 0; duration: 520; easing.type: Easing.InQuad }
                }
                SequentialAnimation on y {
                  running: true
                  PauseAnimation { duration: modelData.delay }
                  NumberAnimation { from: 36; to: 2; duration: 620; easing.type: Easing.OutCubic }
                }
                SequentialAnimation on x {
                  running: true
                  PauseAnimation { duration: modelData.delay }
                  NumberAnimation { from: modelData.x; to: modelData.x + modelData.drift; duration: 620 }
                }
              }
            }

            CapyFace {
              id: heroFace
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              faceSize: Style.space(72)
              mood: root.capy.mood
              popped: root.actionPop
              scale: root.heroScale
              rotation: root.heroSpin
              transformOrigin: Item.Center
            }

            Column {
              id: heroCopy
              anchors.left: heroFace.right
              anchors.leftMargin: Style.space(12)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(5)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "OmaCapy"
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.meta.title.toUpperCase()
                  color: root.moodColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.1
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                width: parent.width
                text: root.rank + "  ·  LOAD " + Model.loadPercent(root.loadRatio) + "%"
                  + (Model.lastActionLine(root.capy) !== "" ? "  ·  " + Model.lastActionLine(root.capy) : "")
                color: root.dim
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Repeater {
                model: root.meters
                delegate: Item {
                  required property var modelData
                  width: heroCopy.width
                  height: Style.space(14)

                  Text {
                    id: meterLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label.toUpperCase()
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.letterSpacing: 0.6
                  }

                  Text {
                    id: meterValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(modelData.value) + "%"
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  Rectangle {
                    anchors.left: meterLabel.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: meterValue.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(4)
                    radius: height / 2
                    color: Style.selectedFillFor(root.fg, Color.accent)

                    Rectangle {
                      width: parent.width * (modelData.value / 100)
                      height: parent.height
                      radius: parent.radius
                      color: Color.accent
                      Behavior on width {
                        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                      }
                    }
                  }
                }
              }
            }
          }

          Grid {
            id: careGrid
            width: parent.width
            columns: 2
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)

            Repeater {
              model: root.actions
              delegate: Item {
                required property var modelData
                required property int index
                width: (careGrid.width - careGrid.columnSpacing) / 2
                height: Style.space(36)

                Button {
                  anchors.fill: parent
                  text: Model.actionButtonLabel(root.capy, modelData)
                  tooltipText: Model.actionTooltip(modelData)
                  bordered: true
                  selected: root.capy.lastAction === modelData.id
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorActive && root.cursorIndex === index
                  onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = index } }
                  onClicked: root.doAction(modelData.id)
                }
              }
            }
          }

          Item {
            width: parent.width
            height: visible ? feedbackBox.height : 0
            visible: root.shownWisdom !== "" || (root.toastText !== "" && root.toastOpacity > 0)

            Rectangle {
              id: feedbackBox
              width: parent.width
              height: feedbackText.implicitHeight + Style.space(14)
              radius: Style.cornerRadius
              color: Style.selectedFillFor(root.fg, Color.accent)
              opacity: root.shownWisdom !== "" ? root.wisdomOpacity : root.toastOpacity

              Text {
                id: feedbackText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                text: root.shownWisdom !== "" ? root.shownWisdom : root.toastText
                color: root.fg
                wrapMode: Text.WordWrap
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

        }
      }
    }
  }
}

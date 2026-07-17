import Quickshell
  import Quickshell.Io
  import Quickshell.Wayland
  import QtQuick
  import QtQuick.Controls

  ShellRoot {
      id: root

      property bool startOpen: false
      readonly property string uiFont: "Noto Sans"
      property var allApps: []
      property bool showingAllApps: false
      property bool quickSettingsOpen: false
      property bool wifiDetailsOpen: false
      property bool bluetoothDetailsOpen: false
      property bool settingsDetailsOpen: false
      property bool calendarOpen: false
      property bool notificationsOpen: false
      property bool powerOpen: false
      property bool trayOpen: false
      property bool doNotDisturb: false
      property int calendarMonth: currentTime.getMonth()
      property int calendarYear: currentTime.getFullYear()
      readonly property var calendarMonths: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
      readonly property var calendarWeekdays: ["S", "M", "T", "W", "T", "F", "S"]
      property string wifiInterface: ""
      property string wifiConnected: ""
      property date currentTime: new Date()
      property var runningClasses: []
      property string activeClass: ""
      property bool wifiEnabled: false
      property bool bluetoothEnabled: false
      property real outputVolume: 0
      property bool outputMuted: false
      readonly property bool externalTaskbar: Quickshell.env("WINDOWS_TASKBAR") === "waybar"
      readonly property string assetPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/windows11/assets/"

      ListModel { id: wifiModel }
      ListModel { id: bluetoothModel }

      Process {
          id: dndStateLoader
          running: true
          command: ["/bin/bash", "-lc", "test -e \"$HOME/.local/state/windows11/do-not-disturb\" && printf true || printf false"]
          stdout: StdioCollector { onStreamFinished: root.doNotDisturb = text.trim() === "true" }
      }

      Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: root.currentTime = new Date()
      }

      Process {
          id: wifiStateLoader
          command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/windows11/wifi_state.py"]

          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const state = JSON.parse(text)
                      root.wifiInterface = state.interface
                      root.wifiEnabled = state.powered
                      root.wifiConnected = state.connected
                      wifiModel.clear()
                      for (let i = 0; i < state.networks.length; i++)
                          wifiModel.append(state.networks[i])
                  } catch (error) {
                      console.log("Could not update Wi-Fi networks:", error)
                  }
              }
          }
      }

      Timer {
          id: wifiRefreshDelay
          interval: 1800
          repeat: false
          onTriggered: root.refreshWifi()
      }

      Timer {
          interval: 4000
          running: root.quickSettingsOpen && root.wifiDetailsOpen
          repeat: true
          onTriggered: root.refreshWifi()
      }

      function refreshWifi() {
          if (!wifiStateLoader.running)
              wifiStateLoader.running = true
      }

      function scanWifi() {
          Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-wifi-action", "scan"])
          wifiRefreshDelay.restart()
      }

      Process {
          id: bluetoothStateLoader
          command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/windows11/bluetooth_state.py"]
          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const state = JSON.parse(text)
                      root.bluetoothEnabled = state.powered
                      bluetoothModel.clear()
                      for (let i = 0; i < state.devices.length; i++)
                          bluetoothModel.append(state.devices[i])
                  } catch (error) {
                      console.log("Could not update Bluetooth devices:", error)
                  }
              }
          }
      }

      Timer {
          id: bluetoothRefreshDelay
          interval: 1800
          repeat: false
          onTriggered: root.refreshBluetooth()
      }

      Timer {
          interval: 4000
          running: root.quickSettingsOpen && root.bluetoothDetailsOpen
          repeat: true
          onTriggered: root.refreshBluetooth()
      }

      function refreshBluetooth() {
          if (!bluetoothStateLoader.running)
              bluetoothStateLoader.running = true
      }

      function scanBluetooth() {
          Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-bluetooth-action", "scan"])
          bluetoothRefreshDelay.restart()
      }

      function openSettingsPage(page) {
          root.settingsDetailsOpen = page === "home"
          root.wifiDetailsOpen = page === "wifi"
          root.bluetoothDetailsOpen = page === "bluetooth"
          if (page === "wifi") { root.refreshWifi(); root.scanWifi() }
          if (page === "bluetooth") { root.refreshBluetooth(); root.scanBluetooth() }
      }

      Process {
          id: quickStateLoader
          running: true
          command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/windows11/quick_state.py"]

          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const state = JSON.parse(text)
                      root.wifiEnabled = state.wifi
                      root.bluetoothEnabled = state.bluetooth
                      root.outputVolume = state.volume
                      root.outputMuted = state.muted
                  } catch (error) {
                      console.log("Could not update quick settings:", error)
                  }
              }
          }
      }

      Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: {
              if (!quickStateLoader.running)
                  quickStateLoader.running = true
          }
      }

      function toggleBluetooth() {
          Quickshell.execDetached(["bluetoothctl", "power", root.bluetoothEnabled ? "off" : "on"])
      }

      function toggleMute() {
          Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
      }

      function setVolume(value) {
          const safeValue = Math.max(0, Math.min(1, value))
          Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", safeValue.toFixed(2)])
      }

      function calendarDay(index) {
          const first = new Date(root.calendarYear, root.calendarMonth, 1).getDay()
          const count = new Date(root.calendarYear, root.calendarMonth + 1, 0).getDate()
          const day = index - first + 1
          return day >= 1 && day <= count ? day : 0
      }

      function calendarIsToday(day) {
          return day > 0
              && day === root.currentTime.getDate()
              && root.calendarMonth === root.currentTime.getMonth()
              && root.calendarYear === root.currentTime.getFullYear()
      }

      function moveCalendarMonth(offset) {
          const changed = new Date(root.calendarYear, root.calendarMonth + offset, 1)
          root.calendarYear = changed.getFullYear()
          root.calendarMonth = changed.getMonth()
      }

      function toggleDoNotDisturb() {
          root.doNotDisturb = !root.doNotDisturb
          Quickshell.execDetached([
              Quickshell.env("HOME") + "/.local/bin/windows-notification-state",
              root.doNotDisturb ? "on" : "off"
          ])
      }

      Process {
          id: taskbarStateLoader
          running: true
          command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/windows11/taskbar_state.py"]

          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const state = JSON.parse(text)
                      root.runningClasses = state.clients
                      root.activeClass = state.active
                  } catch (error) {
                      console.log("Could not update taskbar state:", error)
                  }
              }
          }
      }

      Timer {
          interval: 800
          running: true
          repeat: true
          onTriggered: {
              if (!taskbarStateLoader.running)
                  taskbarStateLoader.running = true
          }
      }

      function classMatches(classes, patterns) {
          const choices = patterns.toLowerCase().split("|")
          return classes.some(windowClass =>
              choices.some(choice => windowClass.includes(choice)))
      }

      function activeMatches(patterns) {
          if (root.activeClass.length === 0)
              return false
          return root.classMatches([root.activeClass], patterns)
      }

      ListModel {
          id: taskbarModel

          ListElement { name: "Search"; icon: "@HOME@/.config/quickshell/windows11/assets/search.svg"; command: ""; match: ""; action: "search" }
          ListElement { name: "Task View"; icon: "@HOME@/.config/quickshell/windows11/assets/taskview.svg"; command: "rofi -show window"; match: ""; action: "launch" }
          ListElement { name: "File Explorer"; icon: "@HOME@/.config/quickshell/windows11/assets/explorer.svg"; command: "thunar"; match: "thunar"; action: "launch" }
          ListElement { name: "Browser"; icon: "@HOME@/.config/quickshell/windows11/assets/browser.svg"; command: "zen-browser"; match: "zen"; action: "launch" }
          ListElement { name: "Discord"; icon: "com.discordapp.Discord"; command: "discord"; match: "discord"; action: "launch" }
      }

      ListModel {
          id: recommendedModel
          ListElement { name: "File Explorer"; detail: "Recently used"; icon: "org.xfce.thunar"; command: "thunar" }
          ListElement { name: "Zen Browser"; detail: "Recently used"; icon: "@HOME@/.config/quickshell/windows11/assets/zen-waybar.png"; command: "zen-browser" }
          ListElement { name: "Discord"; detail: "Recently used"; icon: "com.discordapp.Discord"; command: "discord"; match: "discord" }
          ListElement { name: "Prism Launcher"; detail: "Recently added"; icon: "org.prismlauncher.PrismLauncher"; command: "prismlauncher" }
          ListElement { name: "Volume Control"; detail: "Recently used"; icon: "org.pulseaudio.pavucontrol"; command: "pavucontrol" }
          ListElement { name: "OpenRGB"; detail: "Recently used"; icon: "org.openrgb.OpenRGB"; command: "openrgb" }
      }

      ListModel {
          id: pinnedModel

          ListElement { name: "Zen Browser"; icon: "@HOME@/.config/quickshell/windows11/assets/zen-waybar.png"; command: "zen-browser" }
          ListElement { name: "Firefox"; icon: "firefox"; command: "firefox --name firefox" }
          ListElement { name: "Discord"; icon: "com.discordapp.Discord"; command: "discord"; match: "discord" }
          ListElement { name: "Prism Launcher"; icon: "org.prismlauncher.PrismLauncher"; command: "prismlauncher" }
          ListElement { name: "Sober"; icon: "org.vinegarhq.Sober"; command: "@HOME@/.local/bin/windows-flatpak run org.vinegarhq.Sober" }
          ListElement { name: "File Explorer"; icon: "org.xfce.thunar"; command: "thunar" }
          ListElement { name: "Terminal"; icon: "kitty"; command: "kitty" }
          ListElement { name: "Easy Effects"; icon: "com.github.wwmm.easyeffects"; command: "easyeffects" }
          ListElement { name: "OpenRGB"; icon: "org.openrgb.OpenRGB"; command: "openrgb" }
          ListElement { name: "Input Remapper"; icon: "input-remapper"; command: "input-remapper-gtk" }
          ListElement { name: "Tablet Driver"; icon: "input-remapper"; command: "otd-gui" }
          ListElement { name: "Volume Control"; icon: "org.pulseaudio.pavucontrol"; command: "pavucontrol" }
      }

      ListModel {
          id: appModel
      }

      Process {
          id: appLoader
          running: true
          command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/windows11/apps.py"]

          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      root.allApps = JSON.parse(text)
                      root.filterApps("")
                  } catch (error) {
                      console.log("Could not load applications:", error)
                  }
              }
          }
      }

      function filterApps(query) {
          const words = query.toLowerCase().trim().split(/\\s+/).filter(Boolean)
          appModel.clear()

          for (let i = 0; i < root.allApps.length; i++) {
              const app = root.allApps[i]
              const name = app.name.toLowerCase()
              const matches = words.length === 0
                  || words.every(word => name.includes(word))

              if (matches && (root.showingAllApps || appModel.count < 8))
                  appModel.append(app)
          }

          appList.currentIndex = appModel.count > 0 ? 0 : -1
      }

      function launchApp(command, match) {
          const executor = Quickshell.env("HOME") + "/.local/bin/windows-command-exec"
          if (match && match.length > 0) {
              Quickshell.execDetached([
                  Quickshell.env("HOME") + "/.local/bin/windows-task-action",
                  "activate", match, executor, command
              ])
          } else {
              Quickshell.execDetached(["hyprctl", "dispatch", "exec", "--", executor, command])
          }
          search.text = ""
          root.startOpen = false
      }

      function showAppMenu(name, command, icon, match) {
          Quickshell.execDetached([
              Quickshell.env("HOME") + "/.local/bin/windows-start-app-menu",
              name, command, icon, match || ""
          ])
      }

      function taskbarActivate(item) {
          if (item.action === "search") {
              root.startOpen = true
              root.quickSettingsOpen = false
              search.forceActiveFocus()
          } else if (item.action === "allapps") {
              root.startOpen = true
              root.quickSettingsOpen = false
              root.showAllApps()
          } else {
              root.launchApp(item.command, item.match || "")
          }
      }

      function showAllApps() {
          root.showingAllApps = true
          root.filterApps("")
          search.forceActiveFocus()
      }

      IpcHandler {
          target: "windowsStart"

          function toggle(): void {
              root.startOpen = !root.startOpen
              root.calendarOpen = false
              root.notificationsOpen = false
              root.powerOpen = false
              root.trayOpen = false
          }

          function toggleQuickSettings(): void {
              root.quickSettingsOpen = !root.quickSettingsOpen
              root.startOpen = false
              root.calendarOpen = false
              root.notificationsOpen = false
              root.powerOpen = false
              root.trayOpen = false
              if (!root.quickSettingsOpen)
                  root.wifiDetailsOpen = false
              if (!root.quickSettingsOpen)
                  root.bluetoothDetailsOpen = false
              if (!root.quickSettingsOpen)
                  root.settingsDetailsOpen = false
          }

          function openWifi(): void {
              root.quickSettingsOpen = true
              root.startOpen = false
              root.calendarOpen = false
              root.wifiDetailsOpen = true
              root.refreshWifi()
              root.scanWifi()
          }

          function openBluetooth(): void {
              root.quickSettingsOpen = true
              root.startOpen = false
              root.calendarOpen = false
              root.wifiDetailsOpen = false
              root.bluetoothDetailsOpen = true
              root.refreshBluetooth()
              root.scanBluetooth()
          }

          function openSettings(): void {
              root.quickSettingsOpen = true
              root.startOpen = false
              root.calendarOpen = false
              root.openSettingsPage("home")
          }

          function toggleCalendar(): void {
              root.calendarOpen = !root.calendarOpen
              root.startOpen = false
              root.quickSettingsOpen = false
              root.wifiDetailsOpen = false
              root.bluetoothDetailsOpen = false
              root.settingsDetailsOpen = false
              root.notificationsOpen = false
              root.powerOpen = false
              root.trayOpen = false
              if (root.calendarOpen) {
                  root.calendarMonth = root.currentTime.getMonth()
                  root.calendarYear = root.currentTime.getFullYear()
              }
          }

          function toggleNotifications(): void {
              root.notificationsOpen = !root.notificationsOpen
              root.startOpen = false; root.quickSettingsOpen = false; root.calendarOpen = false
              root.powerOpen = false; root.trayOpen = false
          }

          function togglePower(): void {
              root.powerOpen = !root.powerOpen
              root.startOpen = false; root.quickSettingsOpen = false; root.calendarOpen = false
              root.notificationsOpen = false; root.trayOpen = false
          }

          function toggleTray(): void {
              root.trayOpen = !root.trayOpen
              root.startOpen = false; root.quickSettingsOpen = false; root.calendarOpen = false
              root.notificationsOpen = false; root.powerOpen = false
          }
      }

      // Empty-desktop right click swaps between the two Windows wallpapers.
      // This lives on the background layer, so application context menus keep
      // receiving right clicks normally.
      PanelWindow {
          id: desktopClickSurface
          WlrLayershell.namespace: "windows-desktop-clicks"
          WlrLayershell.layer: WlrLayer.Background
          anchors {
              left: true
              right: true
              top: true
              bottom: true
          }
          exclusiveZone: 0
          color: "transparent"

          MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              onClicked: Quickshell.execDetached([
                  Quickshell.env("HOME") + "/.local/bin/windows-wallpaper-toggle"
              ])
          }
      }

      // Taskbar
      PanelWindow {
          id: taskbar
          visible: !root.externalTaskbar
          WlrLayershell.namespace: "windows-taskbar"
          anchors {
              left: true
              right: true
              bottom: true
          }

          implicitHeight: 48
          color: "#d91b2029"

          Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: 1
              color: "#22ffffff"
          }

          Row {
              anchors.centerIn: parent
              spacing: 2

              Rectangle {
                  width: 44
                  height: 40
                  radius: 5
                  color: root.startOpen
                      ? "#30ffffff"
                      : taskStartMouse.containsMouse ? "#22ffffff" : "transparent"

                  Item {
                      anchors.centerIn: parent
                      width: 22
                      height: 22

                      Rectangle { x: 0; y: 1; width: 10; height: 9; color: "#4cc2ff" }
                      Rectangle { x: 12; y: 0; width: 10; height: 10; color: "#4cc2ff" }
                      Rectangle { x: 0; y: 12; width: 10; height: 9; color: "#4cc2ff" }
                      Rectangle { x: 12; y: 12; width: 10; height: 10; color: "#4cc2ff" }
                  }

                  MouseArea {
                      id: taskStartMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.startOpen = !root.startOpen
                  }
              }

              Repeater {
                  model: taskbarModel

                  delegate: Rectangle {
                      required property int index
                      readonly property var taskData: taskbarModel.get(index)
                      readonly property bool appRunning: taskData.match.length > 0 && root.classMatches(root.runningClasses, taskData.match)
                      readonly property bool appActive: taskData.match.length > 0 && root.activeMatches(taskData.match)

                      width: 44
                      height: 40
                      radius: 4
                      color: taskMouse.containsMouse ? "#22ffffff" : "transparent"

                      Image {
                          anchors.centerIn: parent
                          width: 24
                          height: 24
                          source: taskData.icon.startsWith("/")
                              ? "file://" + taskData.icon
                              : "image://icon/" + taskData.icon
                          sourceSize: Qt.size(56, 56)
                          fillMode: Image.PreserveAspectFit
                          onStatusChanged: {
                              if (status === Image.Error)
                                  source = "image://icon/application-x-executable"
                          }
                      }

                      Rectangle {
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.bottom: parent.bottom
                          anchors.bottomMargin: 2
                          width: appActive ? 16 : 5
                          height: 3
                          radius: 2
                          visible: appRunning
                          color: appActive ? "#60cdff" : "#b8b8b8"

                          Behavior on width {
                              NumberAnimation { duration: 140 }
                          }
                      }

                      MouseArea {
                          id: taskMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: root.taskbarActivate(taskData)
                      }
                  }
              }
          }

          Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: weatherText.width + 18
              height: 40
              radius: 5
              color: weatherMouse.containsMouse ? "#22ffffff" : "transparent"

              Row {
                  id: weatherText
                  anchors.centerIn: parent
                  spacing: 6
                  Image { width: 16; height: 16; source: root.assetPath + "sun.svg" }
                  Text { anchors.verticalCenter: parent.verticalCenter; text: "14°C"; color: "#eeeeee"; font.pixelSize: 12; font.family: root.uiFont }
              }

              MouseArea {
                  id: weatherMouse
                  anchors.fill: parent
                  hoverEnabled: true
              }
          }

          Row {
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Rectangle {
                  width: 76
                  height: 40
                  radius: 5
                  color: trayMouse.containsMouse ? "#22ffffff" : "transparent"

                  Row {
                      anchors.centerIn: parent
                      spacing: 7

                      Image { width: 13; height: 13; source: root.assetPath + "chevron.svg" }
                      Image { width: 16; height: 16; source: root.assetPath + "wifi.svg"; opacity: root.wifiEnabled ? 1 : 0.45 }
                      Image { width: 16; height: 16; source: root.assetPath + "volume.svg"; opacity: root.outputMuted ? 0.45 : 1 }
                  }

                  MouseArea {
                      id: trayMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: {
                          root.quickSettingsOpen = !root.quickSettingsOpen
                          root.startOpen = false
                      }
                  }
              }

              Rectangle {
                  width: 78
                  height: 40
                  radius: 5
                  color: clockMouse.containsMouse ? "#22ffffff" : "transparent"

                  Column {
                      anchors.centerIn: parent
                      spacing: 0

                      Text {
                          anchors.right: parent.right
                          text: Qt.formatDateTime(root.currentTime, "HH:mm")
                          color: "white"
                          font.pixelSize: 11
                          font.family: root.uiFont
                      }

                      Text {
                          anchors.right: parent.right
                          text: Qt.formatDateTime(root.currentTime, "dd.MM.yyyy")
                          color: "white"
                          font.pixelSize: 10
                          font.family: root.uiFont
                      }
                  }

                  MouseArea {
                      id: clockMouse
                      anchors.fill: parent
                      hoverEnabled: true
                  }
              }

              Rectangle {
                  width: 30
                  height: 40
                  radius: 4
                  color: notificationMouse.containsMouse ? "#22ffffff" : "transparent"

                  Image {
                      anchors.centerIn: parent
                      width: 17
                      height: 17
                      source: root.assetPath + "alert.svg"
                  }

                  MouseArea {
                      id: notificationMouse
                      anchors.fill: parent
                      hoverEnabled: true
                  }
              }
          }

          // The narrow Show Desktop target at the extreme right edge.
          Rectangle {
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 6
              color: showDesktopMouse.containsMouse ? "#18ffffff" : "transparent"

              Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 1
                  color: "#26ffffff"
              }

              MouseArea {
                  id: showDesktopMouse
                  anchors.fill: parent
                  hoverEnabled: true
              }
          }
      }

      // Windows 11-style Quick Settings flyout
      PanelWindow {
          id: quickSettings
          visible: root.quickSettingsOpen
          WlrLayershell.namespace: "windows-quick-settings"
          anchors {
              right: true
              bottom: true
          }
          margins {
              right: 10
              bottom: 56
          }
          implicitWidth: 360
          implicitHeight: root.settingsDetailsOpen ? 520 : (root.wifiDetailsOpen || root.bluetoothDetailsOpen) ? 420 : 286
          Behavior on implicitHeight {
              NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
          }
          exclusiveZone: 0
          color: "transparent"

          Rectangle {
              id: quickSettingsSurface
              anchors.fill: parent
              radius: 10
              color: "#aa202631"
              border.width: 1
              border.color: "#38ffffff"
              transformOrigin: Item.BottomRight
              scale: root.quickSettingsOpen ? 1 : 0.88
              opacity: root.quickSettingsOpen ? 1 : 0
              Behavior on scale {
                  NumberAnimation { duration: 260; easing.type: Easing.OutBack }
              }
              Behavior on opacity {
                  NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
              }

              Grid {
                  visible: !root.wifiDetailsOpen && !root.bluetoothDetailsOpen && !root.settingsDetailsOpen
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 18
                  columns: 2
                  spacing: 10

                  Rectangle {
                      width: 151; height: 72; radius: 7
                      color: root.wifiEnabled ? "#60cdff" : "#343a45"
                      Text { anchors.centerIn: parent; text: "⌁\nWi-Fi"; horizontalAlignment: Text.AlignHCenter; color: root.wifiEnabled ? "#101820" : "white"; font.family: root.uiFont; font.pixelSize: 13 }
                      MouseArea {
                          anchors.fill: parent
                          onClicked: {
                              root.wifiDetailsOpen = true
                              root.refreshWifi()
                              root.scanWifi()
                          }
                      }
                  }

                  Rectangle {
                      width: 151; height: 72; radius: 7
                      color: root.bluetoothEnabled ? "#60cdff" : "#343a45"
                      Text { anchors.centerIn: parent; text: "ᛒ\nBluetooth"; horizontalAlignment: Text.AlignHCenter; color: root.bluetoothEnabled ? "#101820" : "white"; font.family: root.uiFont; font.pixelSize: 13 }
                      MouseArea {
                          anchors.fill: parent
                          onClicked: {
                              root.bluetoothDetailsOpen = true
                              root.wifiDetailsOpen = false
                              root.refreshBluetooth()
                              root.scanBluetooth()
                          }
                      }
                  }

              }

              Row {
                  visible: !root.wifiDetailsOpen && !root.bluetoothDetailsOpen && !root.settingsDetailsOpen
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.topMargin: 124
                  anchors.leftMargin: 22
                  anchors.rightMargin: 22
                  spacing: 14

                  Rectangle {
                      width: 32; height: 32; radius: 6
                      color: muteMouse.containsMouse ? "#3d4654" : "transparent"
                      Image { anchors.centerIn: parent; width: 20; height: 20; source: root.assetPath + "volume.svg"; opacity: root.outputMuted ? 0.45 : 1 }
                      MouseArea { id: muteMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleMute() }
                  }

                  Slider {
                      id: volumeSlider
                      width: 270
                      height: 32
                      from: 0
                      to: 1
                      value: root.outputVolume
                      onMoved: root.setVolume(value)

                      background: Rectangle {
                          x: volumeSlider.leftPadding
                          y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                          width: volumeSlider.availableWidth
                          height: 4
                          radius: 2
                          color: "#626975"

                          Rectangle {
                              width: volumeSlider.visualPosition * parent.width
                              height: parent.height
                              radius: 2
                              color: "#60cdff"
                          }
                      }

                      handle: Rectangle {
                          x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                          y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                          width: 16; height: 16; radius: 8
                          color: "white"
                          border.width: 4
                          border.color: "#60cdff"
                      }
                  }
              }

              Rectangle {
                  visible: !root.wifiDetailsOpen && !root.bluetoothDetailsOpen && !root.settingsDetailsOpen
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 58
                  color: "#d91a1f29"

                  Text {
                      anchors.left: parent.left
                      anchors.leftMargin: 22
                      anchors.verticalCenter: parent.verticalCenter
                      text: Math.round(root.outputVolume * 100) + "%"
                      color: "white"
                      font.family: root.uiFont
                      font.pixelSize: 13
                  }

                  Text {
                      anchors.right: parent.right
                      anchors.rightMargin: 22
                      anchors.verticalCenter: parent.verticalCenter
                      text: "⚙"
                      color: "white"
                      font.family: root.uiFont
                      font.pixelSize: 20
                      MouseArea {
                          anchors.fill: parent
                          anchors.margins: -10
                          onClicked: root.openSettingsPage("home")
                      }
                  }
              }

              Item {
                  anchors.fill: parent
                  visible: root.wifiDetailsOpen
                  z: 10
                  opacity: visible ? 1 : 0
                  scale: visible ? 1 : 0.94
                  transformOrigin: Item.BottomRight
                  Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                  Rectangle {
                      anchors.fill: parent
                      radius: 10
                      color: "#c7202631"

                      Rectangle {
                          id: wifiBackButton
                          anchors.left: parent.left
                          anchors.leftMargin: 14
                          anchors.top: parent.top
                          anchors.topMargin: 14
                          width: 34; height: 34; radius: 6
                          color: wifiBackMouse.containsMouse ? "#3d4654" : "transparent"
                          Text { anchors.centerIn: parent; text: "‹"; color: "white"; font.pixelSize: 28; font.family: root.uiFont }
                          MouseArea {
                              id: wifiBackMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              onClicked: root.wifiDetailsOpen = false
                          }
                      }

                      Text {
                          anchors.left: wifiBackButton.right
                          anchors.leftMargin: 10
                          anchors.verticalCenter: wifiBackButton.verticalCenter
                          text: "Wi-Fi"
                          color: "white"
                          font.pixelSize: 20
                          font.bold: true
                          font.family: root.uiFont
                      }

                      Rectangle {
                          id: wifiPowerButton
                          anchors.right: parent.right
                          anchors.rightMargin: 16
                          anchors.verticalCenter: wifiBackButton.verticalCenter
                          width: 54; height: 28; radius: 14
                          color: root.wifiEnabled ? "#60cdff" : "#4b515c"
                          Rectangle {
                              width: 20; height: 20; radius: 10
                              y: 4
                              x: root.wifiEnabled ? 30 : 4
                              color: root.wifiEnabled ? "#10202a" : "#e6e6e6"
                          }
                          MouseArea {
                              anchors.fill: parent
                              onClicked: {
                                  Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-wifi-action", "power"])
                                  wifiRefreshDelay.restart()
                              }
                          }
                      }

                      Text {
                          anchors.left: parent.left
                          anchors.leftMargin: 20
                          anchors.top: parent.top
                          anchors.topMargin: 64
                          text: root.wifiConnected.length > 0 ? "Connected to " + root.wifiConnected : "Available networks"
                          color: "#d8dce2"
                          font.pixelSize: 12
                          font.family: root.uiFont
                      }

                      ListView {
                          id: wifiList
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.top: parent.top
                          anchors.topMargin: 88
                          anchors.bottom: parent.bottom
                          anchors.bottomMargin: 54
                          anchors.leftMargin: 10
                          anchors.rightMargin: 10
                          spacing: 3
                          clip: true
                          model: wifiModel

                          delegate: Rectangle {
                              required property int index
                              readonly property var networkData: wifiModel.get(index)
                              width: wifiList.width
                              height: 58
                              radius: 7
                              color: networkMouse.containsMouse ? "#39414d" : networkData.connected ? "#33485a" : "transparent"

                              Text {
                                  anchors.left: parent.left
                                  anchors.leftMargin: 14
                                  anchors.right: signalText.left
                                  anchors.rightMargin: 10
                                  anchors.top: parent.top
                                  anchors.topMargin: 9
                                  text: networkData.name
                                  color: "white"
                                  font.pixelSize: 14
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                              }
                              Text {
                                  anchors.left: parent.left
                                  anchors.leftMargin: 14
                                  anchors.bottom: parent.bottom
                                  anchors.bottomMargin: 8
                                  text: networkData.connected ? "Connected" : networkData.security === "open" ? "Open" : "Secured"
                                  color: networkData.connected ? "#60cdff" : "#aeb5bf"
                                  font.pixelSize: 11
                                  font.family: root.uiFont
                              }
                              Text {
                                  id: signalText
                                  anchors.right: parent.right
                                  anchors.rightMargin: 14
                                  anchors.verticalCenter: parent.verticalCenter
                                  text: "▂▄▆█".slice(0, Math.max(1, networkData.signal))
                                  color: "#e7e9ec"
                                  font.pixelSize: 12
                              }
                              MouseArea {
                                  id: networkMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onClicked: {
                                      if (networkData.connected)
                                          Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-wifi-action", "disconnect"])
                                      else
                                          Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-wifi-action", "connect", networkData.name, networkData.security])
                                      wifiRefreshDelay.restart()
                                  }
                              }
                          }
                      }

                      Rectangle {
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.bottom: parent.bottom
                          height: 48
                          color: "#d91a1f29"
                          Text {
                              anchors.left: parent.left
                              anchors.leftMargin: 20
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Network settings"
                              color: "white"
                              font.pixelSize: 12
                              font.family: root.uiFont
                          }
                          Rectangle {
                              anchors.right: parent.right
                              anchors.rightMargin: 12
                              anchors.verticalCenter: parent.verticalCenter
                              width: 74; height: 30; radius: 6
                              color: refreshMouse.containsMouse ? "#46505e" : "#343b46"
                              Text { anchors.centerIn: parent; text: "Refresh"; color: "white"; font.pixelSize: 11; font.family: root.uiFont }
                              MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.scanWifi() }
                          }
                      }
                  }
              }

              Item {
                  anchors.fill: parent
                  visible: root.bluetoothDetailsOpen
                  z: 11
                  opacity: visible ? 1 : 0
                  scale: visible ? 1 : 0.94
                  transformOrigin: Item.BottomRight
                  Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                  Rectangle {
                      anchors.fill: parent
                      radius: 10
                      color: "#c7202631"

                      Rectangle {
                          id: bluetoothBackButton
                          anchors.left: parent.left; anchors.leftMargin: 14
                          anchors.top: parent.top; anchors.topMargin: 14
                          width: 34; height: 34; radius: 6
                          color: bluetoothBackMouse.containsMouse ? "#3d4654" : "transparent"
                          Text { anchors.centerIn: parent; text: "‹"; color: "white"; font.pixelSize: 28; font.family: root.uiFont }
                          MouseArea { id: bluetoothBackMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.bluetoothDetailsOpen = false }
                      }

                      Text {
                          anchors.left: bluetoothBackButton.right; anchors.leftMargin: 10
                          anchors.verticalCenter: bluetoothBackButton.verticalCenter
                          text: "Bluetooth"; color: "white"; font.pixelSize: 20; font.bold: true; font.family: root.uiFont
                      }

                      Rectangle {
                          anchors.right: parent.right; anchors.rightMargin: 16
                          anchors.verticalCenter: bluetoothBackButton.verticalCenter
                          width: 54; height: 28; radius: 14
                          color: root.bluetoothEnabled ? "#60cdff" : "#4b515c"
                          Rectangle { width: 20; height: 20; radius: 10; y: 4; x: root.bluetoothEnabled ? 30 : 4; color: root.bluetoothEnabled ? "#10202a" : "#e6e6e6" }
                          MouseArea {
                              anchors.fill: parent
                              onClicked: {
                                  Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-bluetooth-action", "power"])
                                  bluetoothRefreshDelay.restart()
                              }
                          }
                      }

                      Text {
                          anchors.left: parent.left; anchors.leftMargin: 20
                          anchors.top: parent.top; anchors.topMargin: 64
                          text: bluetoothModel.count > 0 ? "Devices" : "No devices found"
                          color: "#d8dce2"; font.pixelSize: 12; font.family: root.uiFont
                      }

                      ListView {
                          id: bluetoothList
                          anchors.left: parent.left; anchors.right: parent.right
                          anchors.top: parent.top; anchors.topMargin: 88
                          anchors.bottom: parent.bottom; anchors.bottomMargin: 54
                          anchors.leftMargin: 10; anchors.rightMargin: 10
                          spacing: 3; clip: true; model: bluetoothModel

                          delegate: Rectangle {
                              required property int index
                              readonly property var deviceData: bluetoothModel.get(index)
                              width: bluetoothList.width; height: 58; radius: 7
                              color: deviceMouse.containsMouse ? "#39414d" : deviceData.connected ? "#33485a" : "transparent"
                              Text {
                                  anchors.left: parent.left; anchors.leftMargin: 14
                                  anchors.right: parent.right; anchors.rightMargin: 14
                                  anchors.top: parent.top; anchors.topMargin: 9
                                  text: deviceData.name; color: "white"; font.pixelSize: 14; font.family: root.uiFont; elide: Text.ElideRight
                              }
                              Text {
                                  anchors.left: parent.left; anchors.leftMargin: 14
                                  anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                  text: deviceData.connected ? "Connected" : deviceData.paired ? "Paired" : "Available"
                                  color: deviceData.connected ? "#60cdff" : "#aeb5bf"; font.pixelSize: 11; font.family: root.uiFont
                              }
                              MouseArea {
                                  id: deviceMouse; anchors.fill: parent; hoverEnabled: true
                                  onClicked: {
                                      Quickshell.execDetached([
                                          Quickshell.env("HOME") + "/.local/bin/windows-bluetooth-action",
                                          deviceData.connected ? "disconnect" : "connect", deviceData.address
                                      ])
                                      bluetoothRefreshDelay.restart()
                                  }
                              }
                          }
                      }

                      Rectangle {
                          anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                          height: 48; color: "#d91a1f29"
                          Text { anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth settings"; color: "white"; font.pixelSize: 12; font.family: root.uiFont }
                          Rectangle {
                              anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                              width: 74; height: 30; radius: 6; color: bluetoothScanMouse.containsMouse ? "#46505e" : "#343b46"
                              Text { anchors.centerIn: parent; text: "Scan"; color: "white"; font.pixelSize: 11; font.family: root.uiFont }
                              MouseArea { id: bluetoothScanMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.scanBluetooth() }
                          }
                      }
                  }
              }

              Item {
                  anchors.fill: parent
                  visible: root.settingsDetailsOpen
                  z: 12
                  opacity: visible ? 1 : 0
                  scale: visible ? 1 : 0.94
                  transformOrigin: Item.BottomRight
                  Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                  Rectangle {
                      anchors.fill: parent; radius: 10; color: "#c7202631"
                      Rectangle {
                          id: settingsBackButton
                          anchors.left: parent.left; anchors.leftMargin: 14; anchors.top: parent.top; anchors.topMargin: 14
                          width: 34; height: 34; radius: 6; color: settingsBackMouse.containsMouse ? "#3d4654" : "transparent"
                          Text { anchors.centerIn: parent; text: "‹"; color: "white"; font.pixelSize: 28; font.family: root.uiFont }
                          MouseArea { id: settingsBackMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.settingsDetailsOpen = false }
                      }
                      Text {
                          anchors.left: settingsBackButton.right; anchors.leftMargin: 10; anchors.verticalCenter: settingsBackButton.verticalCenter
                          text: "Settings"; color: "white"; font.pixelSize: 20; font.bold: true; font.family: root.uiFont
                      }
                      Column {
                          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                          anchors.topMargin: 66; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 4
                          Repeater {
                              model: [
                                  { title: "Network & internet", detail: "Wi-Fi and connections", action: "wifi" },
                                  { title: "Bluetooth & devices", detail: "Pair and manage devices", action: "bluetooth" },
                                  { title: "System sound", detail: "Output, input and application volume", action: "sound" },
                                  { title: "Taskbar", detail: "Task View and weather visibility", action: "taskbar" },
                                  { title: "Weather", detail: "Location and forecast source", action: "weather" },
                                  { title: "Personalization", detail: "Switch desktop style and keybindings", action: "style" }
                              ]
                              delegate: Rectangle {
                                  required property var modelData
                                  width: parent.width; height: 66; radius: 7
                                  color: settingsRowMouse.containsMouse ? "#39414d" : "transparent"
                                  Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.top: parent.top; anchors.topMargin: 10; text: modelData.title; color: "white"; font.pixelSize: 14; font.family: root.uiFont }
                                  Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 9; text: modelData.detail; color: "#aeb5bf"; font.pixelSize: 11; font.family: root.uiFont }
                                  Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: "#d8dce2"; font.pixelSize: 22 }
                                  MouseArea {
                                      id: settingsRowMouse; anchors.fill: parent; hoverEnabled: true
                                      onClicked: {
                                          if (modelData.action === "wifi") root.openSettingsPage("wifi")
                                          else if (modelData.action === "bluetooth") root.openSettingsPage("bluetooth")
                                          else if (modelData.action === "sound") Quickshell.execDetached(["pavucontrol"])
                                          else if (modelData.action === "taskbar") Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-taskbar-options"])
                                          else if (modelData.action === "weather") Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-weather-settings"])
                                          else if (modelData.action === "style") Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hypr-config-switcher"])
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }

      // Native calendar flyout
      PanelWindow {
          id: calendarPanel
          visible: root.calendarOpen
          WlrLayershell.namespace: "windows-calendar"
          anchors { right: true; bottom: true }
          margins { right: 10; bottom: 56 }
          implicitWidth: 350
          implicitHeight: 390
          exclusiveZone: 0
          color: "transparent"

          Rectangle {
              anchors.fill: parent
              radius: 11
              color: "#c7202631"
              border.width: 1
              border.color: "#38ffffff"
              transformOrigin: Item.BottomRight
              scale: root.calendarOpen ? 1 : 0.88
              opacity: root.calendarOpen ? 1 : 0
              Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
              Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

              Text {
                  anchors.left: parent.left; anchors.leftMargin: 22
                  anchors.top: parent.top; anchors.topMargin: 18
                  text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
                  color: "white"; font.family: root.uiFont; font.pixelSize: 16; font.bold: true
              }
              Text {
                  anchors.left: parent.left; anchors.leftMargin: 22
                  anchors.top: parent.top; anchors.topMargin: 46
                  text: Qt.formatDateTime(root.currentTime, "HH:mm:ss")
                  color: "#60cdff"; font.family: root.uiFont; font.pixelSize: 24
              }
              Rectangle {
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.top: parent.top; anchors.topMargin: 88
                  height: 1; color: "#24ffffff"
              }
              Text {
                  anchors.left: parent.left; anchors.leftMargin: 22
                  anchors.top: parent.top; anchors.topMargin: 108
                  text: root.calendarMonths[root.calendarMonth] + " " + root.calendarYear
                  color: "white"; font.family: root.uiFont; font.pixelSize: 14; font.bold: true
              }

              Row {
                  anchors.right: parent.right; anchors.rightMargin: 16
                  anchors.top: parent.top; anchors.topMargin: 99
                  spacing: 4
                  Repeater {
                      model: [{ text: "‹", offset: -1 }, { text: "›", offset: 1 }]
                      delegate: Rectangle {
                          required property var modelData
                          width: 34; height: 34; radius: 6
                          color: monthMouse.containsMouse ? "#36ffffff" : "transparent"
                          Behavior on color { ColorAnimation { duration: 100 } }
                          Text { anchors.centerIn: parent; text: modelData.text; color: "white"; font.pixelSize: 23 }
                          MouseArea {
                              id: monthMouse; anchors.fill: parent; hoverEnabled: true
                              onClicked: root.moveCalendarMonth(modelData.offset)
                          }
                      }
                  }
              }

              Grid {
                  anchors.left: parent.left; anchors.leftMargin: 18
                  anchors.top: parent.top; anchors.topMargin: 148
                  columns: 7; spacing: 2
                  Repeater {
                      model: 7
                      delegate: Text {
                          required property int index
                          width: 43; height: 26
                          horizontalAlignment: Text.AlignHCenter
                          verticalAlignment: Text.AlignVCenter
                          text: root.calendarWeekdays[index]
                          color: "#8fa1b5"; font.family: root.uiFont; font.pixelSize: 11
                      }
                  }
                  Repeater {
                      model: 42
                      delegate: Rectangle {
                          required property int index
                          readonly property int day: root.calendarDay(index)
                          width: 43; height: 31; radius: 7
                          color: root.calendarIsToday(day)
                              ? "#60cdff"
                              : dayMouse.containsMouse && day > 0 ? "#2effffff" : "transparent"
                          Behavior on color { ColorAnimation { duration: 100 } }
                          Text {
                              anchors.centerIn: parent
                              text: day > 0 ? day : ""
                              color: root.calendarIsToday(day) ? "#071018" : "white"
                              font.family: root.uiFont; font.pixelSize: 12
                              font.bold: root.calendarIsToday(day)
                          }
                          MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                      }
                  }
              }
          }
      }

      // Native notification center
      PanelWindow {
          visible: root.notificationsOpen
          WlrLayershell.namespace: "windows-notifications"
          anchors { right: true; bottom: true }
          margins { right: 10; bottom: 56 }
          implicitWidth: 370; implicitHeight: 310
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.BottomRight
              scale: root.notificationsOpen ? 1 : 0.88
              opacity: root.notificationsOpen ? 1 : 0
              Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
              Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              Text { anchors.left: parent.left; anchors.leftMargin: 22; anchors.top: parent.top; anchors.topMargin: 20; text: "Notifications"; color: "white"; font.family: root.uiFont; font.pixelSize: 18; font.bold: true }
              Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 58; height: 1; color: "#24ffffff" }
              Column {
                  anchors.centerIn: parent; anchors.verticalCenterOffset: -8; spacing: 8
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✓"; color: "#60cdff"; font.pixelSize: 30 }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; color: "white"; font.family: root.uiFont; font.pixelSize: 14 }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No new notifications"; color: "#8fa1b5"; font.family: root.uiFont; font.pixelSize: 11 }
              }
              Rectangle {
                  anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16
                  height: 46; radius: 8; color: dndMouse.containsMouse ? "#36ffffff" : "#18ffffff"
                  Behavior on color { ColorAnimation { duration: 110 } }
                  Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "Do not disturb"; color: "white"; font.family: root.uiFont; font.pixelSize: 12 }
                  Rectangle {
                      anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                      width: 40; height: 22; radius: 11; color: root.doNotDisturb ? "#60cdff" : "#4b5665"
                      Behavior on color { ColorAnimation { duration: 140 } }
                      Rectangle { width: 16; height: 16; radius: 8; color: "white"; anchors.verticalCenter: parent.verticalCenter; x: root.doNotDisturb ? 21 : 3; Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutBack } } }
                  }
                  MouseArea { id: dndMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleDoNotDisturb() }
              }
          }
      }

      // Native power flyout
      PanelWindow {
          visible: root.powerOpen
          WlrLayershell.namespace: "windows-power"
          anchors { bottom: true }
          margins { bottom: 56 }
          implicitWidth: 270; implicitHeight: 285
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.Bottom; scale: root.powerOpen ? 1 : 0.86; opacity: root.powerOpen ? 1 : 0
              Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              Text { anchors.left: parent.left; anchors.leftMargin: 20; anchors.top: parent.top; anchors.topMargin: 18; text: "Power"; color: "white"; font.family: root.uiFont; font.pixelSize: 17; font.bold: true }
              Column {
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 55; anchors.margins: 12; spacing: 5
                  Repeater {
                      model: [{ title: "Lock", glyph: "●", action: "lock" }, { title: "Sleep", glyph: "☾", action: "sleep" }, { title: "Restart", glyph: "↻", action: "restart" }, { title: "Shut down", glyph: "⏻", action: "shutdown" }]
                      delegate: Rectangle {
                          required property var modelData
                          width: parent.width; height: 48; radius: 7; color: powerMouse.containsMouse ? "#36ffffff" : "transparent"
                          Behavior on color { ColorAnimation { duration: 100 } }
                          Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; color: "#60cdff"; font.pixelSize: 18 }
                          Text { anchors.left: parent.left; anchors.leftMargin: 48; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; color: "white"; font.family: root.uiFont; font.pixelSize: 13 }
                          MouseArea {
                              id: powerMouse; anchors.fill: parent; hoverEnabled: true
                              onClicked: {
                                  root.powerOpen = false
                                  if (modelData.action === "lock") Quickshell.execDetached(["hyprlock", "--config", Quickshell.env("HOME") + "/.config/hypr/hyprlock-windows.conf"])
                                  else if (modelData.action === "sleep") Quickshell.execDetached(["systemctl", "suspend"])
                                  else if (modelData.action === "restart") Quickshell.execDetached(["systemctl", "reboot"])
                                  else if (modelData.action === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
                              }
                          }
                      }
                  }
              }
          }
      }

      // Native system-controls flyout
      PanelWindow {
          visible: root.trayOpen
          WlrLayershell.namespace: "windows-tray"
          anchors { right: true; bottom: true }
          margins { right: 106; bottom: 56 }
          implicitWidth: 280; implicitHeight: 255
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.BottomRight; scale: root.trayOpen ? 1 : 0.88; opacity: root.trayOpen ? 1 : 0
              Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              Text { anchors.left: parent.left; anchors.leftMargin: 20; anchors.top: parent.top; anchors.topMargin: 18; text: "System controls"; color: "white"; font.family: root.uiFont; font.pixelSize: 17; font.bold: true }
              Grid {
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 58; anchors.margins: 14; columns: 2; spacing: 8
                  Repeater {
                      model: [{ title: "Settings", glyph: "⚙", action: "settings" }, { title: "Volume", glyph: "◖))", action: "volume" }, { title: "Bluetooth", glyph: "ᛒ", action: "bluetooth" }, { title: "Network", glyph: "⌁", action: "wifi" }]
                      delegate: Rectangle {
                          required property var modelData
                          width: 122; height: 78; radius: 8; color: trayMouse.containsMouse ? "#36ffffff" : "#18ffffff"
                          Behavior on color { ColorAnimation { duration: 100 } }
                          Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 12; text: modelData.glyph; color: "#60cdff"; font.pixelSize: 20 }
                          Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: modelData.title; color: "white"; font.family: root.uiFont; font.pixelSize: 11 }
                          MouseArea {
                              id: trayMouse; anchors.fill: parent; hoverEnabled: true
                              onClicked: {
                                  root.trayOpen = false; root.quickSettingsOpen = true
                                  if (modelData.action === "settings") root.openSettingsPage("home")
                                  else if (modelData.action === "bluetooth") root.openSettingsPage("bluetooth")
                                  else if (modelData.action === "wifi") root.openSettingsPage("wifi")
                              }
                          }
                      }
                  }
              }
          }
      }

      // Start menu
      PanelWindow {
          id: startMenu
          WlrLayershell.namespace: "windows-start"
          visible: root.startOpen

          WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

          onVisibleChanged: {
              if (visible) {
                  search.forceActiveFocus()
              } else {
                  root.showingAllApps = false
                  search.text = ""
              }
          }

          anchors {
              bottom: true
          }

          margins {
              bottom: 56
          }

          implicitWidth: 620
          implicitHeight: 650
          exclusiveZone: 0
          color: "transparent"

          Rectangle {
              id: startSurface
              anchors.fill: parent
              radius: 10
              color: "#70202631"
              border.color: "#38ffffff"
              border.width: 1
              transformOrigin: Item.Bottom
              scale: root.startOpen ? 1 : 0.88
              opacity: root.startOpen ? 1 : 0
              Behavior on scale {
                  NumberAnimation { duration: 280; easing.type: Easing.OutBack }
              }
              Behavior on opacity {
                  NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
              }

              Column {
                  anchors.fill: parent
                  anchors.margins: 32
                  anchors.bottomMargin: 86
                  spacing: 16

                  Rectangle {
                      width: parent.width
                      height: 46
                      radius: 8
                      color: "#661a1f28"
                      border.width: 1
                      border.color: search.activeFocus ? "#4cc2ff" : "#50ffffff"

                      Text {
                          anchors.left: parent.left
                          anchors.leftMargin: 16
                          anchors.verticalCenter: parent.verticalCenter
                          text: "⌕"
                          color: "#4cc2ff"
                          font.pixelSize: 22
                          font.family: root.uiFont
                      }

                      Text {
                          anchors.left: parent.left
                          anchors.leftMargin: 52
                          anchors.verticalCenter: parent.verticalCenter
                          text: "Search apps and commands"
                          color: "#888888"
                          font.family: root.uiFont
                          visible: search.text.length === 0
                      }

                      TextInput {
                          id: search

                          anchors.left: parent.left
                          anchors.leftMargin: 52
                          anchors.right: parent.right
                          anchors.rightMargin: 16
                          anchors.verticalCenter: parent.verticalCenter

                          color: "white"
                          font.pixelSize: 16
                          font.family: root.uiFont
                          clip: true

                          onTextChanged: {
                              root.showingAllApps = false
                              root.filterApps(text)
                          }

                          Keys.onDownPressed: {
                              if (appList.currentIndex < appModel.count - 1)
                                  appList.currentIndex++
                          }

                          Keys.onUpPressed: {
                              if (appList.currentIndex > 0)
                                  appList.currentIndex--
                          }

                          Keys.onReturnPressed: {
                              if (appList.currentIndex >= 0)
                                  root.launchApp(appModel.get(appList.currentIndex).exec,
                                      appModel.get(appList.currentIndex).match)
                          }

                          Keys.onEscapePressed: {
                              root.startOpen = false
                          }
                      }

                      MouseArea {
                          anchors.fill: parent
                          onClicked: search.forceActiveFocus()
                      }
                  }

                  Item {
                      id: startHome
                      width: parent.width
                      height: 480
                      visible: search.text.length === 0 && !root.showingAllApps
                      opacity: visible ? 1 : 0
                      scale: visible ? 1 : 0.97
                      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                      Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

                      Text {
                          anchors.left: parent.left
                          anchors.top: parent.top
                          anchors.topMargin: 4
                          text: "Pinned"
                          color: "white"
                          font.pixelSize: 18
                          font.bold: true
                          font.family: root.uiFont
                      }

                      Rectangle {
                          anchors.right: parent.right
                          anchors.top: parent.top
                          width: 82
                          height: 30
                          radius: 6
                          color: allAppsMouse.containsMouse ? "#4a4b50" : "#3a3b40"
                          Behavior on color { ColorAnimation { duration: 110 } }

                          Text {
                              anchors.centerIn: parent
                              text: "All apps  ›"
                              color: "white"
                              font.pixelSize: 12
                              font.family: root.uiFont
                          }

                          MouseArea {
                              id: allAppsMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              onClicked: root.showAllApps()
                          }
                      }

                      GridView {
                          id: pinnedGrid
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.top: parent.top
                          anchors.topMargin: 42
                          height: 190
                          cellWidth: width / 6
                          cellHeight: 92
                          interactive: false
                          model: pinnedModel

                          delegate: Item {
                              required property int index
                              readonly property var pinnedData: pinnedModel.get(index)

                              width: pinnedGrid.cellWidth
                              height: pinnedGrid.cellHeight

                              Rectangle {
                                  anchors.fill: parent
                                  anchors.margins: 3
                                  radius: 7
                                  color: pinnedMouse.containsMouse ? "#34353a" : "transparent"
                                  Behavior on color { ColorAnimation { duration: 110 } }
                              }

                              Image {
                                  anchors.horizontalCenter: parent.horizontalCenter
                                  anchors.top: parent.top
                                  anchors.topMargin: 10
                                  width: 36
                                  height: 36
                                  source: pinnedData.icon.startsWith("/")
                                      ? "file://" + pinnedData.icon
                                      : "image://icon/" + pinnedData.icon
                                  sourceSize: Qt.size(72, 72)
                                  fillMode: Image.PreserveAspectFit
                                  onStatusChanged: {
                                      if (status === Image.Error)
                                          source = "image://icon/application-x-executable"
                                  }
                              }

                              Text {
                                  anchors.left: parent.left
                                  anchors.right: parent.right
                                  anchors.bottom: parent.bottom
                                  anchors.bottomMargin: 8
                                  horizontalAlignment: Text.AlignHCenter
                                  text: pinnedData.name
                                  color: "white"
                                  font.pixelSize: 11
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                              }

                              MouseArea {
                                  id: pinnedMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                                  onClicked: function(mouse) {
                                      if (mouse.button === Qt.RightButton)
                                          root.showAppMenu(pinnedData.name, pinnedData.command, pinnedData.icon, "")
                                      else
                                          root.launchApp(pinnedData.command, pinnedData.match || "")
                                  }
                              }
                          }
                      }

                      Text {
                          anchors.left: parent.left
                          anchors.top: parent.top
                          anchors.topMargin: 252
                          text: "Recommended"
                          color: "white"
                          font.pixelSize: 18
                          font.bold: true
                          font.family: root.uiFont
                      }

                      GridView {
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.top: parent.top
                          anchors.topMargin: 292
                          height: 174
                          cellWidth: width / 2
                          cellHeight: 58
                          interactive: false
                          model: recommendedModel

                          delegate: Rectangle {
                              required property int index
                              readonly property var recentData: recommendedModel.get(index)
                              width: GridView.view.cellWidth
                              height: GridView.view.cellHeight
                              radius: 7
                              color: recentMouse.containsMouse ? "#343b49" : "transparent"

                              Image {
                                  anchors.left: parent.left
                                  anchors.leftMargin: 10
                                  anchors.verticalCenter: parent.verticalCenter
                                  width: 34
                                  height: 34
                                  source: recentData.icon.startsWith("/") ? "file://" + recentData.icon : "image://icon/" + recentData.icon
                                  onStatusChanged: { if (status === Image.Error) source = "image://icon/application-x-executable" }
                              }

                              Column {
                                  anchors.left: parent.left
                                  anchors.leftMargin: 54
                                  anchors.right: parent.right
                                  anchors.rightMargin: 6
                                  anchors.verticalCenter: parent.verticalCenter
                                  spacing: 2
                                  Text { width: parent.width; text: recentData.name; color: "white"; font.pixelSize: 12; font.family: root.uiFont; elide: Text.ElideRight }
                                  Text { text: recentData.detail; color: "#a7a7a7"; font.pixelSize: 10; font.family: root.uiFont }
                              }

                              MouseArea {
                                  id: recentMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onClicked: root.launchApp(recentData.command, recentData.match || "")
                              }
                          }
                      }
                  }

                  Item {
                      id: searchResults
                      width: parent.width
                      height: 480
                      visible: search.text.length > 0 || root.showingAllApps
                      opacity: visible ? 1 : 0
                      scale: visible ? 1 : 0.97
                      Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                      Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                      Text {
                          id: resultsTitle
                          anchors.left: parent.left
                          anchors.top: parent.top
                          text: root.showingAllApps
                              ? "All apps"
                              : "Results for \"" + search.text + "\""
                          color: "white"
                          font.pixelSize: 18
                          font.bold: true
                          font.family: root.uiFont
                      }

                      ListView {
                          id: appList
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.top: resultsTitle.bottom
                          anchors.topMargin: 12
                          anchors.bottom: parent.bottom
                          spacing: 4
                          clip: true
                          model: appModel
                          currentIndex: appModel.count > 0 ? 0 : -1

                          delegate: Rectangle {
                          required property int index
                          readonly property var appData: appModel.get(index)

                          width: appList.width
                          height: 50
                          radius: 7
                          color: index === appList.currentIndex
                              ? "#3d3e43"
                              : resultMouse.containsMouse ? "#303136" : "transparent"
                          Behavior on color { ColorAnimation { duration: 100 } }

                          Image {
                              anchors.left: parent.left
                              anchors.leftMargin: 10
                              anchors.verticalCenter: parent.verticalCenter
                              width: 30
                              height: 30
                              source: appData.icon.startsWith("/")
                                  ? "file://" + appData.icon
                                  : "image://icon/" + appData.icon
                              sourceSize: Qt.size(64, 64)
                              fillMode: Image.PreserveAspectFit
                              onStatusChanged: {
                                  if (status === Image.Error)
                                      source = "image://icon/application-x-executable"
                              }
                          }

                          Text {
                              anchors.left: parent.left
                              anchors.leftMargin: 54
                              anchors.right: parent.right
                              anchors.rightMargin: 12
                              anchors.verticalCenter: parent.verticalCenter
                              text: appData.name
                              color: "white"
                              font.pixelSize: 15
                              font.family: root.uiFont
                              elide: Text.ElideRight
                          }

                          MouseArea {
                              id: resultMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              acceptedButtons: Qt.LeftButton | Qt.RightButton
                              onEntered: appList.currentIndex = index
                              onClicked: function(mouse) {
                                  if (mouse.button === Qt.RightButton)
                                      root.showAppMenu(appData.name, appData.exec, appData.icon, appData.match)
                                  else
                                      root.launchApp(appData.exec, appData.match)
                              }
                          }
                          }
                      }
                  }
              }

              Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 68
                  color: "#661a1f29"

                  Text {
                      anchors.left: parent.left
                      anchors.leftMargin: 44
                      anchors.verticalCenter: parent.verticalCenter
                      text: "●   " + Quickshell.env("USER")
                      color: "white"
                      font.pixelSize: 13
                      font.family: root.uiFont
                  }

                  Rectangle {
                      anchors.right: parent.right
                      anchors.rightMargin: 40
                      anchors.verticalCenter: parent.verticalCenter
                      width: 38
                      height: 38
                      radius: 6
                      color: powerMouse.containsMouse ? "#3d3e43" : "transparent"

                      Text {
                          anchors.centerIn: parent
                          text: "⏻"
                          color: "white"
                          font.pixelSize: 20
                          font.family: root.uiFont
                      }

                      MouseArea {
                          id: powerMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: {
                              root.startOpen = false
                              Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-power-menu"])
                          }
                      }
                  }
              }
          }
      }
  }

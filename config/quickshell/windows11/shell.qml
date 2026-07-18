import Quickshell
  import Quickshell.Io
  import Quickshell.Wayland
  import QtQuick
  import QtQuick.Controls
  import QtQuick.Dialogs

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
      property bool personalizationOpen: false
      property bool systemDialogOpen: false
      property var activePreset: ({})
      property var availablePresets: []
      property bool personalizationDirty: false
      property var personalizationCommands: []
      property string filePickerTarget: ""
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
      property string activeAddress: ""
      property bool wifiEnabled: false
      property bool bluetoothEnabled: false
      property real outputVolume: 0
      property bool outputMuted: false
      readonly property bool externalTaskbar: Quickshell.env("WINDOWS_TASKBAR") === "waybar"
      property string taskbarEdge: "bottom"
      property int taskbarThickness: 48
      property bool directionalMotion: true
      property bool animateShellPanels: true
      property int motionDuration: 280
      property int motionDistance: 36
      readonly property int panelGap: taskbarThickness + 8

      function panelOffsetX(open) {
          if (open || !directionalMotion || !animateShellPanels) return 0
          if (taskbarEdge === "left") return -motionDistance
          if (taskbarEdge === "right") return motionDistance
          return 0
      }

      function panelOffsetY(open) {
          if (open || !directionalMotion || !animateShellPanels) return 0
          if (taskbarEdge === "top") return -motionDistance
          if (taskbarEdge === "bottom") return motionDistance
          return 0
      }

      function changePersonalization(key, value) {
          const changed = JSON.parse(JSON.stringify(root.activePreset))
          if (changed.slug === "windows-11") {
              changed.slug = "my-windows"
              changed.name = "My Windows"
              root.upsertPreset("", changed.slug, changed.name)
          }
          const keys = key.split(".")
          let target = changed
          for (let index = 0; index < keys.length - 1; index++) target = target[keys[index]]
          target[keys[keys.length - 1]] = value
          root.activePreset = changed
          root.personalizationDirty = true
          root.queuePersonalization(["stage", changed.slug, key, String(value)])
      }

      function queuePersonalization(arguments) {
          const queued = root.personalizationCommands.slice()
          queued.push([Quickshell.env("HOME") + "/.local/bin/windows-personalization"].concat(arguments))
          root.personalizationCommands = queued
          root.runNextPersonalizationCommand()
      }

      function runNextPersonalizationCommand() {
          if (personalizationWriter.running || root.personalizationCommands.length === 0) return
          const queued = root.personalizationCommands.slice()
          personalizationWriter.command = queued.shift()
          root.personalizationCommands = queued
          personalizationWriter.running = true
      }

      function presetSlug(name) {
          const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
          return slug.length > 0 ? slug : "custom-preset"
      }

      function upsertPreset(oldSlug, newSlug, name) {
          const updated = []
          let found = false
          for (let index = 0; index < root.availablePresets.length; index++) {
              const item = root.availablePresets[index]
              if (item.slug === oldSlug || item.slug === newSlug) {
                  if (!found) updated.push({ slug: newSlug, name: name, protected: false })
                  found = true
              } else updated.push(item)
          }
          if (!found) updated.push({ slug: newSlug, name: name, protected: false })
          root.availablePresets = updated
      }

      function previewPreset(slug) {
          if (presetPreview.running) return
          presetPreview.command = [Quickshell.env("HOME") + "/.local/bin/windows-personalization", "state", slug]
          presetPreview.running = true
      }

      function renamePreset(name) {
          const cleanName = name.trim().length > 0 ? name.trim() : root.activePreset.name
          const oldSlug = root.activePreset.slug
          const newSlug = root.presetSlug(cleanName)
          const changed = JSON.parse(JSON.stringify(root.activePreset))
          changed.slug = newSlug
          changed.name = cleanName
          root.activePreset = changed
          root.upsertPreset(oldSlug === "windows-11" ? "" : oldSlug, newSlug, cleanName)
          root.personalizationDirty = true
          root.queuePersonalization(["rename", oldSlug, cleanName])
      }

      function clonePreset(name) {
          const cleanName = name.trim().length > 0 ? name.trim() : "My Shell"
          const sourceSlug = root.activePreset.slug
          const newSlug = root.presetSlug(cleanName)
          const changed = JSON.parse(JSON.stringify(root.activePreset))
          changed.slug = newSlug
          changed.name = cleanName
          root.activePreset = changed
          root.upsertPreset("", newSlug, cleanName)
          root.personalizationDirty = true
          root.queuePersonalization(["clone", sourceSlug, cleanName])
      }

      function deletePreset(slug) {
          root.queuePersonalization(["delete", slug])
          root.availablePresets = root.availablePresets.filter(item => item.slug !== slug)
          root.previewPreset("windows-11")
      }

      function applyPersonalization() {
          if (!root.personalizationDirty || !root.activePreset.slug) return
          root.personalizationDirty = false
          root.closeRightMenu()
          root.queuePersonalization(["apply", root.activePreset.slug])
      }

      function closeRightMenu() {
          root.quickSettingsOpen = false
          root.wifiDetailsOpen = false
          root.bluetoothDetailsOpen = false
          root.settingsDetailsOpen = false
          root.personalizationOpen = false
      }

      function closeAllMenus() {
          root.startOpen = false
          root.closeRightMenu()
          root.calendarOpen = false
          root.notificationsOpen = false
          root.powerOpen = false
          root.trayOpen = false
      }

      function openSystemDialog(dialog) {
          root.systemDialogOpen = true
          dialog.open()
          root.closeRightMenu()
      }

      function openImagePicker(target, title, includeSvg) {
          if (imagePicker.running) return
          root.filePickerTarget = target
          root.systemDialogOpen = true
          const extensions = includeSvg
              ? "*.png *.svg *.webp *.jpg *.jpeg *.ico"
              : "*.png *.webp *.jpg *.jpeg"
          imagePicker.command = [
              "zenity", "--file-selection", "--title=" + title,
              "--filename=" + Quickshell.env("HOME") + "/Pictures/",
              "--file-filter=Images | " + extensions,
              "--file-filter=All files | *"
          ]
          imagePicker.running = true
          root.closeRightMenu()
      }

      function colorHex(color) {
          function channel(value) { return Math.round(value * 255).toString(16).padStart(2, "0") }
          return "#" + channel(color.r) + channel(color.g) + channel(color.b)
      }

      // Qt 6.11's native QtQuick FileDialog currently crashes while opening on
      // this stack. Zenity still uses the desktop's normal GTK/portal chooser,
      // but runs out of process so a picker bug cannot take down the shell.
      Process {
          id: imagePicker
          stdout: StdioCollector {
              onStreamFinished: {
                  const selectedPath = text.trim()
                  root.systemDialogOpen = false
                  if (selectedPath.length > 0 && root.filePickerTarget.length > 0)
                      root.changePersonalization(root.filePickerTarget, selectedPath)
                  root.filePickerTarget = ""
              }
          }
      }
      ColorDialog {
          id: backgroundPicker
          parentWindow: quickSettingsSurface.Window.window
          title: "Taskbar background"
          onAccepted: {
              root.systemDialogOpen = false
              root.changePersonalization("appearance.background", root.colorHex(selectedColor))
          }
          onRejected: root.systemDialogOpen = false
      }
      ColorDialog {
          id: accentPicker
          parentWindow: quickSettingsSurface.Window.window
          title: "Accent color"
          onAccepted: {
              root.systemDialogOpen = false
              root.changePersonalization("appearance.accent", root.colorHex(selectedColor))
          }
          onRejected: root.systemDialogOpen = false
      }

      Process {
          id: personalizationState
          running: true
          command: [Quickshell.env("HOME") + "/.local/bin/windows-personalization", "state"]
          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const preset = JSON.parse(text)
                      root.taskbarEdge = preset.taskbar.position
                      root.taskbarThickness = preset.taskbar.size
                      root.directionalMotion = preset.motion.follow_taskbar
                      root.animateShellPanels = preset.motion.shell_panels
                      root.motionDuration = preset.motion.duration_ms
                      root.motionDistance = preset.motion.distance
                      root.activePreset = preset
                      root.availablePresets = preset.presets || []
                  } catch (error) {
                      console.log("Could not load personalization preset:", error)
                  }
              }
          }
      }
      Process {
          id: presetPreview
          stdout: StdioCollector {
              onStreamFinished: {
                  try {
                      const preset = JSON.parse(text)
                      root.activePreset = preset
                      root.availablePresets = preset.presets || root.availablePresets
                      root.personalizationDirty = true
                  } catch (error) {
                      console.log("Could not preview personalization preset:", error)
                  }
              }
          }
      }
      Process { id: personalizationWriter }
      Timer {
          interval: 60
          repeat: true
          running: personalizationWriter.running || root.personalizationCommands.length > 0
          onTriggered: root.runNextPersonalizationCommand()
      }
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
                      const previousAddress = root.activeAddress
                      root.runningClasses = state.clients
                      root.activeClass = state.active
                      root.activeAddress = state.address || ""
                      if (root.quickSettingsOpen && previousAddress.length > 0
                              && root.activeAddress !== previousAddress)
                          root.closeRightMenu()
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
          ListElement { name: "Browser"; icon: "@HOME@/.config/quickshell/windows11/assets/browser.svg"; command: "@HOME@/.local/bin/zen"; match: "zen"; action: "launch" }
          ListElement { name: "Discord"; icon: "com.discordapp.Discord"; command: "@HOME@/.local/bin/discord-wayland"; match: "discord"; action: "launch" }
      }

      ListModel {
          id: recommendedModel
          ListElement { name: "File Explorer"; detail: "Recently used"; icon: "org.xfce.thunar"; command: "thunar" }
          ListElement { name: "Zen Browser"; detail: "Recently used"; icon: "@HOME@/.config/quickshell/windows11/assets/zen-waybar.png"; command: "@HOME@/.local/bin/zen" }
          ListElement { name: "Discord"; detail: "Recently used"; icon: "com.discordapp.Discord"; command: "@HOME@/.local/bin/discord-wayland"; match: "discord" }
          ListElement { name: "Prism Launcher"; detail: "Recently added"; icon: "org.prismlauncher.PrismLauncher"; command: "prismlauncher" }
          ListElement { name: "Volume Control"; detail: "Recently used"; icon: "org.pulseaudio.pavucontrol"; command: "pavucontrol" }
          ListElement { name: "OpenRGB"; detail: "Recently used"; icon: "org.openrgb.OpenRGB"; command: "openrgb" }
      }

      ListModel {
          id: pinnedModel

          ListElement { name: "Zen Browser"; icon: "@HOME@/.config/quickshell/windows11/assets/zen-waybar.png"; command: "@HOME@/.local/bin/zen" }
          ListElement { name: "Firefox"; icon: "firefox"; command: "firefox --name firefox" }
          ListElement { name: "Discord"; icon: "com.discordapp.Discord"; command: "@HOME@/.local/bin/discord-wayland"; match: "discord" }
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
          root.closeAllMenus()
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
      }

      function showAppMenu(name, command, icon, match) {
          root.closeAllMenus()
          Quickshell.execDetached([
              Quickshell.env("HOME") + "/.local/bin/windows-start-app-menu",
              name, command, icon, match || ""
          ])
      }

      function taskbarActivate(item) {
          if (item.action === "search") {
              root.closeAllMenus()
              root.startOpen = true
              search.forceActiveFocus()
          } else if (item.action === "allapps") {
              root.closeAllMenus()
              root.startOpen = true
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
              root.closeRightMenu()
              root.calendarOpen = false
              root.notificationsOpen = false
              root.powerOpen = false
              root.trayOpen = false
          }

          function toggleQuickSettings(): void {
              const shouldOpen = !root.quickSettingsOpen
              root.closeAllMenus()
              root.quickSettingsOpen = shouldOpen
          }

          function openWifi(): void {
              root.closeAllMenus()
              root.quickSettingsOpen = true
              root.wifiDetailsOpen = true
              root.refreshWifi()
              root.scanWifi()
          }

          function openBluetooth(): void {
              root.closeAllMenus()
              root.quickSettingsOpen = true
              root.bluetoothDetailsOpen = true
              root.refreshBluetooth()
              root.scanBluetooth()
          }

          function openSettings(): void {
              root.closeAllMenus()
              root.quickSettingsOpen = true
              root.openSettingsPage("home")
          }

          function openPersonalization(): void {
              root.closeAllMenus()
              root.quickSettingsOpen = true
              root.openSettingsPage("home")
              root.personalizationOpen = true
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
                      onClicked: {
                          root.startOpen = !root.startOpen
                          root.closeRightMenu()
                          root.calendarOpen = false
                          root.notificationsOpen = false
                          root.powerOpen = false
                          root.trayOpen = false
                      }
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
                          const shouldOpen = !root.quickSettingsOpen
                          root.closeAllMenus()
                          root.quickSettingsOpen = shouldOpen
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
          visible: root.quickSettingsOpen || root.systemDialogOpen
          WlrLayershell.namespace: "windows-quick-settings"
          anchors {
              left: root.taskbarEdge === "left"
              right: root.taskbarEdge !== "left"
              top: root.taskbarEdge === "top"
              bottom: root.taskbarEdge !== "top"
          }
          margins {
              left: root.taskbarEdge === "left" ? root.panelGap : 0
              right: root.taskbarEdge === "right" ? root.panelGap : 10
              top: root.taskbarEdge === "top" ? root.panelGap : 0
              bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0
          }
          implicitWidth: root.personalizationOpen || root.systemDialogOpen ? 760 : 360
          implicitHeight: root.personalizationOpen || root.systemDialogOpen ? 650 : root.settingsDetailsOpen ? 520 : (root.wifiDetailsOpen || root.bluetoothDetailsOpen) ? 420 : 286
          Behavior on implicitHeight {
              NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
          }
          exclusiveZone: 0
          color: "transparent"

          Rectangle {
              id: quickSettingsSurface
              visible: root.quickSettingsOpen
              anchors.fill: parent
              radius: 10
              color: "#aa202631"
              border.width: 1
              border.color: "#38ffffff"
              transformOrigin: Item.BottomRight
              scale: root.quickSettingsOpen ? 1 : 0.88
              opacity: root.quickSettingsOpen ? 1 : 0
              transform: Translate {
                  x: root.panelOffsetX(root.quickSettingsOpen)
                  y: root.panelOffsetY(root.quickSettingsOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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
                  visible: root.settingsDetailsOpen && !root.personalizationOpen
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
                                  { title: "Taskbar", detail: "Position, buttons, icons and motion", action: "personalize" },
                                  { title: "Weather", detail: "Location and forecast source", action: "weather" },
                                  { title: "Personalization", detail: "Presets, colors, wallpaper and animation", action: "personalize" }
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
                                          else if (modelData.action === "sound") { root.closeRightMenu(); Quickshell.execDetached(["pavucontrol"]) }
                                          else if (modelData.action === "personalize") root.personalizationOpen = true
                                          else if (modelData.action === "weather") { root.closeRightMenu(); Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/windows-weather-settings"]) }
                                          else if (modelData.action === "style") { root.closeRightMenu(); Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hypr-config-switcher"]) }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }

              Item {
                  anchors.fill: parent
                  visible: root.personalizationOpen
                  z: 20

                  Rectangle { anchors.fill: parent; radius: 10; color: "#e0202631" }
                  Rectangle {
                      id: personalizationBack
                      anchors.left: parent.left; anchors.leftMargin: 16; anchors.top: parent.top; anchors.topMargin: 14
                      width: 36; height: 36; radius: 7; color: personalizationBackMouse.containsMouse ? "#3d4654" : "transparent"
                      Text { anchors.centerIn: parent; text: "‹"; color: "white"; font.pixelSize: 28 }
                      MouseArea { id: personalizationBackMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.personalizationOpen = false }
                  }
                  Text { anchors.left: personalizationBack.right; anchors.leftMargin: 12; anchors.verticalCenter: personalizationBack.verticalCenter; text: "Personalization"; color: "white"; font.pixelSize: 22; font.bold: true; font.family: root.uiFont }
                  Rectangle {
                      id: applyChangesButton
                      anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: personalizationBack.verticalCenter
                      width: 118; height: 36; radius: 7
                      opacity: root.personalizationDirty ? 1 : 0.45
                      color: applyChangesMouse.containsMouse && root.personalizationDirty ? "#67b9e8" : "#3784ad"
                      Text { anchors.centerIn: parent; text: "Apply changes"; color: "white"; font.pixelSize: 11; font.bold: true }
                      MouseArea { id: applyChangesMouse; anchors.fill: parent; hoverEnabled: true; enabled: root.personalizationDirty; onClicked: root.applyPersonalization() }
                  }
                  Text { anchors.right: applyChangesButton.left; anchors.rightMargin: 12; anchors.verticalCenter: personalizationBack.verticalCenter; text: root.activePreset.name || "Windows 11"; color: root.personalizationDirty ? "#f3c96b" : "#60cdff"; font.pixelSize: 12; font.family: root.uiFont }

                  Flickable {
                      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                      anchors.topMargin: 64; anchors.bottomMargin: 14; anchors.leftMargin: 18; anchors.rightMargin: 18
                      contentHeight: personalizationColumns.height; clip: true

                      Row {
                          id: personalizationColumns
                          width: parent.width; spacing: 14

                          Column {
                              width: (parent.width - 14) / 2; spacing: 10
                              Text { text: "Presets"; color: "white"; font.pixelSize: 16; font.bold: true; font.family: root.uiFont }
                              Flow {
                                  width: parent.width; spacing: 6
                                  Repeater {
                                      model: root.availablePresets
                                      delegate: Rectangle {
                                          required property var modelData
                                          width: 156; height: 42; radius: 7
                                          color: root.activePreset.slug === modelData.slug ? "#405a7187" : presetMouse.containsMouse ? "#30414d5b" : "#202a3542"
                                          Text { anchors.centerIn: parent; text: modelData.name; color: "white"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter }
                                          MouseArea { id: presetMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.previewPreset(modelData.slug) }
                                      }
                                  }
                              }
                              Rectangle {
                                  width: parent.width; height: 46; radius: 8; color: "#202a3542"
                                  TextInput { id: presetName; anchors.left: parent.left; anchors.right: renameButton.left; anchors.margins: 12; anchors.verticalCenter: parent.verticalCenter; text: root.activePreset.slug === "windows-11" ? "My Windows" : (root.activePreset.name || "My Windows"); color: "white"; selectByMouse: true; font.pixelSize: 12 }
                                  Rectangle {
                                      id: renameButton; anchors.right: cloneButton.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                                      width: 70; height: 36; radius: 6
                                      color: renameMouse.containsMouse ? "#526171" : "#35414e"
                                      Text { anchors.centerIn: parent; text: "Rename"; color: "white"; font.pixelSize: 11 }
                                      MouseArea { id: renameMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.renamePreset(presetName.text) }
                                  }
                                  Rectangle {
                                      id: cloneButton; anchors.right: deleteButton.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                                      width: 72; height: 36; radius: 6; color: cloneMouse.containsMouse ? "#67b9e8" : "#3784ad"
                                      Text { anchors.centerIn: parent; text: "Save copy"; color: "white"; font.pixelSize: 10 }
                                      MouseArea { id: cloneMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clonePreset(presetName.text) }
                                  }
                                  Rectangle {
                                      id: deleteButton; anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                                      width: 58; height: 36; radius: 6
                                      opacity: root.activePreset.slug === "windows-11" ? 0.38 : 1
                                      color: deleteMouse.containsMouse && root.activePreset.slug !== "windows-11" ? "#8f3f48" : "#56343b"
                                      Text { anchors.centerIn: parent; text: "Delete"; color: "white"; font.pixelSize: 10 }
                                      MouseArea {
                                          id: deleteMouse; anchors.fill: parent; hoverEnabled: true; enabled: root.activePreset.slug !== "windows-11"
                                          onClicked: root.deletePreset(root.activePreset.slug)
                                      }
                                  }
                              }

                              Text { text: "Taskbar edge"; color: "white"; font.pixelSize: 16; font.bold: true; font.family: root.uiFont }
                              Row {
                                  spacing: 6
                                  Repeater {
                                      model: ["bottom", "top", "left", "right"]
                                      delegate: Rectangle {
                                          required property string modelData
                                          width: 76; height: 40; radius: 7; color: root.activePreset.taskbar && root.activePreset.taskbar.position === modelData ? "#3784ad" : edgeMouse.containsMouse ? "#394552" : "#252e39"
                                          Text { anchors.centerIn: parent; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); color: "white"; font.pixelSize: 11 }
                                          MouseArea { id: edgeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("taskbar.position", modelData) }
                                      }
                                  }
                              }
                              Row {
                                  spacing: 8
                                  Text { anchors.verticalCenter: parent.verticalCenter; text: "Size"; color: "white"; width: 48 }
                                  Rectangle { width: 34; height: 34; radius: 6; color: sizeDownMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "−"; color: "white"; font.pixelSize: 18 } MouseArea { id: sizeDownMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("taskbar.size", Math.max(34, root.activePreset.taskbar.size - 4)) } }
                                  Text { anchors.verticalCenter: parent.verticalCenter; text: root.activePreset.taskbar ? String(root.activePreset.taskbar.size) : "48"; color: "#60cdff"; width: 34; horizontalAlignment: Text.AlignHCenter }
                                  Rectangle { width: 34; height: 34; radius: 6; color: sizeUpMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 18 } MouseArea { id: sizeUpMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("taskbar.size", Math.min(96, root.activePreset.taskbar.size + 4)) } }
                              }
                              Text { text: "Colors and material"; color: "white"; font.pixelSize: 14; font.bold: true }
                              Row { spacing: 8
                                  Rectangle { width: 150; height: 38; radius: 7; color: backgroundMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "Background color"; color: "white"; font.pixelSize: 11 } MouseArea { id: backgroundMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openSystemDialog(backgroundPicker) } }
                                  Rectangle { width: 150; height: 38; radius: 7; color: accentMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "Accent color"; color: "white"; font.pixelSize: 11 } MouseArea { id: accentMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openSystemDialog(accentPicker) } }
                              }
                              Text { text: "App alignment"; color: "white"; font.pixelSize: 14; font.bold: true }
                              Row {
                                  spacing: 6
                                  Repeater {
                                      model: ["center", "left"]
                                      delegate: Rectangle {
                                          required property string modelData
                                          width: 110; height: 38; radius: 7
                                          color: root.activePreset.taskbar && root.activePreset.taskbar.alignment === modelData ? "#3784ad" : alignmentMouse.containsMouse ? "#394552" : "#252e39"
                                          Text { anchors.centerIn: parent; text: modelData; color: "white" }
                                          MouseArea { id: alignmentMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("taskbar.alignment", modelData) }
                                      }
                                  }
                              }
                              Text { text: "Start icon and wallpaper"; color: "white"; font.pixelSize: 14; font.bold: true }
                              Row { spacing: 8
                                  Rectangle {
                                      width: 150; height: 40; radius: 7; color: iconMouse.containsMouse ? "#394552" : "#252e39"
                                      Text { anchors.centerIn: parent; text: "Choose Start icon"; color: "white"; font.pixelSize: 11 }
                                      MouseArea { id: iconMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openImagePicker("icons.start", "Choose a Start icon", true) }
                                  }
                                  Rectangle {
                                      width: 150; height: 40; radius: 7; color: wallpaperMouse.containsMouse ? "#394552" : "#252e39"
                                      Text { anchors.centerIn: parent; text: "Choose wallpaper"; color: "white"; font.pixelSize: 11 }
                                      MouseArea { id: wallpaperMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openImagePicker("wallpaper", "Choose a wallpaper", false) }
                                  }
                              }
                              Row { spacing: 8
                                  Rectangle {
                                      width: 150; height: 40; radius: 7; color: searchIconMouse.containsMouse ? "#394552" : "#252e39"
                                      Text { anchors.centerIn: parent; text: "Choose Search icon"; color: "white"; font.pixelSize: 11 }
                                      MouseArea { id: searchIconMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openImagePicker("icons.search", "Choose a Search icon", true) }
                                  }
                                  Rectangle {
                                      width: 150; height: 40; radius: 7; color: taskViewIconMouse.containsMouse ? "#394552" : "#252e39"
                                      Text { anchors.centerIn: parent; text: "Choose Task View icon"; color: "white"; font.pixelSize: 11 }
                                      MouseArea { id: taskViewIconMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openImagePicker("icons.task_view", "Choose a Task View icon", true) }
                                  }
                              }
                          }

                          Column {
                              width: (parent.width - 14) / 2; spacing: 7
                              Text { text: "Taskbar buttons"; color: "white"; font.pixelSize: 16; font.bold: true; font.family: root.uiFont }
                              Repeater {
                                  model: [
                                      { label: "Start", key: "start" }, { label: "Search", key: "search" }, { label: "Task View", key: "task_view" },
                                      { label: "Workspaces", key: "workspaces" }, { label: "Weather", key: "weather" }, { label: "Pinned apps", key: "pinned_apps" },
                                      { label: "Running apps", key: "running_apps" }, { label: "System tray", key: "tray" }, { label: "Network", key: "network" },
                                      { label: "Volume", key: "volume" }, { label: "Clock", key: "clock" }, { label: "Notifications", key: "notifications" },
                                      { label: "Show Desktop", key: "show_desktop" }
                                  ]
                                  delegate: Rectangle {
                                      required property var modelData
                                      readonly property bool enabledValue: !!(root.activePreset.taskbar && root.activePreset.taskbar.show[modelData.key])
                                      width: parent.width; height: 34; radius: 6; color: toggleMouse.containsMouse ? "#293441" : "transparent"
                                      Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "white"; font.pixelSize: 12 }
                                      Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 20; radius: 10; color: parent.enabledValue ? "#60cdff" : "#4b5665"; Rectangle { width: 14; height: 14; radius: 7; color: "white"; anchors.verticalCenter: parent.verticalCenter; x: parent.parent.enabledValue ? 21 : 3; Behavior on x { NumberAnimation { duration: 140 } } } }
                                      MouseArea { id: toggleMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("taskbar.show." + modelData.key, !parent.enabledValue) }
                                  }
                              }
                              Text { text: "Motion"; color: "white"; font.pixelSize: 16; font.bold: true; font.family: root.uiFont }
                              Repeater {
                                  model: [{ label: "Shell panels follow taskbar", key: "shell_panels" }, { label: "Application windows", key: "windows" }, { label: "Workspace transitions", key: "workspaces" }]
                                  delegate: Rectangle {
                                      required property var modelData
                                      readonly property bool enabledValue: !!(root.activePreset.motion && root.activePreset.motion[modelData.key])
                                      width: parent.width; height: 38; radius: 6; color: motionMouse.containsMouse ? "#293441" : "transparent"
                                      Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "white"; font.pixelSize: 12 }
                                      Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.enabledValue ? "On" : "Off"; color: parent.enabledValue ? "#60cdff" : "#9aa4af" }
                                      MouseArea { id: motionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("motion." + modelData.key, !parent.enabledValue) }
                                  }
                              }
                              Text { text: "Window corners"; color: "white"; font.pixelSize: 16; font.bold: true; font.family: root.uiFont }
                              Row {
                                  spacing: 8
                                  Text { anchors.verticalCenter: parent.verticalCenter; text: "Rounding"; color: "white"; width: 72 }
                                  Rectangle { width: 34; height: 34; radius: 6; color: roundingDownMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "−"; color: "white"; font.pixelSize: 18 } MouseArea { id: roundingDownMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("appearance.window_rounding", Math.max(0, root.activePreset.appearance.window_rounding - 1)) } }
                                  Text { anchors.verticalCenter: parent.verticalCenter; text: root.activePreset.appearance ? String(root.activePreset.appearance.window_rounding) : "8"; color: "#60cdff"; width: 34; horizontalAlignment: Text.AlignHCenter }
                                  Rectangle { width: 34; height: 34; radius: 6; color: roundingUpMouse.containsMouse ? "#394552" : "#252e39"; Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 18 } MouseArea { id: roundingUpMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.changePersonalization("appearance.window_rounding", Math.min(32, root.activePreset.appearance.window_rounding + 1)) } }
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
          anchors { left: root.taskbarEdge === "left"; right: root.taskbarEdge !== "left"; top: root.taskbarEdge === "top"; bottom: root.taskbarEdge !== "top" }
          margins { left: root.taskbarEdge === "left" ? root.panelGap : 0; right: root.taskbarEdge === "right" ? root.panelGap : 10; top: root.taskbarEdge === "top" ? root.panelGap : 0; bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0 }
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
              transform: Translate {
                  x: root.panelOffsetX(root.calendarOpen); y: root.panelOffsetY(root.calendarOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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
          anchors { left: root.taskbarEdge === "left"; right: root.taskbarEdge !== "left"; top: root.taskbarEdge === "top"; bottom: root.taskbarEdge !== "top" }
          margins { left: root.taskbarEdge === "left" ? root.panelGap : 0; right: root.taskbarEdge === "right" ? root.panelGap : 10; top: root.taskbarEdge === "top" ? root.panelGap : 0; bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0 }
          implicitWidth: 370; implicitHeight: 310
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.BottomRight
              scale: root.notificationsOpen ? 1 : 0.88
              opacity: root.notificationsOpen ? 1 : 0
              transform: Translate {
                  x: root.panelOffsetX(root.notificationsOpen); y: root.panelOffsetY(root.notificationsOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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
          anchors { left: root.taskbarEdge === "left"; right: root.taskbarEdge === "right"; top: root.taskbarEdge === "top"; bottom: root.taskbarEdge === "bottom" }
          margins { left: root.taskbarEdge === "left" ? root.panelGap : 0; right: root.taskbarEdge === "right" ? root.panelGap : 0; top: root.taskbarEdge === "top" ? root.panelGap : 0; bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0 }
          implicitWidth: 270; implicitHeight: 285
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.Bottom; scale: root.powerOpen ? 1 : 0.86; opacity: root.powerOpen ? 1 : 0
              transform: Translate {
                  x: root.panelOffsetX(root.powerOpen); y: root.panelOffsetY(root.powerOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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
          anchors { left: root.taskbarEdge === "left"; right: root.taskbarEdge !== "left"; top: root.taskbarEdge === "top"; bottom: root.taskbarEdge !== "top" }
          margins { left: root.taskbarEdge === "left" ? root.panelGap : 0; right: root.taskbarEdge === "right" ? root.panelGap : 106; top: root.taskbarEdge === "top" ? root.panelGap : 0; bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0 }
          implicitWidth: 280; implicitHeight: 255
          exclusiveZone: 0; color: "transparent"
          Rectangle {
              anchors.fill: parent; radius: 11
              color: "#c7202631"; border.width: 1; border.color: "#38ffffff"
              transformOrigin: Item.BottomRight; scale: root.trayOpen ? 1 : 0.88; opacity: root.trayOpen ? 1 : 0
              transform: Translate {
                  x: root.panelOffsetX(root.trayOpen); y: root.panelOffsetY(root.trayOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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
              left: root.taskbarEdge === "left"
              right: root.taskbarEdge === "right"
              top: root.taskbarEdge === "top"
              bottom: root.taskbarEdge === "bottom"
          }

          margins {
              left: root.taskbarEdge === "left" ? root.panelGap : 0
              right: root.taskbarEdge === "right" ? root.panelGap : 0
              top: root.taskbarEdge === "top" ? root.panelGap : 0
              bottom: root.taskbarEdge === "bottom" ? root.panelGap : 0
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
              transform: Translate {
                  x: root.panelOffsetX(root.startOpen)
                  y: root.panelOffsetY(root.startOpen)
                  Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
                  Behavior on y { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
              }
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

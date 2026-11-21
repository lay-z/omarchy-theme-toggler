import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// A sun/moon bar widget that swaps between a light and a dark Omarchy theme.
// Left-click toggles; right-click opens the settings panel.
Panel {
  id: root
  moduleName: "io.github.lay-z.theme-toggler"
  ipcTarget: "io.github.lay-z.theme-toggler"
  // This panel owns its ShellIpc so `toggle` can mean "toggle the theme"
  // while `open` still opens the settings card.
  manageIpc: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string pluginId: "io.github.lay-z.theme-toggler"
  // Resolve the plugin's own directory so the bundled scripts work whether the
  // plugin was cloned by omarchy or symlinked for development.
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    try { url = decodeURIComponent(url) } catch (error) {}
    while (url.length > 1 && url.charAt(url.length - 1) === "/") url = url.slice(0, -1)
    return url
  }
  readonly property string listScript: pluginDir + "/bin/theme-toggler-list"
  readonly property string applyScript: pluginDir + "/bin/theme-toggler-apply"
  readonly property string configDir: (Quickshell.env("HOME") || "") + "/.config/omarchy/theme-toggler"
  readonly property string preHook: configDir + "/pre-toggle.sh"
  readonly property string postHook: configDir + "/post-toggle.sh"

  property var themes: []
  property var lightBackgrounds: []
  property var darkBackgrounds: []
  property string currentTheme: ""
  property string currentBackground: ""
  property bool busy: false
  property string notice: ""
  property bool noticeError: false
  property string pendingMode: ""
  property string pendingTheme: ""
  property string lightBackgroundsFor: ""
  property string darkBackgroundsFor: ""

  readonly property string configuredLightTheme: setting("lightTheme", "")
  readonly property string configuredDarkTheme: setting("darkTheme", "")
  readonly property string configuredLightBackground: setting("lightBackground", "")
  readonly property string configuredDarkBackground: setting("darkBackground", "")
  readonly property string fallbackMode: setting("mode", "dark")

  readonly property string lightTheme: Model.resolveThemeSlug(themes, configuredLightTheme, Model.defaultLightTheme(themes))
  readonly property string darkTheme: Model.resolveThemeSlug(themes, configuredDarkTheme, Model.defaultDarkTheme(themes))
  readonly property string lightThemeName: Model.themeName(lightTheme)
  readonly property string darkThemeName: Model.themeName(darkTheme)
  readonly property string currentThemeName: Model.themeName(currentTheme)
  readonly property string mode: Model.modeForTheme(currentTheme, lightTheme, darkTheme, fallbackMode)
  readonly property bool isLight: mode === "light"
  readonly property string nextMode: Model.otherMode(mode)
  readonly property var themeChoices: Model.themeOptions(themes)
  readonly property var lightBackgroundChoices: backgroundChoices(lightBackgrounds, configuredLightBackground)
  readonly property var darkBackgroundChoices: backgroundChoices(darkBackgrounds, configuredDarkBackground)
  readonly property string tooltipText: strings.t(isLight ? "panel.tooltipDark" : "panel.tooltipLight")
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

  function backgroundChoices(backgrounds, selected) {
    var choices = [{ value: "", label: strings.t("panel.backgroundDefault") }]
    var seen = { "": true }
    for (var i = 0; i < backgrounds.length; i++) {
      if (seen[backgrounds[i].path]) continue
      seen[backgrounds[i].path] = true
      choices.push({ value: backgrounds[i].path, label: backgrounds[i].name })
    }
    if (selected && !seen[selected]) {
      choices.push({
        value: selected,
        label: strings.t("panel.backgroundCustom").arg(Model.backgroundName(selected))
      })
    }
    return choices
  }

  // Keep every existing setting when one value changes. The host's
  // updateEntryInline replaces the whole shell.json entry, so a partial write
  // would drop the other theme, background, and mode keys.
  function saveSettings(patch) {
    var entry = { id: root.moduleName }
    var current = root.settings || {}
    for (var key in current) if (key !== "id") entry[key] = current[key]
    for (var patchKey in patch) entry[patchKey] = patch[patchKey]

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
      return true
    }

    root.notice = strings.t("error.settings")
    root.noticeError = true
    return false
  }

  function setLightTheme(slug) {
    saveSettings({ lightTheme: slug })
  }

  function setDarkTheme(slug) {
    saveSettings({ darkTheme: slug })
  }

  function setLightBackground(path) {
    saveSettings({ lightBackground: path })
  }

  function setDarkBackground(path) {
    saveSettings({ darkBackground: path })
  }

  function refreshThemes() {
    if (!themesProcess.running) themesProcess.running = true
  }

  function refreshState() {
    if (!stateProcess.running) stateProcess.running = true
  }

  function refreshAll() {
    refreshThemes()
    refreshState()
    loadLightBackgrounds()
    loadDarkBackgrounds()
  }

  function loadLightBackgrounds() {
    if (!lightTheme) {
      lightBackgrounds = []
      return
    }
    lightBackgroundsFor = lightTheme
    if (lightBgProcess.running) lightBgProcess.running = false
    lightBgProcess.command = [listScript, "backgrounds", lightTheme]
    lightBgProcess.running = true
  }

  function loadDarkBackgrounds() {
    if (!darkTheme) {
      darkBackgrounds = []
      return
    }
    darkBackgroundsFor = darkTheme
    if (darkBgProcess.running) darkBgProcess.running = false
    darkBgProcess.command = [listScript, "backgrounds", darkTheme]
    darkBgProcess.running = true
  }

  function ensureHooks() {
    if (hookProcess.running) return
    hookProcess.command = [listScript, "init-hooks", configDir]
    hookProcess.running = true
  }

  function openHook(path) {
    ensureHooks()
    if (!root.bar) return
    root.bar.run("omarchy launch config editor " + Model.shellQuote(path))
  }

  function toggleTheme() {
    if (busy) return

    var targetMode = nextMode
    var targetTheme = targetMode === "light" ? lightTheme : darkTheme
    var targetBackground = targetMode === "light"
      ? configuredLightBackground
      : configuredDarkBackground

    if (!targetTheme) {
      notice = strings.t("error.noThemes")
      noticeError = true
      return
    }

    root.close()
    busy = true
    notice = ""
    noticeError = false
    pendingMode = targetMode
    pendingTheme = Model.themeName(targetTheme)

    applyProcess.command = [
      applyScript,
      targetMode,
      targetTheme,
      targetBackground,
      preHook,
      postHook
    ]
    applyProcess.running = true
  }

  onLightThemeChanged: loadLightBackgrounds()
  onDarkThemeChanged: loadDarkBackgrounds()
  onThemesChanged: {
    loadLightBackgrounds()
    loadDarkBackgrounds()
  }
  onOpenedChanged: {
    if (opened) {
      refreshAll()
      ensureHooks()
    }
  }
  Component.onCompleted: {
    ensureHooks()
    refreshThemes()
    refreshState()
  }

  ShellIpc {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggleTheme() }
    function togglePanel(): void { root.toggle() }
    function refresh(): void { root.refreshAll() }
    function state(): string {
      return JSON.stringify({
        mode: root.mode,
        theme: root.currentTheme,
        background: root.currentBackground
      })
    }
  }

  // Theme changes made outside the widget (the menu, the theme switcher, a
  // terminal) still move the icon to the matching side. `omarchy theme set`
  // writes this file in place, so a watcher is enough; no polling.
  FileView {
    id: themeNameFile
    path: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    blockLoading: true
    onFileChanged: root.refreshState()
    onLoaded: root.refreshState()
  }

  Process {
    id: themesProcess
    command: [root.listScript, "themes"]
    stdout: StdioCollector { id: themesStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.themes = Model.parseThemes(themesStdout.text)
    }
  }

  Process {
    id: stateProcess
    command: [root.listScript, "state"]
    stdout: StdioCollector { id: stateStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var state = Model.parseState(stateStdout.text)
      root.currentTheme = state.theme
      root.currentBackground = state.background
    }
  }

  Process {
    id: lightBgProcess
    stdout: StdioCollector { id: lightBgStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 || root.lightBackgroundsFor !== root.lightTheme) return
      root.lightBackgrounds = Model.parseBackgrounds(lightBgStdout.text)
    }
  }

  Process {
    id: darkBgProcess
    stdout: StdioCollector { id: darkBgStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 || root.darkBackgroundsFor !== root.darkTheme) return
      root.darkBackgrounds = Model.parseBackgrounds(darkBgStdout.text)
    }
  }

  Process {
    id: hookProcess
    command: [root.listScript, "init-hooks", root.configDir]
  }

  Process {
    id: applyProcess
    stderr: StdioCollector { id: applyStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode === 0 || exitCode === 2) {
        root.saveSettings({ mode: root.pendingMode })
        root.notice = strings.t(exitCode === 2 ? "panel.appliedWithHookWarning" : "panel.applied")
          .arg(root.pendingTheme)
        root.noticeError = exitCode === 2
        root.refreshState()
        root.refreshThemes()
      } else {
        root.notice = strings.t("error.apply")
        root.noticeError = true
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isLight ? "󰖙" : "󰖔"
    slotSize: Style.bar.statusSlot
    tooltipText: root.tooltipText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) root.toggle()
      else root.toggleTheme()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(660))

    content: Item {
      id: contentRoot
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      focus: true
      Keys.onEscapePressed: root.close()

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: strings.t("panel.title")
            meta: root.busy
              ? strings.t("panel.busy")
              : strings.t("panel.current")
                  .arg(root.isLight ? strings.t("panel.mode.light") : strings.t("panel.mode.dark"))
                  .arg(root.currentThemeName !== "" ? root.currentThemeName : "—")
            foreground: root.barForeground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                text: root.isLight ? "󰖙" : "󰖔"
                textFormat: Text.PlainText
                color: root.barForeground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

            trailingControl: Component {
              ToggleSwitch {
                checked: root.isLight
                busy: root.busy
                foreground: root.barForeground
                onToggled: root.toggleTheme()
              }
            }
          }

          Text {
            width: parent.width
            visible: root.notice !== ""
            textFormat: Text.PlainText
            text: root.notice
            color: root.noticeError
              ? (root.bar ? root.bar.urgent : Commons.Color.urgent)
              : Qt.darker(root.barForeground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ModeSection {
            width: parent.width
            title: strings.t("panel.lightSection")
            themeValue: root.lightTheme
            themeChoices: root.themeChoices
            backgroundColorChoices: root.lightBackgroundChoices
            backgroundValue: root.configuredLightBackground
            onThemePicked: function(value) { root.setLightTheme(value) }
            onBackgroundPicked: function(value) { root.setLightBackground(value) }
            onBackgroundEdited: function(value) { root.setLightBackground(value) }
          }

          PanelSeparator { foreground: root.barForeground }

          ModeSection {
            width: parent.width
            title: strings.t("panel.darkSection")
            themeValue: root.darkTheme
            themeChoices: root.themeChoices
            backgroundColorChoices: root.darkBackgroundChoices
            backgroundValue: root.configuredDarkBackground
            onThemePicked: function(value) { root.setDarkTheme(value) }
            onBackgroundPicked: function(value) { root.setDarkBackground(value) }
            onBackgroundEdited: function(value) { root.setDarkBackground(value) }
          }

          PanelSeparator { foreground: root.barForeground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: strings.t("panel.hooks")
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: strings.t("panel.hooksHelp")
              color: Qt.darker(root.barForeground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Button {
              width: parent.width
              leftAlign: true
              text: strings.t("panel.editPre")
              foreground: root.barForeground
              fontFamily: root.fontFamily
              onClicked: root.openHook(root.preHook)
            }

            Button {
              width: parent.width
              leftAlign: true
              text: strings.t("panel.editPost")
              foreground: root.barForeground
              fontFamily: root.fontFamily
              onClicked: root.openHook(root.postHook)
            }
          }

          PanelSeparator { foreground: root.barForeground }

          Button {
            width: parent.width
            text: strings.t("panel.reload")
            foreground: root.barForeground
            fontFamily: root.fontFamily
            onClicked: root.refreshAll()
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: strings.t("panel.footerHint")
            color: Qt.darker(root.barForeground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            bottomPadding: Style.space(4)
          }
        }
      }
    }
  }

  component ModeSection: Column {
    id: section
    spacing: Style.space(10)

    property string title: ""
    property string themeValue: ""
    property var themeChoices: []
    property var backgroundColorChoices: []
    property string backgroundValue: ""

    signal themePicked(string value)
    signal backgroundPicked(string value)
    signal backgroundEdited(string value)

    PanelSectionHeader {
      text: section.title
      foreground: root.barForeground
      fontFamily: root.fontFamily
    }

    Dropdown {
      width: parent.width
      label: strings.t("panel.theme")
      value: section.themeValue
      options: section.themeChoices
      foreground: root.barForeground
      fontFamily: root.fontFamily
      onChanged: function(value) { section.themePicked(value) }
    }

    SearchableDropdown {
      width: parent.width
      label: strings.t("panel.background")
      value: section.backgroundValue
      options: section.backgroundColorChoices
      foreground: root.barForeground
      fontFamily: root.fontFamily
      onChanged: function(value) { section.backgroundPicked(value) }
    }

    TextField {
      id: backgroundField
      width: parent.width
      placeholderText: strings.t("panel.backgroundPathHint")
      foreground: root.barForeground
      font.family: root.fontFamily
      onEditingFinished: section.backgroundEdited(text)

      Component.onCompleted: text = section.backgroundValue

      Connections {
        target: section
        function onBackgroundValueChanged() {
          if (!backgroundField.activeFocus) backgroundField.text = section.backgroundValue
        }
      }
    }
  }
}

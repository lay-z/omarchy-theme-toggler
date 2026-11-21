// Pure helpers for the Theme Toggler plugin. Kept free of QML so the same
// functions can be exercised by the Node test suite.

function str(value) {
  return value === undefined || value === null ? "" : String(value)
}

// The same title-casing `omarchy theme list` uses: capitalise the first letter
// of every hyphen-separated word, then turn the hyphens into spaces.
function themeName(slug) {
  return str(slug)
    .replace(/(^|-)([a-z])/g, function(match, separator, letter) {
      return separator + letter.toUpperCase()
    })
    .replace(/-/g, " ")
}

function basename(path) {
  var value = str(path).replace(/\/+$/, "")
  var slash = value.lastIndexOf("/")
  return slash === -1 ? value : value.substring(slash + 1)
}

function backgroundName(path) {
  var name = basename(path)
  var dot = name.lastIndexOf(".")
  if (dot > 0) name = name.substring(0, dot)
  name = name.replace(/^[0-9]+-/, "")
  return themeName(name.replace(/_/g, "-"))
}

function arrayOf(value) {
  return Array.isArray(value) ? value : []
}

function cleanTheme(entry) {
  if (!entry || typeof entry !== "object") return null
  var slug = str(entry.slug).trim()
  if (!slug) return null
  return { slug: slug, name: str(entry.name).trim() || themeName(slug) }
}

function parseThemes(raw) {
  var parsed
  try {
    parsed = JSON.parse(str(raw) || "[]")
  } catch (error) {
    return []
  }

  var input = arrayOf(parsed)
  var themes = []
  var seen = {}
  for (var i = 0; i < input.length; i++) {
    var theme = cleanTheme(input[i])
    if (!theme || seen[theme.slug]) continue
    seen[theme.slug] = true
    themes.push(theme)
  }
  return themes
}

function cleanBackground(entry) {
  if (!entry || typeof entry !== "object") return null
  var path = str(entry.path).trim()
  if (!path) return null
  return { path: path, name: str(entry.name).trim() || backgroundName(path) }
}

function parseBackgrounds(raw) {
  var parsed
  try {
    parsed = JSON.parse(str(raw) || "[]")
  } catch (error) {
    return []
  }

  var input = arrayOf(parsed)
  var backgrounds = []
  var seen = {}
  for (var i = 0; i < input.length; i++) {
    var background = cleanBackground(input[i])
    if (!background || seen[background.path]) continue
    seen[background.path] = true
    backgrounds.push(background)
  }
  return backgrounds
}

function parseState(raw) {
  var parsed
  try {
    parsed = JSON.parse(str(raw) || "{}")
  } catch (error) {
    return { theme: "", name: "", background: "" }
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
    return { theme: "", name: "", background: "" }
  var theme = str(parsed.theme).trim()
  return {
    theme: theme,
    name: str(parsed.name).trim() || themeName(theme),
    background: str(parsed.background).trim()
  }
}

function themeSlugs(themes) {
  var out = []
  for (var i = 0; i < themes.length; i++) out.push(themes[i].slug)
  return out
}

function hasTheme(themes, slug) {
  var wanted = str(slug)
  if (!wanted) return false
  for (var i = 0; i < themes.length; i++) {
    if (themes[i].slug === wanted) return true
  }
  return false
}

function themeOptions(themes) {
  var out = []
  for (var i = 0; i < themes.length; i++) {
    out.push({ value: themes[i].slug, label: themes[i].name })
  }
  return out
}

function firstMatching(themes, candidates) {
  for (var c = 0; c < candidates.length; c++) {
    for (var i = 0; i < themes.length; i++) {
      if (themes[i].slug === candidates[c]) return themes[i].slug
    }
  }
  return ""
}

function lightPattern(slug) {
  return /(^|-)(light|latte|white|day|dawn|paper|snow)(-|$)/i.test(str(slug))
}

function defaultLightTheme(themes) {
  var preferred = firstMatching(themes, [
    "catppuccin-latte",
    "flexoki-light",
    "white",
    "solarized-light",
    "gruvbox-light"
  ])
  if (preferred) return preferred
  for (var i = 0; i < themes.length; i++) {
    if (lightPattern(themes[i].slug)) return themes[i].slug
  }
  return themes.length > 0 ? themes[0].slug : ""
}

function defaultDarkTheme(themes) {
  var preferred = firstMatching(themes, [
    "catppuccin",
    "tokyo-night",
    "gruvbox",
    "nord",
    "everforest",
    "kanagawa"
  ])
  if (preferred) return preferred
  for (var i = 0; i < themes.length; i++) {
    if (!lightPattern(themes[i].slug)) return themes[i].slug
  }
  return themes.length > 0 ? themes[0].slug : ""
}

// A configured theme wins only while it still exists. Otherwise the caller's
// default keeps the widget usable after a theme is uninstalled.
function resolveThemeSlug(themes, configured, fallback) {
  var wanted = str(configured)
  if (wanted && hasTheme(themes, wanted)) return wanted
  return str(fallback)
}

function backgroundOptions(backgrounds, selected) {
  var options = [{ value: "", label: "" }]
  var seen = { "": true }
  for (var i = 0; i < backgrounds.length; i++) {
    if (seen[backgrounds[i].path]) continue
    seen[backgrounds[i].path] = true
    options.push({ value: backgrounds[i].path, label: backgrounds[i].name })
  }
  var chosen = str(selected)
  if (chosen && !seen[chosen]) {
    options.push({ value: chosen, label: backgroundName(chosen) })
  }
  return options
}

function modeForTheme(currentTheme, lightTheme, darkTheme, fallback) {
  var current = str(currentTheme)
  if (current && current === str(lightTheme)) return "light"
  if (current && current === str(darkTheme)) return "dark"
  return str(fallback) === "light" ? "light" : "dark"
}

function otherMode(mode) {
  return str(mode) === "light" ? "dark" : "light"
}

function shellQuote(value) {
  return "'" + str(value).replace(/'/g, "'\\''") + "'"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    backgroundName: backgroundName,
    backgroundOptions: backgroundOptions,
    basename: basename,
    defaultDarkTheme: defaultDarkTheme,
    defaultLightTheme: defaultLightTheme,
    firstMatching: firstMatching,
    hasTheme: hasTheme,
    lightPattern: lightPattern,
    modeForTheme: modeForTheme,
    otherMode: otherMode,
    parseBackgrounds: parseBackgrounds,
    parseState: parseState,
    parseThemes: parseThemes,
    resolveThemeSlug: resolveThemeSlug,
    shellQuote: shellQuote,
    themeName: themeName,
    themeOptions: themeOptions,
    themeSlugs: themeSlugs
  }
}

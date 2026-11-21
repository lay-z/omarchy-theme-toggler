const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const themes = [
  { slug: "catppuccin", name: "Catppuccin" },
  { slug: "catppuccin-latte", name: "Catppuccin Latte" },
  { slug: "white", name: "White" },
  { slug: "tokyo-night", name: "Tokyo Night" }
]

test("themeName matches omarchy title casing", () => {
  assert.equal(Model.themeName("catppuccin-latte"), "Catppuccin Latte")
  assert.equal(Model.themeName("tokyo-night"), "Tokyo Night")
  assert.equal(Model.themeName(""), "")
})

test("backgroundName strips folders, extensions, and numeric prefixes", () => {
  assert.equal(Model.backgroundName("/tmp/1-totoro.webp"), "Totoro")
  assert.equal(Model.backgroundName("/tmp/blue_eye.png"), "Blue Eye")
})

test("parseThemes rejects junk and de-duplicates slugs", () => {
  assert.deepEqual(Model.parseThemes("not json"), [])
  assert.deepEqual(Model.parseThemes('{"slug":"nope"}'), [])
  assert.deepEqual(
    Model.parseThemes('[{"slug":"a","name":"A"},{"slug":"a","name":"Again"},{"slug":"b"}]'),
    [{ slug: "a", name: "A" }, { slug: "b", name: "B" }]
  )
})

test("parseBackgrounds de-duplicates paths", () => {
  assert.deepEqual(
    Model.parseBackgrounds('[{"path":"/a.png","name":"A"},{"path":"/a.png","name":"A2"}]'),
    [{ path: "/a.png", name: "A" }]
  )
})

test("parseState survives malformed input", () => {
  assert.deepEqual(Model.parseState("bad"), { theme: "", name: "", background: "" })
  assert.deepEqual(Model.parseState('{"theme":"white"}'), {
    theme: "white",
    name: "White",
    background: ""
  })
})

test("preferred defaults pick a light and a dark theme", () => {
  assert.equal(Model.defaultLightTheme(themes), "catppuccin-latte")
  assert.equal(Model.defaultDarkTheme(themes), "catppuccin")
})

test("theme matching falls back when the saved theme is gone", () => {
  assert.equal(Model.resolveThemeSlug(themes, "white", "catppuccin"), "white")
  assert.equal(Model.resolveThemeSlug(themes, "removed", "catppuccin"), "catppuccin")
})

test("mode derives from the current theme, then the saved fallback", () => {
  assert.equal(Model.modeForTheme("white", "white", "catppuccin", "dark"), "light")
  assert.equal(Model.modeForTheme("catppuccin", "white", "catppuccin", "light"), "dark")
  assert.equal(Model.modeForTheme("nord", "white", "catppuccin", "light"), "light")
  assert.equal(Model.modeForTheme("", "", "", "nonsense"), "dark")
})

test("background options always lead with the theme default", () => {
  const backgrounds = [{ path: "/a.png", name: "A" }]
  assert.deepEqual(Model.backgroundOptions(backgrounds, ""), [
    { value: "", label: "" },
    { value: "/a.png", label: "A" }
  ])
  assert.equal(Model.backgroundOptions(backgrounds, "/b.png").length, 3)
})

test("shellQuote keeps a path with spaces as one argument", () => {
  assert.equal(Model.shellQuote("/tmp/a b.png"), "'/tmp/a b.png'")
  assert.equal(Model.shellQuote("it's here"), "'it'\\''s here'")
})

var M = require("./Model.js")
var fails = 0

function assert(name, cond) {
  if (cond) {
    console.log("ok  " + name)
    return
  }
  fails += 1
  console.log("FAIL  " + name)
}

var t0 = new Date(2026, 7, 13, 15, 0, 0).getTime()
var night = new Date(2026, 7, 13, 23, 30, 0).getTime()

var idle = M.defaultState(t0)
assert("v4 default", idle.version === 4 && idle.mood === "chill")
assert("default meters", M.meters(idle).length === 3 && M.meters(idle)[0].label === "Happiness")
assert("visitor rank", M.bondRank(0) === "visitor")
assert("roommate rank", M.bondRank(10) === "roommate")
assert("family rank", M.bondRank(30) === "family")
assert("river kin rank", M.bondRank(80) === "river kin")

assert("empty parse", M.parseState("", t0).version === 4)
assert("bad json", M.parseState("{", t0).happiness === 72)
assert("loadavg", M.parseLoad("1.25 0.80 0.40 1/234 99") === 1.25)
assert("load empty", M.parseLoad("") === 0)
assert("cpu range", M.parseCpuCount("0-31") === 32)
assert("cpu groups", M.parseCpuCount("0-3,8,10-11") === 7)
assert("cpu fallback", M.parseCpuCount("nope") === 1)
assert("four cpu parity", M.normalizeLoad(4.5, 4) === 1.125)
assert("hugin moderate load", M.normalizeLoad(16, 32) === 0.5)
assert("load percent", M.loadPercent(1.125) === 113)

var v1 = M.parseState(JSON.stringify({
  version: 1,
  happiness: 40,
  belly: 20,
  zen: 10,
  pets: 3,
  bond: 4,
}), t0)
assert("migrates v1 pet", v1.version === 4 && v1.happiness === 40 && v1.pets === 3)

var stack = M.parseState(JSON.stringify({
  version: 3,
  languages: { python: { ms: 90000 } },
}), t0)
assert("drops language stack", stack.happiness === 72 && stack.languages == null)

var s = M.tick(idle, 0.2, t0)
assert("zero dt keeps meters", s.happiness === 72)

s = M.tick(idle, 0.2, t0 + 10 * 60 * 1000)
assert("decays belly", s.belly < 58 && s.belly > 50)
assert("decays happiness", s.happiness < 72 && s.happiness > 68)

var hot = M.tick(Object.assign(M.defaultState(t0), { zen: 50, lastTickMs: t0 }), 1.25, t0 + 20 * 60 * 1000)
assert("load cooks zen", hot.zen < 50)
assert("fried from load", M.deriveMood(Object.assign(M.defaultState(t0), { zen: 50 }), 1.125, t0) === "fried")
assert("hugin moderate load stays chill",
  M.deriveMood(Object.assign(M.defaultState(t0), { zen: 50 }), M.normalizeLoad(16, 32), t0) === "chill")
assert("hugin saturated load fries",
  M.deriveMood(Object.assign(M.defaultState(t0), { zen: 50 }), M.normalizeLoad(36, 32), t0) === "fried")
assert("fried from zen", M.deriveMood(Object.assign(M.defaultState(t0), { zen: 10 }), 0.1, t0) === "fried")

var lonely = Object.assign(M.defaultState(t0), { happiness: 30, lastInteractMs: t0 - 7 * 60 * 60 * 1000 })
assert("lonely after neglect", M.deriveMood(lonely, 0.2, t0) === "lonely")

var nap = Object.assign(M.defaultState(night), { happiness: 60, lastInteractMs: night })
assert("naps at night", M.deriveMood(nap, 0.2, night) === "napping")

var soaked = Object.assign(M.defaultState(t0), {
  zen: 90, happiness: 80, lastInteractMs: t0, lastAction: "soak", lastActionMs: t0,
})
assert("soaked after soak", M.deriveMood(soaked, 0.2, t0) === "soaked")
assert("soaked expires", M.deriveMood(soaked, 0.2, t0 + 160000) === "chill")

var yum = Object.assign(M.defaultState(t0), {
  belly: 90, zen: 50, happiness: 50, lastInteractMs: t0, lastAction: "orange", lastActionMs: t0,
})
assert("munching after orange", M.deriveMood(yum, 0.2, t0) === "munching")

var hype = Object.assign(M.defaultState(t0), {
  happiness: 95, zen: 50, belly: 40, lastInteractMs: t0, lastAction: "pet", lastActionMs: t0,
})
assert("hyped after pet", M.deriveMood(hype, 0.2, t0) === "hyped")

var meh = Object.assign(M.defaultState(t0), { happiness: 20, zen: 50, lastInteractMs: t0 })
assert("meh when sad", M.deriveMood(meh, 0.2, t0) === "meh")

var p = M.pet(idle, 0.2, t0 + 1000)
assert("pet raises happiness", p.happiness > idle.happiness && p.pets === 1 && p.bond === 1)
assert("pet marks action", p.lastAction === "pet")
var o = M.orange(idle, 0.2, t0 + 1000)
assert("orange fills belly", o.belly > idle.belly && o.oranges === 1)
var k = M.soak(idle, 0.2, t0 + 1000)
assert("soak restores zen", k.zen > idle.zen && k.soaks === 1)

var w1 = M.wisdom(idle, 0.2, t0 + 1000)
var w2 = M.wisdom(w1, 0.2, t0 + 2000)
assert("wisdom writes a line", w1.lastWisdom.length > 10)
assert("wisdom does not repeat", w1.lastWisdom !== w2.lastWisdom)
assert("wisdom advances index", w2.wisdomIndex === 2)
assert("wisdom marks action", w1.lastAction === "wisdom")
var afterWisdom = M.wisdom(M.soak(idle, 0.2, t0 + 1000), 0.2, t0 + 2000)
assert("wisdom leaves soaked", afterWisdom.mood !== "soaked")

var toastA = M.pet(idle, 0.2, t0 + 1000).toast
var toastB = M.pet(idle, 0.2, t0 + 1000).toast
assert("toast deterministic", toastA === toastB && toastA.length > 0)

var round = M.parseState(M.serializeState(p), t0 + 5000)
assert("roundtrip pets", round.pets === 1 && round.version === 4)
assert("toast not persisted", JSON.parse(M.serializeState(p)).toast == null)

assert("portrait soaked", M.portraitFor("soaked") === "capy-soaked.png")
assert("portrait chill", M.portraitFor("chill") === "capy.png")
assert("four actions", M.actions().map(function(a) { return a.id }).join(",") === "pet,orange,soak,wisdom")
assert("bar word", M.moodMeta("chill").bar === "Capy")
assert("tooltip", M.tooltip(idle, 0.375).indexOf("system load 38%") !== -1)

assert("action count pets", M.actionCount(p, "pet") === 1 && M.actionCount(p, "orange") === 0)
assert("button label with count", M.actionButtonLabel(p, M.actions()[0]) === "Pet  ·  1")
assert("button label wisdom", M.actionButtonLabel(p, M.actions()[3]) === "Wisdom")
assert("tooltip has key", M.actionTooltip(M.actions()[2]).indexOf("s") !== -1)
assert("last action pet", M.lastActionLine(p) === "just petted")
assert("last action soak", M.lastActionLine(k) === "just soaked")
assert("last action wisdom", M.lastActionLine(w1) === "just spoke")
assert("last action empty", M.lastActionLine(idle) === "")
assert("keys p/1", M.textKeyAction("p") === "pet" && M.textKeyAction("1") === "pet")
assert("keys o/s/w", M.textKeyAction("O") === "orange" && M.textKeyAction("s") === "soak" && M.textKeyAction("4") === "wisdom")
assert("keys ignore", M.textKeyAction("x") === "")
assert("wisdom has no toast", w1.toast === "")
assert("lounge hint", M.loungeHint().indexOf("p pet") === 0)

if (fails) {
  console.log(fails + " failed")
  process.exit(1)
}
console.log("all good")

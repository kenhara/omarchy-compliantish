import QtQuick
import Quickshell
import Quickshell.Io

// Local probe runner + cache for Compliantish.
// Read-only: runs scripts/probe.sh, no network, no sudo.
Item {
  id: store

  property int refreshIntervalSec: 900
  property int screenLockMaxSec: 900
  property bool notifyOnFail: false
  // Per-check toggles — all five on by default (union of Vanta 4 + Drata 5).
  // Primary UI: panel Checks menu; schema / widget settings remain secondary.
  property bool enableDiskEncryption: true
  property bool enableScreenLock: true
  property bool enableAntivirus: true
  property bool enablePasswordManager: true
  property bool enableAutoUpdates: true
  property bool panelOpen: false

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/compliantish"
  readonly property string cachePath: cacheDir + "/last.json"
  readonly property string pluginDir: String(Qt.resolvedUrl("."))
    .replace(/^file:\/\//, "")
    .replace(/\/$/, "")
  readonly property string probePath: pluginDir + "/scripts/probe.sh"

  property var checks: []
  property var meta: ({})
  property string probedAt: ""
  property string dataSource: "none"   // disk | probe | none
  property bool loading: false
  property string lastError: ""
  property string toastText: ""
  property var notifiedFails: ({})   // code -> YYYY-MM-DD

  property string probeBuf: ""
  readonly property int maxProbeBytes: 65536
  property bool probeOverflow: false
  readonly property int maxCacheBytes: 262144
  property string cacheBuf: ""
  property bool cacheOverflow: false

  function isCheckEnabled(code) {
    var c = String(code || "")
    if (c === "HD") return !!store.enableDiskEncryption
    if (c === "SL") return !!store.enableScreenLock
    if (c === "AV") return !!store.enableAntivirus
    if (c === "PW") return !!store.enablePasswordManager
    if (c === "AU") return !!store.enableAutoUpdates
    return true
  }

  // Only enabled checks appear in the panel and count toward the bar.
  // Touch every enable flag so QML re-evaluates when settings change.
  readonly property var enabledChecks: {
    var _e = [
      store.enableDiskEncryption,
      store.enableScreenLock,
      store.enableAntivirus,
      store.enablePasswordManager,
      store.enableAutoUpdates
    ]
    var out = []
    var list = store.checks || []
    for (var i = 0; i < list.length; i++) {
      if (store.isCheckEnabled(list[i].code))
        out.push(list[i])
    }
    return out
  }

  readonly property int passCount: {
    var n = 0
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].status || "").toLowerCase() === "pass")
        n++
    }
    return n
  }
  readonly property int failCount: {
    var n = 0
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].status || "").toLowerCase() === "fail")
        n++
    }
    return n
  }
  readonly property int unknownCount: {
    var n = 0
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].status || "").toLowerCase() === "unknown")
        n++
    }
    return n
  }
  readonly property int totalCount: (store.enabledChecks || []).length
  readonly property string worstStatus: {
    if (store.failCount > 0) return "fail"
    if (store.unknownCount > 0 || store.totalCount === 0) return "unknown"
    return "pass"
  }
  // Bar glyph: FA lock (\uf023) — tintable via Text.color; color emoji 🔒 is not
  readonly property string barGlyph: "\uf023"
  readonly property string barLabel: store.barGlyph
  // Visible UI lists use full names; JSON `code` keys stay internal.
  readonly property string failListText: {
    var fails = []
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].status || "").toLowerCase() === "fail")
        fails.push(String(list[i].label || list[i].code || "?"))
    }
    return fails.join(", ")
  }
  readonly property string unknownListText: {
    var unk = []
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].status || "").toLowerCase() === "unknown")
        unk.push(String(list[i].label || list[i].code || "?"))
    }
    return unk.join(", ")
  }
  readonly property string barTooltipDetail: {
    var parts = []
    if (store.failCount > 0)
      parts.push("fail: " + store.failListText)
    if (store.unknownCount > 0)
      parts.push("unknown: " + store.unknownListText)
    if (!parts.length && store.totalCount > 0)
      parts.push("all pass")
    if (!store.totalCount)
      parts.push("no checks enabled")
    return parts.join(" · ")
  }
  readonly property string lastUpdatedText: formatUpdated(store.probedAt)

  signal checkEnableChanged(string code, bool enabled)

  // Full definitions for Checks menu (always five; enabled flags separate).
  readonly property var allCheckDefs: [
    { code: "HD", label: "Hard drive encryption", enableProp: "enableDiskEncryption" },
    { code: "SL", label: "Screen lock", enableProp: "enableScreenLock" },
    { code: "AV", label: "Antivirus", enableProp: "enableAntivirus" },
    { code: "PW", label: "Password manager", enableProp: "enablePasswordManager" },
    { code: "AU", label: "Automatic updates", enableProp: "enableAutoUpdates" }
  ]

  readonly property string refreshIntervalLabel: {
    var sec = Number(store.refreshIntervalSec) || 900
    if (sec < 60) return sec + "s"
    if (sec % 3600 === 0) {
      var h = Math.round(sec / 3600)
      return h + "h"
    }
    if (sec % 60 === 0) {
      var m = Math.round(sec / 60)
      return m + "m"
    }
    return Math.round(sec / 60) + "m"
  }

  function setCheckEnabled(code, enabled) {
    var c = String(code || "")
    var on = !!enabled
    var prev = store.isCheckEnabled(c)
    if (c === "HD") store.enableDiskEncryption = on
    else if (c === "SL") store.enableScreenLock = on
    else if (c === "AV") store.enableAntivirus = on
    else if (c === "PW") store.enablePasswordManager = on
    else if (c === "AU") store.enableAutoUpdates = on
    else return false
    store.checkEnableChanged(c, on)
    store.persistToDisk()
    // Re-probe when turning a check back on so the row is fresh.
    if (on && !prev)
      Qt.callLater(function() { store.refresh() })
    return true
  }

  function applySettings(opts) {
    opts = opts || {}
    if (opts.refreshIntervalSec !== undefined) {
      var n = Number(opts.refreshIntervalSec)
      if (!isFinite(n)) n = 900
      store.refreshIntervalSec = Math.max(60, Math.min(86400, Math.round(n)))
      refreshTimer.interval = store.refreshIntervalSec * 1000
    }
    if (opts.screenLockMaxSec !== undefined) {
      var s = Number(opts.screenLockMaxSec)
      if (!isFinite(s)) s = 900
      store.screenLockMaxSec = Math.max(60, Math.min(86400, Math.round(s)))
    }
    if (opts.notifyOnFail !== undefined)
      store.notifyOnFail = !!opts.notifyOnFail
    if (opts.enableDiskEncryption !== undefined)
      store.enableDiskEncryption = !!opts.enableDiskEncryption
    if (opts.enableScreenLock !== undefined)
      store.enableScreenLock = !!opts.enableScreenLock
    if (opts.enableAntivirus !== undefined)
      store.enableAntivirus = !!opts.enableAntivirus
    if (opts.enablePasswordManager !== undefined)
      store.enablePasswordManager = !!opts.enablePasswordManager
    if (opts.enableAutoUpdates !== undefined)
      store.enableAutoUpdates = !!opts.enableAutoUpdates
  }

  function formatUpdated(iso) {
    if (!iso) return "never"
    var t = Date.parse(iso)
    if (!isFinite(t)) return String(iso)
    var sec = Math.max(0, Math.floor((Date.now() - t) / 1000))
    if (sec < 60) return "just now"
    if (sec < 3600) return Math.floor(sec / 60) + "m ago"
    if (sec < 86400) return Math.floor(sec / 3600) + "h ago"
    return Math.floor(sec / 86400) + "d ago"
  }

  function statusColorKind(status) {
    var s = String(status || "").toLowerCase()
    if (s === "pass") return "pass"
    if (s === "fail") return "fail"
    return "unknown"
  }

  function emptyChecks() {
    return [
      { code: "HD", label: "Hard drive encryption", status: "unknown", detail: "not probed yet", fixCommand: "", configPath: "" },
      { code: "SL", label: "Screen lock", status: "unknown", detail: "not probed yet", fixCommand: "", configPath: "" },
      { code: "AV", label: "Antivirus", status: "unknown", detail: "not probed yet", fixCommand: "", configPath: "" },
      { code: "PW", label: "Password manager", status: "unknown", detail: "not probed yet", fixCommand: "", configPath: "" },
      { code: "AU", label: "Automatic updates", status: "unknown", detail: "not probed yet", fixCommand: "", configPath: "" }
    ]
  }

  function applyPayload(obj, source) {
    if (!obj || typeof obj !== "object") return false
    var list = obj.checks
    if (!list || !list.length) return false
    var prev = store.checks || []
    var prevMap = ({})
    for (var i = 0; i < prev.length; i++)
      prevMap[String(prev[i].code || "")] = String(prev[i].status || "").toLowerCase()

    store.checks = list
    store.meta = obj.meta || ({})
    store.probedAt = obj.probedAt || ""
    store.dataSource = source || "probe"
    store.lastError = ""

    if (store.notifyOnFail)
      store.maybeNotifyFails(prevMap, list)

    return true
  }

  function todayKey() {
    var d = new Date()
    var m = d.getMonth() + 1
    var day = d.getDate()
    return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
  }

  function maybeNotifyFails(prevMap, list) {
    var day = store.todayKey()
    var map = store.notifiedFails || ({})
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      var code = String(c.code || "")
      var st = String(c.status || "").toLowerCase()
      if (st !== "fail") continue
      if (!store.isCheckEnabled(code)) continue
      var prev = String(prevMap[code] || "")
      if (prev === "fail") continue
      if (map[code] === day) continue
      map[code] = day
      var name = String(c.label || code || "check")
      store.notifySend("Compliantish", name + " failed — " + (c.detail || "see panel"))
    }
    store.notifiedFails = map
  }

  function notifySend(title, body) {
    try {
      notifyProc.command = [
        "notify-send",
        "-a", "Compliantish",
        "-u", "normal",
        String(title || "Compliantish"),
        String(body || "")
      ]
      notifyProc.running = true
    } catch (e) {}
  }

  function showToast(msg) {
    store.toastText = String(msg || "")
    toastClear.restart()
  }

  function copyText(text) {
    var t = String(text || "")
    if (!t.length) {
      store.showToast("Nothing to copy")
      return false
    }
    try {
      if (typeof Quickshell !== "undefined" && Quickshell.clipboardText !== undefined) {
        Quickshell.clipboardText = t
        store.showToast("Copied")
        return true
      }
    } catch (e) {}
    // Shell fallback: wl-copy / xclip / xsel; bash -c (not -lc).
    // Toast only on copyProc success (onExited) — never claim Copied early.
    copyProc.command = [
      "bash", "-c",
      't="$1"; if command -v wl-copy >/dev/null 2>&1; then printf "%s" "$t" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$t" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$t" | xsel --clipboard --input; else exit 127; fi',
      "st-copy", t
    ]
    copyProc.running = true
    return true
  }

  function copyFix(check) {
    if (!check) return false
    var cmd = String(check.fixCommand || "")
    if (!cmd.length) {
      store.showToast("No fix command")
      return false
    }
    return store.copyText(cmd)
  }

  function openConfig(check) {
    if (!check) return false
    var path = String(check.configPath || "")
    if (!path.length) {
      store.showToast("No config path")
      return false
    }
    openUrlProc.command = ["xdg-open", path]
    openUrlProc.running = true
    return true
  }

  function buildSummary() {
    var lines = []
    lines.push("# Compliantish evidence summary")
    lines.push("")
    lines.push("Probed: " + (store.probedAt || "(unknown)"))
    lines.push("Host: " + ((store.meta && store.meta.hostname) || ""))
    lines.push("OS: " + ((store.meta && store.meta.osPretty) || ""))
    lines.push("Kernel: " + ((store.meta && store.meta.kernel) || ""))
    lines.push("Pass: " + store.passCount + "/" + store.totalCount + " (enabled checks)")
    lines.push("")
    var list = store.enabledChecks || []
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      lines.push("- **" + (c.label || c.code || "?") + "** — **"
        + String(c.status || "unknown").toUpperCase() + "** — " + (c.detail || ""))
    }
    var all = store.checks || []
    var off = []
    for (var j = 0; j < all.length; j++) {
      if (!store.isCheckEnabled(all[j].code))
        off.push(String(all[j].label || all[j].code || "?"))
    }
    if (off.length)
      lines.push("\n_Disabled (not counted): " + off.join(", ") + "_")
    lines.push("")
    lines.push("_Unofficial local probe. Not affiliated with Drata, Inc. or Vanta._")
    lines.push("")
    return lines.join("\n")
  }

  function copySummary() {
    return store.copyText(store.buildSummary())
  }

  function persistToDisk(obj) {
    var body = JSON.stringify(obj || buildCacheObject(), null, 2) + "\n"
    cacheWriteProc.command = [
      "bash", "-c",
      'dir=$(dirname "$1"); mkdir -p "$dir" && printf "%s" "$2" > "$1"',
      "st-write", store.cachePath, body
    ]
    cacheWriteProc.running = true
  }

  function buildCacheObject() {
    return {
      version: 1,
      probedAt: store.probedAt,
      screenLockMaxSec: store.screenLockMaxSec,
      meta: store.meta || ({}),
      checks: store.checks || [],
      notifiedFails: store.notifiedFails || ({}),
      enableDiskEncryption: !!store.enableDiskEncryption,
      enableScreenLock: !!store.enableScreenLock,
      enableAntivirus: !!store.enableAntivirus,
      enablePasswordManager: !!store.enablePasswordManager,
      enableAutoUpdates: !!store.enableAutoUpdates
    }
  }

  function refresh() {
    if (store.loading && probeProc.running)
      return
    store.loading = true
    store.lastError = ""
    store.probeBuf = ""
    store.probeOverflow = false
    probeProc.command = ["bash", store.probePath, String(store.screenLockMaxSec)]
    probeProc.running = true
  }

  function onProbeFinished(exitCode) {
    store.loading = false
    if (store.probeOverflow) {
      store.probeBuf = ""
      store.probeOverflow = false
      return
    }
    var raw = store.probeBuf || ""
    store.probeBuf = ""
    if (!raw.length) {
      store.lastError = "probe produced no output (exit " + exitCode + ")"
      return
    }
    try {
      var obj = JSON.parse(raw)
      if (!store.applyPayload(obj, "probe")) {
        store.lastError = "probe JSON missing checks"
        return
      }
      // Persist merged cache (checks + notify debounce), not raw probe-only JSON.
      store.persistToDisk()
    } catch (e) {
      store.lastError = "probe JSON parse failed"
    }
  }

  function loadDiskText(text) {
    try {
      var obj = JSON.parse(text || "{}")
      if (obj.notifiedFails)
        store.notifiedFails = obj.notifiedFails
      // Rehydrate Checks-menu toggles when host settings are not writable
      if (obj.enableDiskEncryption !== undefined)
        store.enableDiskEncryption = !!obj.enableDiskEncryption
      if (obj.enableScreenLock !== undefined)
        store.enableScreenLock = !!obj.enableScreenLock
      if (obj.enableAntivirus !== undefined)
        store.enableAntivirus = !!obj.enableAntivirus
      if (obj.enablePasswordManager !== undefined)
        store.enablePasswordManager = !!obj.enablePasswordManager
      if (obj.enableAutoUpdates !== undefined)
        store.enableAutoUpdates = !!obj.enableAutoUpdates
      return store.applyPayload(obj, "disk")
    } catch (e) {
      return false
    }
  }

  function bootstrap() {
    if (!store.checks || !store.checks.length)
      store.checks = store.emptyChecks()
    store.cacheBuf = ""
    store.cacheOverflow = false
    cacheReadProc.running = true
  }

  function onCacheLoaded(text) {
    if (text && text.length > 2 && store.loadDiskText(text)) {
      // Soft refresh in background
      Qt.callLater(function() { store.refresh() })
      return
    }
    store.refresh()
  }

  function handleSummonPayload(obj) {
    if (obj === undefined || obj === null) return false
    var o = obj
    if (typeof obj === "string") {
      try { o = JSON.parse(obj) } catch (e) { return false }
    }
    if (!o || typeof o !== "object") return false
    var acted = false
    if (o.refresh) {
      store.refresh()
      acted = true
    }
    if (o.copyEvidence || o.copySummary) {
      store.copySummary()
      acted = true
    }
    return acted
  }

  Component.onCompleted: {
    refreshTimer.interval = store.refreshIntervalSec * 1000
    store.bootstrap()
  }

  Timer {
    id: refreshTimer
    interval: 900000
    running: true
    repeat: true
    onTriggered: store.refresh()
  }

  Timer {
    id: toastClear
    interval: 1800
    repeat: false
    onTriggered: store.toastText = ""
  }

  Process {
    id: cacheReadProc
    running: false
    command: ["head", "-c", String(store.maxCacheBytes + 1), store.cachePath]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (store.cacheOverflow) return
        store.cacheBuf += chunk
        if (store.cacheBuf.length > store.maxCacheBytes) {
          store.cacheOverflow = true
          store.cacheBuf = ""
        }
      }
    }
    onExited: function(exitCode, exitStatus) {
      var txt = store.cacheBuf
      var over = store.cacheOverflow
      store.cacheBuf = ""
      store.cacheOverflow = false
      if (over || exitCode !== 0) {
        store.refresh()
        return
      }
      store.onCacheLoaded(txt)
    }
  }

  Process {
    id: cacheWriteProc
    running: false
  }

  Process {
    id: openUrlProc
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0)
        store.showToast("Opened")
      else
        store.showToast("Open failed")
    }
  }

  Process {
    id: notifyProc
    running: false
  }

  Process {
    id: copyProc
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0)
        store.showToast("Copied")
      else if (exitCode === 127)
        store.showToast("No clipboard tool")
      else
        store.showToast("Copy failed")
    }
  }

  Process {
    id: probeProc
    running: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (store.probeOverflow) return
        store.probeBuf += chunk
        if (store.probeBuf.length > store.maxProbeBytes) {
          store.probeOverflow = true
          store.probeBuf = ""
          store.lastError = "probe output exceeded " + store.maxProbeBytes + " bytes"
          probeProc.running = false
        }
      }
    }
    stderr: SplitParser {
      onRead: function(line) {
        // keep last stderr snippet for debugging
        var s = String(line || "")
        if (s.length)
          store.lastError = s
      }
    }
    onExited: function(exitCode, exitStatus) {
      store.onProbeFinished(exitCode)
    }
  }
}

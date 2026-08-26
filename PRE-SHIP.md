# Compliantish — Quattro pre-ship checklist (0.5.21)

## 0.5.21 security pass

Cache writes go through `scripts/load-cache.py --write` (exclusive tmp + `os.replace`).
`openConfig` is absolute local paths only. Probe/error/meta/toast/detail/label `Text`
items set `textFormat: Text.PlainText`. Strings are neutralized at ingest (clamp, strip
tags and markdown images, enum status/code). PRE-SHIP item 12 matches the QML.

## PRE-SHIP note — discoverability (0.5.4)

Patch bump for marketplace discoverability before UTM smoke: expanded `keywords` + `barWidget.aliases` (Drata/Vanta/SOC 2/encryption/ClamAV/1Password…); README Discoverability; suggest missing tag `compliance`. Category stays **System**. No QML/probe change.


Same 17-item checklist as siblings (Encyclopedic, Scriptural, Enricherino,
Rocketlauncher). Applied on top of the 0.5.1 audit map (`AUDIT-NOTES.md`).

## Checklist

| # | Rule | Status |
|---|------|--------|
| 1 | No `Style.font.size(` — named tokens only | **pass** — Panel / CheckRow use `body` / `bodySmall` / `caption` |
| 2 | monospace / `bar.fontFamily` fallbacks | **pass** — `bar ? bar.fontFamily : "monospace"` |
| 3 | `Quickshell.clipboardText` | **pass** — ComplianceStore `copyText` |
| 4 | `bash -c` if/elif clipboard; toast on success only | **pass** — wl-copy → xclip → xsel; toast on `copyProc` exit 0 |
| 5 | No `env KEY=` argv | **pass** — probe argv is path + screenLockMaxSec only; PATH via `Process.environment` |
| 6 | No agent workspace paths in public docs | **pass** |
| 7 | LICENSE second `Software` unquoted | **pass** — canonical MIT |
| 8 | README hero `preview.png`; Install + Remove | **pass** |
| 9 | FileView cache no mkdir race | **Superseded (0.5.21)** — `load-cache.py --write` exclusive open + replace; no FileView `setText`, no bash `printf >` |
| 10 | Dead `dataChanged` delete | **pass** — signal + calls removed; keep `checkEnableChanged` |
| 11 | Honest open/copy toasts (bool return) | **pass** — Copied/Opened only on real success; Open refused on unsafe path |
| 12 | `PlainText` if remote/untrusted text | **pass (0.5.21)** — Panel.qml and CheckRow.qml set `textFormat: Text.PlainText` on every probe/error/meta/toast/detail/label binding. Neutralize at `applyPayload`/`loadDiskText`. |
| 13 | Hover; scroll if needed | **pass** — hover fills kept; Panel `Flickable` |
| 14 | Version sync | **pass** — 0.5.21 across manifest / README / CHANGELOG |
| 15 | Integer schema min/max/step | **pass** — refreshIntervalSec + screenLockMaxSec |
| 16 | No fake summon APIs | **pass** — handlers kept; README IPC honest (payload may drop) |
| 17 | Controls L/R/M; pitch; no `curl\|sh` | **pass** — L toggle / M refresh / R close; Install via `omarchy plugin add` |

## ST-specific keeps (do not regress)

| Keep | Status |
|------|--------|
| crypt ≠ plain LVM mapper name | **kept** — HD via `TYPE=crypt` / crypttab / parent chain |
| lock-listener timeout only | **kept** — hypridle per-listener lock-bearing `on-timeout` |
| AU timers genuinely scheduled | **kept** — active or enabled/enabled-runtime; no `--all` |
| Unknown ≠ fail | **kept** — amber unknown, never silent red |
| enable* persist | **kept** — cache + Checks menu + `mirrorSettingsEnable` |
| probes read-only | **kept** — no sudo / `pacman -S` at runtime |
| fixCommand clipboard-only | **kept** — Copy fix never executes the command |
| HC-05 cache read | **kept** — O_NOFOLLOW + O_NONBLOCK + regular file, fail closed |
| KeyboardPanel shell | **kept** — Panel wrapped in KeyboardPanel + PanelKeyCatcher |
| unofficial footer | **kept** — “Unofficial · not Drata or Vanta · Unknown ≠ fail” |

## Pre-ship grep (expect empty)

```
Style.font.size(
Quickshell.clipboard[^T]
bash -lc
ensureCacheDir
signal dataChanged
agent-workspace absolute paths
```

## Verify

- `bash -n scripts/probe.sh`
- Plain LVM mapper name alone does not HD-pass
- Versions all say **0.5.21**
- Isolated /tmp: symlink write does not follow; FIFO-no-writer does not hang; `openConfig` sanitizer rejects `https://` and relative paths

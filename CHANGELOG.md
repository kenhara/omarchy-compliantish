# Changelog

## 0.5.21

- Exclusive cache write: `load-cache.py --write` mkdir 0700, `O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW` tmp, fsync, `os.replace` onto `last.json` (no bash `printf >`).
- `openConfig` allows only absolute local paths (`/`, no `://`, no `\\`, no leading `-`); `xdg-open -- path`. Refuse + toast otherwise.
- `notify-send` gets `--` before title/body; strip leading `-`.
- Neutralize probe strings at ingest (clamp, strip tags and markdown images, enum status/code); bound `checks.length`; drop oversize records. `Text.PlainText` on probe/error/meta/toast/detail/label bindings.
- Cache read fail-closed if `O_NOFOLLOW`/`O_NONBLOCK` missing; add `O_CLOEXEC`. Probe and helper `PATH=/usr/bin:/bin`.


## 0.5.20

- Harden cache read against symlink/FIFO trust path: `scripts/load-cache.py` opens `O_RDONLY|O_NOFOLLOW|O_NONBLOCK`, requires a regular file, and reads at most cap+1 bytes. Missing / symlink / FIFO / oversize exit 1 (QML re-probes). Valid regular file emits raw bytes and exits 0.

## 0.5.19

- Bound probe/cache I/O (marketplace #2220): clamp probe fields, cap JSON at 32KiB, bounded probe stdout with producer termination, replace unbounded FileView cache with `head -c` read and argv writer.

## 0.5.18

- Marketplace preview.png is the live Omarchy smoke screenshot.

## 0.5.17

- Header: FA lock glyph (`\uf023`) left of COMPLIANTISH; Checks + Refresh on a right-aligned toolbar row so title + subheader are full-width.

## 0.5.15

- Checklist rows: replace colored `●` with tintable per-check FA/Nerd glyphs (HD ``, SL ``, AV ``, PW ``, AU ``; fallback ``), status color tint unchanged (pass=accent / fail=urgent / unknown=amber). Body-sized icons. PASS/FAIL badges, Copy fix, and bar chip unchanged.

## 0.5.14

- Bar chip: replace color emoji 🔒 with tintable Font Awesome lock `\uf023` (same family as omarchy.system-update’s `\uf021`) so WidgetButton `active` → `bar.urgent` is visible. Caption fontSize. Unknown still not urgent. Opt-in `notifyOnFail` (notify-send) remains separate and off by default.

## 0.5.13

- Bar chip: fixed 🔒 glyph (no lock/unlock swap); WidgetButton `active` when any enabled check fails → Omarchy `bar.urgent` / Color.urgent tint. Unknown stays normal (Unknown ≠ fail).

## 0.5.12

- Wrap Panel UI in KeyboardPanel + PanelKeyCatcher (rocketlauncher oracle shell) so the popout opens.
- Inline CheckRow as `component CheckRowDelegate` inside Panel.qml (no qmldir sibling type under Loader).
- BarWidget: loud console.warn on toggle when panelLoader.item is null.

## 0.5.11

- F1: replace Style.font.title/subtitle with Style.font.body (oracle rocketlauncher tokens only) so panels load on VPS/smoke Omarchy.

## 0.5.5

- Renamed plugin id `harris.compliantish` → `kenhara.compliantish`.

## 0.5.4
- Discoverability: expanded `keywords` + `barWidget.aliases` (compliance / Drata / Vanta / encryption / AV / password manager search terms); README Discoverability note. Category remains **System**.

## 0.5.2
- Quattro pre-ship checklist: named `Style.font.*` tokens; `Quickshell.clipboardText` + `bash -c` clipboard; FileView cache (no mkdir race); drop dead `dataChanged`; Flickable scroll; README hero + L/M/R controls; honest Opened toast; PRE-SHIP.md. ST keeps (crypt≠LVM, lock-listener, AU timers, unknown≠fail, enable persist) unchanged.

## 0.5.1
- Audit hardening (false-PASS fixes): HD encryption requires real dm-crypt (`TYPE=crypt` / crypttab / parent chain) — plain LVM `/dev/mapper/…` names no longer pass.
- Screen lock: parse hypridle per `listener` block; use timeout of lock-bearing `on-timeout` only (dim listeners ignored).
- Auto-updates: pass only when a timer is genuinely scheduled (`is-active` or `enabled`/`enabled-runtime`; `list-timers` without `--all`).
- swayidle config parse; drop chkrootkit/rkhunter from AV pass list.
- Honest copy/open toasts; Checks toggles persist in cache; cache mkdir race fixed.
- UI hover fills; docs/version scrub; see `AUDIT-NOTES.md`.

## 0.5.0
- Public MVP — GitHub + Checks menu + five probes + recurring refresh.

## 0.4.2
- Renamed product to **Compliantish** (`kenhara.compliantish`); cache → `~/.cache/compliantish`.

## 0.4.1
- Default `screenLockMaxSec` **900** (15 minutes) to match Drata Test 61; Vanta allows ≤60m via the same knob.

## 0.4.0
- **Checks** menu in the panel header — On/Off for each of the five checks
  (primary UI; widget settings remain secondary).
- All five enables default **on** (turn AV / automatic updates off in Checks if
  Omarchy has no AV or uses manual updates).
- Recurring local probe remains on a Timer (`refreshIntervalSec`, default
  **900 = 15m**); panel shows `auto every 15m`. Drata’s official agent syncs
  ~daily — this interval only re-probes locally.
- DESIGN.md documents accurate Vanta (4) vs Drata (5) with help-center sources.

## 0.3.0
- Per-check enable toggles in widget settings; AV/AU defaulted off.
- Clean UI: colored `●` status dots + full names only. Bar shows `● N/M`.

## 0.2.1 / 0.2.0
- Glyph cleanup and pass-count / surface-card polish.

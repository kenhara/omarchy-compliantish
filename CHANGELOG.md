# Changelog

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
- Renamed product to **Security Theater** (`harris.security-theater`); cache → `~/.cache/security-theater`.

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

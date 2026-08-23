# Security Theater 0.5.1 — audit fix map

False-PASS hardening and polish from the Security Theater audit. Product
principles unchanged: read-only / no-sudo / remediation = copy/open only;
**Unknown ≠ fail**; unofficial Drata/Vanta disclaimer; theme tokens; pointer +
hover on actionable controls.

| ID | Severity | Fix |
|----|----------|-----|
| **ST-01** | HIGH | HD: removed `/dev/mapper`/`crypt` **name** match as encryption proof. Pass only via `lsblk TYPE=crypt`, non-comment `/etc/crypttab`, or walking parent chain of `/` / `/home` for `TYPE=crypt`. Plain LVM (`/dev/mapper/vg0-root`) no longer passes. |
| **ST-02** | HIGH | SL/hypridle: `parse_hypridle_lock_timeout_sec` parses each `listener {…}` block; uses timeout only when `on-timeout` invokes a lock (`loginctl lock-session`, `hyprlock`, `swaylock`, `gtklock`, `lock_cmd`). No lock-bearing timeout → `unknown`, never pass on a dim listener. |
| **ST-03** | HIGH | AU: pass when timer is `is-active`/`activating`, or `is-enabled` ∈ `{enabled, enabled-runtime}` (not `static`/`indirect`/`generated`). Broad scan uses `list-timers` **without** `--all`. Else honest `unknown`. |
| **ST-04** | MED | Implemented swayidle parse (`timeout <sec> <cmd>`) over `SWAYIDLE_CANDIDATES` when hypridle config is absent. |
| **ST-05** | MED | Removed `chkrootkit` / `rkhunter` from `AV_PKGS` (rootkit scanners ≠ AV). |
| **ST-06** | MED | `copyText` / `openConfig`: toast only on real success via Process `onExited`; no `cat >/dev/null` swallow; surfaces “No clipboard tool” / “Copy failed” / “Open failed”. |
| **ST-07** | MED | Persist `enable*` into cache (`buildCacheObject`); rehydrate in `loadDiskText` / bootstrap so Checks menu survives reload when host settings aren’t writable. Still calls `mirrorSettingsEnable`. |
| **ST-08** | MED | Cache write: 0.5.1 chained mkdir+setText; **0.5.2** uses `FileView.setText` only (mkpath, no mkdir race). |
| **ST-09** | LOW | Bumped to **0.5.2**; DESIGN.md + docs/preview banner synced. |
| **ST-10** | LOW | Scrubbed agent workspace paths and public “Quattro” / Space Jockey shipping-name noise from docs; neutralized BarWidget comment. |
| **ST-11** | LOW | LICENSE: unquoted second `Software` (`in the Software without restriction`). |
| **ST-12** | LOW | REPO.md kept as a short pointer. |
| **ST-13** | LOW | Hover fill (`containsMouse` + `hoverEnabled`) on Panel / CheckRow actionable buttons. |
| **ST-14** | LOW | Collapsed dead `worstStatus` branch. |
| **ST-15** | LOW | Changelog moved to `CHANGELOG.md`; README lead stays short. |
| **ST-16** | LOW | Probe EREs use `[[:space:]]` instead of GNU `\s`. |

## Verify
- `bash -n scripts/probe.sh`
- Plain LVM `ROOT_SRC=/dev/mapper/vg0-root` does not yield HD pass from mapper name alone
- hypridle fixture: dim 150 / lock 3600 → SL does not pass on 150
- `bash scripts/probe.sh 900` → valid JSON, exit 0

## shellcheck note (ST-16)
Prefer POSIX character classes (`[[:space:]]`) over GNU `\s` in `grep -E` /
awk patterns so BusyBox/Alpine-style `grep` behaves the same. Optional full
`shellcheck scripts/probe.sh` is recommended on maintainer machines; this tree
does not vendor shellcheck.

## 0.5.2 follow-up
See [PRE-SHIP.md](PRE-SHIP.md) for the Quattro pre-ship checklist applied after this audit map.

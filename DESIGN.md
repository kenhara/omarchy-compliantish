# Security Theater — Omarchy plugin (Vanta ∪ Drata workstation checks)

**Status:** implemented v0.5.2 (community plugin; no Drata/Vanta API)  
**Coverage:** union of **Vanta Device Monitor (4)** + **Drata Agent (5)** = **exactly five** local lights  
**Exemplar lessons:** Omarchy nested `bar-widget` + Panel pattern  

---

## 1. Why this exists

| Reality | Implication |
|---------|-------------|
| Official **Drata Agent** is Electron + OSQuery, toolbar app, **read-only**, syncs ~daily to Drata | We will **not** pretend to be that agent or sync to Drata |
| Drata Linux support is basically **Ubuntu 22/24**; HD encryption often **manual evidence** | Omarchy (Arch) is outside the supported path — gap is real |
| Official agent **does not remediate** — only shows blue “how to fix” links | Our edge: Omarchy-native fix affordances without writing secrets or spoofing Drata |
| Community Omarchy plugin = unsandboxed like any Omarchy plugin | Aim security baseline `passed`; probes read-only; remediation = user-triggered |

**v0.4 success:** Bar shows pass/fail for the **same five workstation controls** (Vanta’s four + Drata’s automatic-updates light); panel **Checks** menu clearly enables/disables each; recurring local probe on a visible interval. No Drata credentials. No auto-sudo.

---

## 2. What the agents actually check (Vanta 4 vs Drata 5)

**Sources (cite these; do not invent extra lights such as firewall):**

- Drata — [How does the Drata agent work?](https://help.drata.com/en/articles/4742932-how-does-the-drata-agent-work)
- Drata — [Install the Drata Agent](https://help.drata.com/en/articles/13612377-install-the-drata-agent)
- Drata — [Computer Configuration via Ubuntu Linux](https://help.drata.com/en/articles/5014509-computer-configuration-via-ubuntu-linux)
- Drata — [Computer Configuration via Windows OS](https://help.drata.com/en/articles/5002070-computer-configuration-via-windows-os)
- Drata — [Configuring Automatic Updates](https://help.drata.com/en/articles/4675832-configuring-automatic-updates-on-your-computer)
- Vanta — [Supported Operating Systems for the Vanta Device Monitor](https://help.vanta.com/en/articles/11345400-supported-operating-systems-for-the-vanta-device-monitor)
- Vanta — [Troubleshooting the Vanta Device Monitor on Linux](https://help.vanta.com/en/articles/11346064-troubleshooting-the-vanta-device-monitor-on-linux-machines)
- Vanta — [Encrypting Your Computer Hard Drives](https://help.vanta.com/en/articles/11345839-encrypting-your-computer-hard-drives)

### Drata Agent (Mac / Windows / Ubuntu toolbar app)

| # | Control | How Drata frames it | Notes |
|---|---------|---------------------|--------|
| 1 | **Hard drive encryption** | FileVault / BitLocker / LUKS | On Ubuntu, often **manual screenshot upload** into myDrata |
| 2 | **Screen lock / screensaver** | Idle lock within org policy | Agent detects config; does not enforce |
| 3 | **Antivirus / antimalware** | Supported AV/EDR installed (or macOS XProtect+Gatekeeper path) | Detects via **installed apps** (+ browser extensions on some OS) |
| 4 | **Password manager** | Supported PWM installed | Same inventory approach (apps + Chrome/Firefox/IE extensions) |
| 5 | **Automatic updates** | OS auto-update enabled | **Extra vs Vanta Device Monitor** — first-class Drata agent light |
| — | Meta | OS identity, serial, app/extension inventory | Asset attribution; not “pass/fail” lights |

**Behavior:** Read-only OSQuery; runs ~daily; **does not modify files**; Sync now in tray.

**What it does *not* do:** MDM, EDR, keylogging, browsing capture, auto-remediation, Arch/Omarchy support. **Firewall is not a Drata agent workstation light.**

### Vanta Device Monitor (for contrast)

| Vanta Computers / agent columns | Drata overlap |
|---------------------------------|---------------|
| Hard drive encryption (HD) | Same |
| Antivirus (AV) | Same |
| Screen lock (SL) | Same |
| Password manager (PW) | Same |
| — | **Missing automatic updates** as a first-class agent column |

**Linux caveats (Vanta):** Official VDM docs state Linux support is limited (Debian/Ubuntu family; **not Arch**). On many Linux builds, **HD encryption is the only reliably supported agent check**; screen lock / AV / password manager often need MDM or manual evidence. Do not treat firewall as a Vanta agent column either.

**Decision:** Security Theater covers the **union: five checks**. Labels match common agent wording. Schema + panel **Checks** menu toggle each independently (all **on** by default in v0.4.0).

---

## 3. Product shape (Omarchy bar-widget lessons)

| Lesson | Apply here |
|--------|------------|
| `bar-widget` + nested `Panel.qml` only | Same — no separate `panel` kind |
| Theme tokens (`Color` / `Style` / `bar.foreground`) | System category chrome; no “compliance SaaS” skin |
| Schema knobs early | `refreshIntervalSec` (900), `screenLockMaxSec` (900 = Drata ≤15m), `notifyOnFail`, five `enable*` flags |
| Primary toggle UI in panel | **Checks** menu in header (schema remains secondary) |
| Pointer + hover only if actionable | Fix buttons / copy / open-config / Checks toggles |
| Honest empty/error states | Unknown ≠ fail; hide broken icons |
| MIT @ repo root, manifest at root | Marketplace-friendly layout |
| Unofficial disclaimer | Not affiliated with Drata, Inc. or Vanta; mirrors common checks only |
| README Controls + IPC | `toggle` / `summon` / Refresh |
| Dead-simple v1 | Five rows + Checks + Refresh + Copy summary — no MDM fantasy |

**ID:** `harris.security-theater`  
**Name:** Security Theater  
**Category:** System  
**Bar:** `● pass/total` (e.g. `2/5`) — pass count from **enabled** statuses; dot color by worst status  
**Pitch:** “Vanta ∪ Drata workstation checks for Omarchy — local, read-only, Checks menu.”

```
BarWidget ──Loader──► Panel (Checks menu + checklist + fix actions)
                 │
                 └── ComplianceStore ← scripts/probe.sh (JSON)
                      └── Timer refreshIntervalSec (default 900s)
```

### Recurring check (v0.4)

- `ComplianceStore.refreshTimer`: `running: true`, `repeat: true`
- Interval synced from schema via `applySettings` → `refreshTimer.interval`
- Panel subtitle shows `auto every 15m` (from `refreshIntervalLabel`)
- Refresh also on panel open (already)
- **Note:** Drata’s official agent syncs ~daily; our interval is a **local re-probe only** (default 15 minutes is fine)

---

## 4. Omarchy probe matrix

| Code | Label | Omarchy probe | Pass (draft) |
|------|-------|---------------|--------------|
| **HD** | Hard drive encryption | `lsblk TYPE=crypt` / crypttab / parent-chain walk | Root (or `/home`) backed by dm-crypt — not plain LVM mapper names |
| **SL** | Screen lock | `hypridle` / `swayidle` + `hyprlock` (or lock cmd) | Idle → lock path exists **and** timeout ≤ `screenLockMaxSec` (default 900 = 15m, Drata Test 61; Vanta allows ≤60m) |
| **AV** | Antivirus | Packages/services: clamav, crowdstrike, sentinelone, mde, sophos, … | ≥1 known agent |
| **PW** | Password manager | `1password`, `bitwarden`, `keepassxc`, `proton-pass`, flatpaks; optional browser extension dirs | ≥1 known PWM |
| **AU** | Automatic updates | Arch/Omarchy: `systemd` timers for update helpers | Timer genuinely scheduled (`is-active` or `enabled`/`enabled-runtime`) **or** clear Unknown |

**Meta (show, don’t gate bar color):** OS pretty name, kernel, hostname, `/etc/machine-id`, last probe time.

**Not a required light:** firewall (`nft`/`iptables`/`ufw`) — **not** in official Drata agent five / Vanta four.

Unknown when probe can’t run (missing tool, permission) — amber, never silent fail.

---

## 5. Remediation triggers

Official Drata: blue help links only. We can do better **locally** without becoming an MDM.

### Tier A — ship (safe, explicit)

| Trigger | When | Behavior |
|---------|------|----------|
| **Copy fix command** | Fail/Unknown with a known shell one-liner | Clipboard via Qt; toast “Copied” |
| **Open config** | SL fail | `xdg-open` on `hypridle.conf` (or detected path) |
| **Refresh** | Always | Re-run `probe.sh` |
| **Copy evidence summary** | Always | Markdown of **enabled** statuses + timestamp |
| **Checks menu** | Always | On/Off per check via `setCheckEnabled` |
| **Notify on fail** (schema off by default) | Transition to fail | `notify-send` once per check/day |

**Principle:** Remediation is **suggest + copy + open file**, never silent mutation of system state.

---

## 6. UX sketch (v0.4)

```
SECURITY THEATER              [Checks ▾] [Refresh]
                             refreshed 2m ago

┌ Checks menu ─────────────────────────────────┐
│ Hard drive encryption              [ On ]    │
│ Screen lock                        [ On ]    │
│ Antivirus                          [ On ]    │
│ Password manager                   [ On ]    │
│ Automatic updates                  [ On ]    │
└──────────────────────────────────────────────┘

● 2 of 5 pass
  auto every 15m · fail Screen lock, Antivirus

 ● Hard drive encryption     PASS    LUKS root
 ● Screen lock               FAIL    no hypridle timeout
   [Copy fix]  [Open config]
 ● Antivirus                 FAIL    none detected
   [Copy fix]
 ● Password manager          PASS    1Password
 ● Automatic updates         UNKNOWN no update timer

 [Copy summary]

Unofficial · not affiliated with Drata or Vanta
```

Bar: worst of **enabled** → red if any fail, amber if any unknown and no fails, else green. Fraction is `passCount/enabledTotal`.

---

## 7. Version notes

### 0.5.2
- Audit false-PASS hardening (HD / SL / AU); swayidle parse; AV list cleanup; cache/toast/hover polish — see `AUDIT-NOTES.md` / `CHANGELOG.md`

### 0.5.0
- Public MVP on GitHub

### 0.4.x
- Panel **Checks** menu; all five `enable*` default on; recurring local probe; rename to Security Theater

### Earlier
- Pass-count fix, surface cards, ● status dots, probe JSON

---

## 8. Out of scope

Drata/Vanta sync, OSQuery dependency, firewall as required light, auto-install packages, silent `pkexec` / sudo remediation.

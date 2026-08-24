#!/usr/bin/env bash
# Compliantish — read-only workstation probes (no network, no sudo).
# Usage: probe.sh [screenLockMaxSec]
# Emits one JSON object on stdout.
# Always emits all five agent checks (HD, SL, AV, PW, AU) — enable flags live in the QML store / Checks menu.
set -euo pipefail

SCREEN_LOCK_MAX_SEC="${1:-${SCREEN_LOCK_MAX_SEC:-900}}"
case "$SCREEN_LOCK_MAX_SEC" in
  ''|*[!0-9]*) SCREEN_LOCK_MAX_SEC=900 ;;
esac
if [ "$SCREEN_LOCK_MAX_SEC" -lt 60 ]; then SCREEN_LOCK_MAX_SEC=60; fi
if [ "$SCREEN_LOCK_MAX_SEC" -gt 86400 ]; then SCREEN_LOCK_MAX_SEC=86400; fi

json_escape() {
  # Escape a string for JSON (no surrounding quotes).
  local s=${1-}
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

package_present() {
  local name="$1"
  if have_cmd pacman; then
    pacman -Q "$name" >/dev/null 2>&1 && return 0
  fi
  if have_cmd rpm; then
    rpm -q "$name" >/dev/null 2>&1 && return 0
  fi
  if have_cmd dpkg-query; then
    dpkg-query -W -f='${Status}' "$name" 2>/dev/null | grep -q "install ok installed" && return 0
  fi
  return 1
}

flatpak_present() {
  local app="$1"
  have_cmd flatpak || return 1
  flatpak list --app 2>/dev/null | grep -qiE "$app" && return 0
  return 1
}

bin_present() {
  local b
  for b in "$@"; do
    have_cmd "$b" && return 0
  done
  return 1
}

# --- meta -------------------------------------------------------------------
HOSTNAME="$(hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)"
KERNEL="$(uname -r 2>/dev/null || echo unknown)"
OS_PRETTY=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_PRETTY="${PRETTY_NAME:-${NAME:-Linux}}"
else
  OS_PRETTY="$(uname -s 2>/dev/null || echo Linux)"
fi
MACHINE_ID=""
if [ -r /etc/machine-id ]; then
  MACHINE_ID="$(tr -d '[:space:]' </etc/machine-id)"
fi
PROBED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"

# --- HD: disk encryption (LUKS / dm-crypt only — not plain LVM mapper names) -
HD_STATUS="unknown"
HD_DETAIL="could not inspect block devices"
HD_FIX="See ArchWiki: dm-crypt/Encrypting an entire system (read-only probe — no auto encrypt)."
HD_CONFIG=""

# True when SOURCE (or a parent in the lsblk tree) has TYPE=crypt.
# Plain LVM names like /dev/mapper/vg0-root must NOT pass on name alone.
mount_src_on_crypt() {
  local src="$1"
  [ -n "$src" ] || return 1
  have_cmd lsblk || return 1
  local chain
  # -s: dependency tree toward parents (PV → crypt → disk)
  chain="$(lsblk -n -r -o NAME,TYPE -s "$src" 2>/dev/null || true)"
  if [ -z "$chain" ]; then
    chain="$(lsblk -n -r -o NAME,TYPE "$src" 2>/dev/null || true)"
  fi
  [ -n "$chain" ] || return 1
  echo "$chain" | grep -qiE '(^|[[:space:]])crypt([[:space:]]|$)' && return 0
  return 1
}

if have_cmd lsblk; then
  LSBLK_OUT="$(lsblk -o NAME,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null || true)"
  ROOT_SRC="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  HOME_SRC="$(findmnt -n -o SOURCE /home 2>/dev/null || true)"
  HAS_CRYPT_TYPE=0
  HAS_CRYPTTAB=0
  echo "$LSBLK_OUT" | grep -qiE '[[:space:]]crypt[[:space:]]' && HAS_CRYPT_TYPE=1 || true
  if [ -r /etc/crypttab ] && grep -qvE '^[[:space:]]*(#|$)' /etc/crypttab 2>/dev/null; then
    HAS_CRYPTTAB=1
  fi

  if mount_src_on_crypt "$ROOT_SRC"; then
    HD_STATUS="pass"
    HD_DETAIL="LUKS/dm-crypt backs / (${ROOT_SRC})"
  elif mount_src_on_crypt "$HOME_SRC"; then
    HD_STATUS="pass"
    HD_DETAIL="LUKS/dm-crypt backs /home (${HOME_SRC})"
  elif [ "$HAS_CRYPT_TYPE" = 1 ]; then
    HD_STATUS="pass"
    HD_DETAIL="crypt mapper present (lsblk TYPE=crypt)"
  elif [ "$HAS_CRYPTTAB" = 1 ]; then
    HD_STATUS="pass"
    HD_DETAIL="entries in /etc/crypttab"
    HD_CONFIG="/etc/crypttab"
  else
    HD_STATUS="fail"
    HD_DETAIL="no LUKS/dm-crypt (TYPE=crypt) or crypttab entries detected"
  fi
elif [ -r /etc/crypttab ] && grep -qvE '^[[:space:]]*(#|$)' /etc/crypttab 2>/dev/null; then
  HD_STATUS="pass"
  HD_DETAIL="entries in /etc/crypttab (lsblk missing)"
  HD_CONFIG="/etc/crypttab"
else
  HD_STATUS="unknown"
  HD_DETAIL="lsblk not available"
fi

# --- SL: screen lock (hypridle + hyprlock / swayidle) -----------------------
SL_STATUS="unknown"
SL_DETAIL="no idle lock config found"
SL_FIX='mkdir -p ~/.config/hypr && cat >> ~/.config/hypr/hypridle.conf <<'\''HYPR'\''
general {
  lock_cmd = pidof hyprlock || hyprlock
}
listener {
  timeout = 300
  on-timeout = loginctl lock-session
}
HYPR'
SL_CONFIG=""

HYPRIDLE_CANDIDATES=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
  "$HOME/.config/hypr/hypridle.conf"
)
SWAYIDLE_CANDIDATES=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/swayidle/config"
  "$HOME/.config/sway/config"
  "$HOME/.config/swayidle/config"
)

LOCK_BIN=""
if bin_present hyprlock; then LOCK_BIN="hyprlock"
elif bin_present swaylock; then LOCK_BIN="swaylock"
elif bin_present gtklock; then LOCK_BIN="gtklock"
fi

FOUND_IDLE_CONF=""
IDLE_KIND=""
for f in "${HYPRIDLE_CANDIDATES[@]}"; do
  if [ -r "$f" ]; then FOUND_IDLE_CONF="$f"; IDLE_KIND="hypridle"; break; fi
done

# Timeout of the listener block whose on-timeout invokes a lock.
# Do NOT take the first timeout= in the file (dim listeners often come first).
parse_hypridle_lock_timeout_sec() {
  local conf="$1"
  awk '
    BEGIN { in_l=0; t=""; lock=0 }
    /listener[[:space:]]*\{/ { in_l=1; t=""; lock=0; next }
    in_l && /^[[:space:]]*\}/ {
      if (lock && t != "") { print t; exit 0 }
      in_l=0; t=""; lock=0; next
    }
    in_l {
      if ($0 ~ /^[[:space:]]*timeout[[:space:]]*=/) {
        line=$0
        sub(/^[^=]*=[[:space:]]*/, "", line)
        sub(/[^0-9].*/, "", line)
        if (line ~ /^[0-9]+$/) t=line
      }
      if ($0 ~ /on-timeout/ && $0 ~ /(loginctl[[:space:]]+lock-session|hyprlock|swaylock|gtklock|lock_cmd)/) {
        lock=1
      }
    }
  ' "$conf" 2>/dev/null || true
}

# swayidle: timeout <sec> <cmd> … — use first timeout whose command locks.
parse_swayidle_lock_timeout_sec() {
  local conf="$1"
  local line sec rest
  while IFS= read -r line || [ -n "$line" ]; do
    # strip comments
    line="${line%%#*}"
    # trim leading whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      timeout[[:space:]]*)
        ;;
      *)
        continue
        ;;
    esac
    # shellcheck disable=SC2086
    set -- $line
    # $1=timeout $2=sec $3…=cmd
    [ "${1-}" = "timeout" ] || continue
    sec="${2-}"
    case "$sec" in
      ''|*[!0-9]*) continue ;;
    esac
    shift 2 || continue
    rest="$*"
    if echo "$rest" | grep -qiE 'hyprlock|swaylock|gtklock|loginctl[[:space:]]+lock|lock-session|lock_cmd'; then
      echo "$sec"
      return 0
    fi
  done < "$conf"
  echo ""
}

has_lock_path() {
  local conf="$1"
  grep -qiE 'hyprlock|swaylock|gtklock|loginctl[[:space:]]+lock|lock_cmd|lock-session' "$conf" 2>/dev/null
}

apply_sl_timeout() {
  local kind="$1" conf="$2" to="$3"
  SL_CONFIG="$conf"
  if [ -n "$to" ]; then
    if [ "$to" -le "$SCREEN_LOCK_MAX_SEC" ]; then
      SL_STATUS="pass"
      SL_DETAIL="${kind} lock timeout ${to}s ≤ ${SCREEN_LOCK_MAX_SEC}s (${conf})"
    else
      SL_STATUS="fail"
      SL_DETAIL="${kind} lock timeout ${to}s > ${SCREEN_LOCK_MAX_SEC}s"
      SL_FIX="Edit ${conf}: set lock listener timeout ≤ ${SCREEN_LOCK_MAX_SEC}"
    fi
  else
    SL_STATUS="unknown"
    SL_DETAIL="${kind} present but no lock-bearing timeout parsed (${conf})"
  fi
}

if [ -n "$FOUND_IDLE_CONF" ]; then
  TO="$(parse_hypridle_lock_timeout_sec "$FOUND_IDLE_CONF")"
  if has_lock_path "$FOUND_IDLE_CONF"; then
    apply_sl_timeout "hypridle" "$FOUND_IDLE_CONF" "$TO"
  else
    SL_STATUS="fail"
    SL_DETAIL="idle config found but no lock command path"
    SL_CONFIG="$FOUND_IDLE_CONF"
  fi
else
  # ST-04: parse swayidle configs when hypridle is absent
  FOUND_SWAY=""
  for f in "${SWAYIDLE_CANDIDATES[@]}"; do
    if [ -r "$f" ]; then FOUND_SWAY="$f"; break; fi
  done
  if [ -n "$FOUND_SWAY" ]; then
    TO="$(parse_swayidle_lock_timeout_sec "$FOUND_SWAY")"
    if has_lock_path "$FOUND_SWAY"; then
      apply_sl_timeout "swayidle" "$FOUND_SWAY" "$TO"
    else
      # sway/config may exist without swayidle lock lines
      SL_STATUS="unknown"
      SL_DETAIL="swayidle candidate found but no lock timeout parsed (${FOUND_SWAY})"
      SL_CONFIG="$FOUND_SWAY"
    fi
  elif pgrep -x hypridle >/dev/null 2>&1 || pgrep -x swayidle >/dev/null 2>&1; then
    SL_STATUS="unknown"
    SL_DETAIL="idle daemon running but config file not found"
  elif [ -n "$LOCK_BIN" ]; then
    SL_STATUS="fail"
    SL_DETAIL="${LOCK_BIN} installed but no hypridle/swayidle config detected"
    SL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
  else
    SL_STATUS="fail"
    SL_DETAIL="no hypridle/swayidle config or lock binary detected"
    SL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
  fi
fi

# --- AV: antivirus package present ------------------------------------------
AV_STATUS="fail"
AV_DETAIL="none detected"
AV_FIX="sudo pacman -S clamav   # or install your org EDR (CrowdStrike / SentinelOne / MDE / Sophos)"
AV_CONFIG=""

# chkrootkit / rkhunter are rootkit scanners, not AV — do not let them alone satisfy pass.
AV_PKGS=(
  clamav clamav-daemon clamd
  crowdstrike falcon-sensor
  sentinelagent sentinelone
  mdatp microsoft-defender
  sophos sophos-av
  bitdefender
  eset
  avg
  avast
  kaspersky
)
AV_BINS=(clamscan clamdscan freshclam falcon-sensor mdatp)
AV_HIT=""

for p in "${AV_PKGS[@]}"; do
  if package_present "$p"; then AV_HIT="$p"; break; fi
done
if [ -z "$AV_HIT" ]; then
  for b in "${AV_BINS[@]}"; do
    if have_cmd "$b"; then AV_HIT="bin:$b"; break; fi
  done
fi
if [ -z "$AV_HIT" ]; then
  # systemd unit hints
  if systemctl list-unit-files 2>/dev/null | grep -qiE 'clamav|falcon|sentinel|mdatp|sophos'; then
    AV_HIT="systemd-unit"
  fi
fi

if [ -n "$AV_HIT" ]; then
  AV_STATUS="pass"
  AV_DETAIL="detected ${AV_HIT}"
  AV_FIX=""
fi

# --- PW: password manager present -------------------------------------------
PW_STATUS="fail"
PW_DETAIL="none detected"
PW_FIX="sudo pacman -S bitwarden keepassxc   # or install 1Password / Proton Pass"
PW_CONFIG=""

PW_HIT=""
PW_PKGS=(1password 1password-cli bitwarden bitwarden-bin bitwarden-cli keepassxc proton-pass protonpass)
PW_BINS=(1password op bitwarden bw keepassxc proton-pass protonpass)
PW_FLATPAKS=(
  '1Password|com.onepassword.OnePassword'
  'Bitwarden|com.bitwarden.desktop'
  'KeePassXC|org.keepassxc.KeePassXC'
  'Proton Pass|me.proton.Pass'
)

for p in "${PW_PKGS[@]}"; do
  if package_present "$p"; then PW_HIT="$p"; break; fi
done
if [ -z "$PW_HIT" ]; then
  for b in "${PW_BINS[@]}"; do
    if have_cmd "$b"; then PW_HIT="bin:$b"; break; fi
  done
fi
if [ -z "$PW_HIT" ]; then
  for entry in "${PW_FLATPAKS[@]}"; do
    name="${entry%%|*}"
    id="${entry##*|}"
    if flatpak_present "$id" || flatpak_present "$name"; then
      PW_HIT="flatpak:$name"
      break
    fi
  done
fi
# Optional browser extension dirs (presence only — not proof of login)
if [ -z "$PW_HIT" ]; then
  EXT_HINTS=(
    "$HOME/.config/google-chrome/Default/Extensions"
    "$HOME/.config/chromium/Default/Extensions"
    "$HOME/.mozilla/firefox"
  )
  for d in "${EXT_HINTS[@]}"; do
    if [ -d "$d" ] && find "$d" -maxdepth 4 \( -iname '*bitwarden*' -o -iname '*1password*' -o -iname '*keepass*' \) 2>/dev/null | grep -q .; then
      PW_HIT="browser-extension hint"
      break
    fi
  done
fi

if [ -n "$PW_HIT" ]; then
  PW_STATUS="pass"
  PW_DETAIL="detected ${PW_HIT}"
  PW_FIX=""
fi

# --- AU: automatic updates --------------------------------------------------
AU_STATUS="unknown"
AU_DETAIL="Omarchy Update menu may count — confirm org policy"
AU_FIX="Enable an update timer (e.g. systemctl --user enable --now omarchy-update.timer) or document weekly Omarchy Update."
AU_CONFIG=""

AU_HIT=""
# Known / likely timer names on Arch / Omarchy / unattended
AU_TIMERS=(
  omarchy-update.timer
  omarchy-updates.timer
  pacman-update.timer
  pacman-autoupdate.timer
  arch-update.timer
  yay-update.timer
  paru-update.timer
  flatpak-update.timer
  apt-daily.timer
  apt-daily-upgrade.timer
  dnf-automatic.timer
  packagekit.timer
)

# Pass only when genuinely scheduled: is-active, or is-enabled in {enabled,enabled-runtime}.
# static / indirect / generated alone are NOT pass.
timer_genuinely_scheduled() {
  local scope="$1"   # "" or "--user"
  local unit="$2"
  local st en
  if [ -n "$scope" ]; then
    st="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
    en="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
  else
    st="$(systemctl is-active "$unit" 2>/dev/null || true)"
    en="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  fi
  case "$st" in
    active|activating) return 0 ;;
  esac
  case "$en" in
    enabled|enabled-runtime) return 0 ;;
  esac
  return 1
}

for t in "${AU_TIMERS[@]}"; do
  if timer_genuinely_scheduled "" "$t"; then
    AU_HIT="$t"
    break
  fi
  if timer_genuinely_scheduled "--user" "$t"; then
    AU_HIT="user:$t"
    break
  fi
done

if [ -z "$AU_HIT" ] && have_cmd systemctl; then
  # Broader scan: list-timers WITHOUT --all so only timers with a real NEXT fire.
  CAND="$(systemctl list-timers --no-pager 2>/dev/null | grep -iE 'update|upgrade|pacman|omarchy' | head -1 || true)"
  if [ -z "$CAND" ]; then
    CAND="$(systemctl --user list-timers --no-pager 2>/dev/null | grep -iE 'update|upgrade|pacman|omarchy' | head -1 || true)"
  fi
  if [ -n "$CAND" ]; then
    AU_HIT="timer:$(echo "$CAND" | awk '{print $NF}')"
  fi
fi

if [ -n "$AU_HIT" ]; then
  AU_STATUS="pass"
  AU_DETAIL="scheduled ${AU_HIT}"
  AU_FIX=""
else
  # Honest Unknown — Omarchy often relies on manual Update menu, not a timer
  AU_STATUS="unknown"
  AU_DETAIL="no update timer/service detected; Omarchy Update menu may still satisfy policy"
fi

# --- emit JSON --------------------------------------------------------------
emit_check() {
  local code="$1" label="$2" status="$3" detail="$4" fix="$5" config="$6"
  printf '{'
  printf '"code":"%s",' "$(json_escape "$code")"
  printf '"label":"%s",' "$(json_escape "$label")"
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"detail":"%s",' "$(json_escape "$detail")"
  printf '"fixCommand":"%s",' "$(json_escape "$fix")"
  printf '"configPath":"%s"' "$(json_escape "$config")"
  printf '}'
}

printf '{'
printf '"version":1,'
printf '"probedAt":"%s",' "$(json_escape "$PROBED_AT")"
printf '"screenLockMaxSec":%s,' "$SCREEN_LOCK_MAX_SEC"
printf '"meta":{'
printf '"hostname":"%s",' "$(json_escape "$HOSTNAME")"
printf '"osPretty":"%s",' "$(json_escape "$OS_PRETTY")"
printf '"kernel":"%s",' "$(json_escape "$KERNEL")"
printf '"machineId":"%s"' "$(json_escape "$MACHINE_ID")"
printf '},'
printf '"checks":['
emit_check "HD" "Hard drive encryption" "$HD_STATUS" "$HD_DETAIL" "$HD_FIX" "$HD_CONFIG"
printf ','
emit_check "SL" "Screen lock" "$SL_STATUS" "$SL_DETAIL" "$SL_FIX" "$SL_CONFIG"
printf ','
emit_check "AV" "Antivirus" "$AV_STATUS" "$AV_DETAIL" "$AV_FIX" "$AV_CONFIG"
printf ','
emit_check "PW" "Password manager" "$PW_STATUS" "$PW_DETAIL" "$PW_FIX" "$PW_CONFIG"
printf ','
emit_check "AU" "Automatic updates" "$AU_STATUS" "$AU_DETAIL" "$AU_FIX" "$AU_CONFIG"
printf ']'
printf '}\n'

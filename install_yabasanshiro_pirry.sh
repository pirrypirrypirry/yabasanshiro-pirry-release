#!/bin/bash
# Install the yabasanshiro-pirry emulator on dArkOS or ArkOS.
# Put this script and the yabasanshiro-pirry binary next to each other (e.g. in roms/tools/)
# and run it from the Tools menu or a terminal.

# ---------- Root check ----------
if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_BIN="$SCRIPT_DIR/yabasanshiro-pirry"
DEST_DIR="/opt/yabasanshiro"
DEST_BIN="$DEST_DIR/yabasanshiro-pirry"
SATURN_SH="/usr/local/bin/saturn.sh"
ES_CFG="/etc/emulationstation/es_systems.cfg"

# Started from the Tools menu: show the output on the screen. Always keep a log next to the script.
LOG="$SCRIPT_DIR/install_yabasanshiro_pirry.log"
if [ ! -t 1 ] && [ -w /dev/tty1 ]; then
  printf "\033c" > /dev/tty1
  exec > >(tee "$LOG" > /dev/tty1) 2>&1
else
  exec > >(tee "$LOG") 2>&1
fi

step() { echo; echo "=== $1 ==="; sleep 1; }
ok()   { echo "[ OK ] $1"; sleep 1; }
fail() { echo "[FAIL] $1"; sleep 5; exit 1; }

# ---------- Step 1: copy the emulator ----------
step "Step 1/5: Copying the emulator"
[ -f "$SRC_BIN" ] || fail "yabasanshiro-pirry not found next to this script ($SCRIPT_DIR)"
mkdir -p "$DEST_DIR"
cp "$SRC_BIN" "$DEST_BIN" || fail "Could not copy the emulator"
chmod +x "$DEST_BIN"
ok "Emulator installed in $DEST_BIN"
MISSING="$(ldd "$DEST_BIN" 2>&1 | grep 'not found')"
[ -z "$MISSING" ] || echo "[WARN] missing libraries: $MISSING"

# ---------- Step 2: backups ----------
step "Step 2/5: Backing up configuration files"
if [ -f "$SATURN_SH.backup" ]; then
  step "Restoring clean saturn.sh from backup"
  cp -p "$SATURN_SH.backup" "$SATURN_SH" || fail "Could not restore saturn.sh"
  ok "Original saturn.sh restored"
fi
[ -f "$SATURN_SH" ] || fail "$SATURN_SH not found"
[ -f "$ES_CFG" ]    || fail "$ES_CFG not found"
[ -f "$SATURN_SH.backup" ] || cp -p "$SATURN_SH" "$SATURN_SH.backup"
for C in "$ES_CFG" "$ES_CFG.dual"; do
  [ -f "$C" ] && { [ -f "$C.backup" ] || cp -p "$C" "$C.backup"; }
done
ok "Backups ready (*.backup)"

# ---------- Step 3: patch saturn.sh ----------
# awk patterns stay plain (no [[:space:]]): ArkOS ships mawk 1.3.3, which does not know character classes.
step "Step 3/5: Patching $SATURN_SH"
if grep -q '"pirry"' "$SATURN_SH"; then
  echo "saturn.sh already has a pirry entry, skipping."
  sleep 1
elif grep -q 'YABA_BIN="./yabasanshiro"' "$SATURN_SH"; then
  # ArkOS: saturn.sh already chooses YABA_BIN (pi4, 2412, ...) -- add a pirry branch before the default one
  awk '
    /^[ \t]*else[ \t]*$/ && !done { held=$0; next }
    held != "" {
      if ($0 ~ /YABA_BIN="\.\/yabasanshiro"/) {
        print "  elif [[ $1 == *\"pirry\"* ]]; then"
        print "    YABA_BIN=\"/opt/yabasanshiro/yabasanshiro-pirry\""
        print "    [[ ! -d \"/$directory/saturn/yabasanshiro-pirry\" ]] && mkdir /$directory/saturn/yabasanshiro-pirry"
        done=1
      }
      print held; held=""
    }
    { print }
    END { if (!done) exit 3 }
  ' "$SATURN_SH.backup" > "$SATURN_SH.new" \
    || { rm -f "$SATURN_SH.new"; fail "Could not patch saturn.sh"; }
  mv "$SATURN_SH.new" "$SATURN_SH"
  chmod +x "$SATURN_SH"
  ok "Patched $SATURN_SH (ArkOS: pirry branch added)"
else
  # dArkOS: saturn.sh starts ./yabasanshiro directly -- choose the binary with YABA_BIN
  awk '
    /if \[\[ ! -d "\/\$directory\/saturn\/yabasanshiro" \]\]/ && !done {
      print "if [[ $1 == *\"pirry\"* ]]; then"
      print "    YABA_BIN=\"/opt/yabasanshiro/yabasanshiro-pirry\""
      print "    [[ ! -d \"/$directory/saturn/yabasanshiro-pirry\" ]] && mkdir /$directory/saturn/yabasanshiro-pirry"
      print "else"
      print "    YABA_BIN=\"./yabasanshiro\""
      print "    [[ ! -d \"/$directory/saturn/yabasanshiro\" ]] && mkdir /$directory/saturn/yabasanshiro"
      print "fi"
      skip=2; done=1
      next
    }
    skip > 0 { skip--; next }
    {
      gsub(/\.\/yabasanshiro/, "\"$YABA_BIN\"")
      # standalone-pirry-bios must take the BIOS branch as well
      gsub(/\$1 == "standalone-bios"/, "$1 == *\"-bios\"*")
      print
    }
    END { if (!done) exit 3 }
  ' "$SATURN_SH.backup" > "$SATURN_SH.new" \
    || { rm -f "$SATURN_SH.new"; fail "Could not patch saturn.sh"; }
  mv "$SATURN_SH.new" "$SATURN_SH"
  chmod +x "$SATURN_SH"
  ok "Patched $SATURN_SH with YABA_BIN configuration"
fi
# pirry finds the BIOS file itself: skip the BIOS warning for this build
grep -q '!= \*"pirry"\*' "$SATURN_SH" \
  || sed -i 's|if \[\[ ! -f "/$directory/bios/saturn_bios.bin" \]\]|& \&\& [[ $1 != *"pirry"* ]]|' "$SATURN_SH"

echo "Checking syntax..."
sleep 1
if bash -n "$SATURN_SH" && grep -q 'yabasanshiro-pirry' "$SATURN_SH"; then
  ok "Syntax OK"
else
  cp -p "$SATURN_SH.backup" "$SATURN_SH"
  fail "Syntax error, original saturn.sh restored"
fi

# ---------- Step 4: patch es_systems.cfg ----------
step "Step 4/5: Patching $ES_CFG"
for C in "$ES_CFG" "$ES_CFG.dual"; do
  [ -f "$C" ] || continue
  if grep -q 'standalone-pirry' "$C"; then
    echo "$(basename "$C") already patched, skipping."
    sleep 1
  else
    awk '
      /<name>saturn<\/name>/ { insat=1 }
      { print }
      insat && /<emulators>/ {
        print "\t\t\t<emulator name=\"standalone-pirry-nobios\">"
        print "\t\t\t</emulator>"
        print "\t\t\t<emulator name=\"standalone-pirry-bios\">"
        print "\t\t\t</emulator>"
        insat=0; done=1
      }
      END { if (!done) exit 3 }
    ' "$C.backup" > "$C.new" \
      || { rm -f "$C.new"; fail "Could not find the Saturn <emulators> section in $(basename "$C")"; }
    mv "$C.new" "$C"
    ok "Emulators added to $(basename "$C")"
  fi
  # es_systems.cfg.dual has one Saturn section per SD card: 2 entries each
  WANT=$(( 2 * $(grep -c '<name>saturn</name>' "$C") ))
  COUNT="$(grep -c 'standalone-pirry' "$C")"
  if [ "$COUNT" -eq "$WANT" ]; then
    ok "Verification passed ($COUNT entries found in $(basename "$C"))"
  else
    cp -p "$C.backup" "$C"
    fail "Expected $WANT entries in $(basename "$C"), found $COUNT. Original restored"
  fi
done

# ---------- Step 5: restart EmulationStation ----------
step "Step 5/5: Restarting EmulationStation"
echo "Done. Choose standalone-pirry-nobios (or standalone-pirry-bios) as the Saturn emulator."
sleep 3
systemctl restart emulationstation

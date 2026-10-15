#!/bin/bash
# Install the yabasanshiro-pirry emulator on dArkOS.

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

step() { echo; echo "=== $1 ==="; sleep 1; }
ok()   { echo "[ OK ] $1"; sleep 1; }
fail() { echo "[FAIL] $1"; exit 1; }

# ---------- Step 1: copy the emulator ----------
step "Step 1/5: Copying the emulator"
[ -f "$SRC_BIN" ] || fail "yabasanshiro-pirry not found next to this script ($SCRIPT_DIR)"
mkdir -p "$DEST_DIR"
cp "$SRC_BIN" "$DEST_BIN" || fail "Could not copy the emulator"
chmod +x "$DEST_BIN"
ok "Emulator installed in $DEST_BIN"

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
[ -f "$ES_CFG.backup" ]    || cp -p "$ES_CFG" "$ES_CFG.backup"
ok "Backups ready (*.backup)"

# ---------- Step 3: patch saturn.sh ----------
step "Step 3/5: Patching $SATURN_SH"
if grep -q 'YABA_BIN' "$SATURN_SH"; then
  echo "saturn.sh already patched, skipping."
  sleep 1
else
  awk '
    /if \[\[ ! -d "\/\$directory\/saturn\/yabasanshiro" \]\]/ {
      print "if [[ $1 == *\"pirry\"* ]]; then"
      print "    YABA_BIN=\"/opt/yabasanshiro/yabasanshiro-pirry\""
      print "    [[ ! -d \"/\$directory/saturn/yabasanshiro-pirry\" ]] && mkdir /\$directory/saturn/yabasanshiro-pirry"
      print "else"
      print "    YABA_BIN=\"./yabasanshiro\""
      print "    [[ ! -d \"/\$directory/saturn/yabasanshiro\" ]] && mkdir /\$directory/saturn/yabasanshiro"
      print "fi"
      skip=2
      next
    }
    skip > 0 { skip--; next }
    {
      gsub(/\.\/yabasanshiro/, "\"$YABA_BIN\"")
      print
    }
  ' "$SATURN_SH.backup" > "$SATURN_SH.new" \
    || { rm -f "$SATURN_SH.new"; fail "Could not patch saturn.sh"; }

  mv "$SATURN_SH.new" "$SATURN_SH"
  chmod +x "$SATURN_SH"
  ok "Patched $SATURN_SH with YABA_BIN configuration"

  # Skip the BIOS warning for this build
  sed -i 's|if [[ ! -f "/\$directory/bios/saturn_bios.bin" ]]||& \&\& [[ $1 != *"pirry"* ]]|' "$SATURN_SH"
  sleep 1
fi

echo "Checking syntax..."
sleep 1
if bash -n "$SATURN_SH"; then
  ok "Syntax OK"
else
  cp -p "$SATURN_SH.backup" "$SATURN_SH"
  fail "Syntax error, original saturn.sh restored"
fi

# ---------- Step 4: patch es_systems.cfg ----------
step "Step 4/5: Patching $ES_CFG"
if grep -q 'standalone-pirry' "$ES_CFG"; then
  echo "es_systems.cfg already patched, skipping."
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
  ' "$ES_CFG.backup" > "$ES_CFG.new" \
    || { rm -f "$ES_CFG.new"; fail "Could not find the Saturn <emulators> section"; }
  mv "$ES_CFG.new" "$ES_CFG"
  ok "Emulators added"
fi
COUNT="$(grep -c 'standalone-pirry' "$ES_CFG")"
if [ "$COUNT" -eq 2 ]; then
  ok "Verification passed (2 entries found)"
else
  cp -p "$ES_CFG.backup" "$ES_CFG"
  fail "Expected 2 entries, found $COUNT. Original es_systems.cfg restored"
fi

# ---------- Step 5: restart EmulationStation ----------
step "Step 5/5: Restarting EmulationStation"
sleep 2
systemctl restart emulationstation 

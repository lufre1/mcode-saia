#!/usr/bin/env bash
#
# build.sh — pack the live SAIA config into install-mcode-saia.sh
#
# Reads the current src/add-saia-mcode.sh and src/models.txt and
# emits a single self-contained installer that can be copied to other devices.
# Rerun this after ANY change to those files, and commit both.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

OUT="install-mcode-saia.sh"
MANIFEST=(
  src/add-saia-mcode.sh
  src/models.txt
)

# ── Sanity checks ────────────────────────────────────────────────────
for f in "${MANIFEST[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing source file: $f" >&2
    exit 1
  fi
  if grep -qF "__MCS_EOF__" "$f"; then
    echo "ERROR: delimiter '__MCS_EOF__' occurs in $f — pick a different delimiter" >&2
    exit 1
  fi
  if [[ -n "$(tail -c 1 "$f")" ]]; then
    echo "ERROR: $f lacks a trailing newline (heredoc packing would add one)" >&2
    exit 1
  fi
done

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY=""
git diff --quiet HEAD -- "${MANIFEST[@]}" 2>/dev/null || DIRTY="-dirty"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TMP_OUT="$(mktemp "$OUT.XXXXXX")"
trap 'rm -f "$TMP_OUT"' EXIT

# ── Header (interpolates the stamp) ──────────────────────────────────
cat >"$TMP_OUT" <<MCS_GEN_HEADER
#!/usr/bin/env bash
#
# install-mcode-saia.sh — GENERATED FILE, DO NOT EDIT.
# Regenerate with: ./build.sh  (in the mcode-saia repo)
# Source: mcode-saia commit $COMMIT$DIRTY, packed $STAMP
#
# Installs the GWDG SAIA setup for mcode: provider + 16 models.

MCS_GEN_HEADER

# ── Static installer body ────────────────────────────────────────────
cat >>"$TMP_OUT" <<'MCS_GEN_BODY'
set -euo pipefail

CONFIG_DIR="$HOME/.minimax"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
BACKUP_DIR=""

usage() {
  cat <<'USAGE'
Usage: SAIA_API_KEY="your-key" bash install-mcode-saia.sh [OPTIONS]

Installs the GWDG SAIA setup for mcode:
  - Registers custom_provider:gwdg-saia with 16 ready SAIA models
  - Configures provider with base URL and API format

Options:
  -y, --yes        answer yes to prompts (e.g. installing mcode)
  -h, --help       show this help

The API key must be provided via the SAIA_API_KEY environment variable.
Files that would be overwritten are backed up to ~/.minimax.bak-<timestamp>/ first.
USAGE
}

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# ── Read API key from environment ────────────────────────────────────
if [[ -z "$SAIA_API_KEY" ]]; then
  echo "ERROR: SAIA_API_KEY environment variable is not set." >&2
  echo "Set it before running: SAIA_API_KEY=\"your-key\" bash install-mcode-saia.sh" >&2
  exit 1
fi

# ── Check/install mcode ──────────────────────────────────────────────
MCODE_BIN="$HOME/.minimax-code/bin/mcode"
if ! command -v mcode &>/dev/null; then
  # mcode not in PATH - check if installed in default location
  if [[ -x "$MCODE_BIN" ]]; then
    # Found mcode in install location - add to PATH for this session
    export PATH="$HOME/.minimax-code/bin:$PATH"
  elif [[ $ASSUME_YES -eq 1 ]]; then
    echo "mcode not found — installing via official installer..."
  elif [[ -t 0 ]]; then
    read -r -p "mcode not found — install it via the official installer? [y/N] " reply
    if [[ $reply != [yY]* ]]; then
      echo "Aborted." >&2
      exit 1
    fi
  else
    echo "ERROR: mcode not found and not in TTY mode — use --yes to auto-install" >&2
    exit 1
  fi

  # Install mcode via official GitHub installer if still not found
  if ! command -v mcode &>/dev/null; then
    if ! command -v curl &>/dev/null; then
      echo "ERROR: curl is required to install mcode" >&2
      exit 1
    fi

    echo "Downloading and installing mcode..."
    if ! curl -fsSL https://filecdn.minimax.chat/public/install.sh | bash; then
      echo "ERROR: mcode installation failed" >&2
      exit 1
    fi

    # Add mcode to PATH for this session (official installer updates shell rc, not current PATH)
    export PATH="$HOME/.minimax-code/bin:$PATH"

    # Verify installation
    if ! command -v mcode &>/dev/null; then
      echo "ERROR: mcode installation completed but not found in PATH" >&2
      exit 1
    fi

    echo "mcode installed successfully"
  fi
fi

# ── Backup existing config if needed ─────────────────────────────────
if [[ -f "$CONFIG_FILE" ]]; then
  if grep -qF "custom_provider:" "$CONFIG_FILE"; then
    if [[ $ASSUME_YES -eq 1 ]]; then
      BACKUP_DIR=""
    elif [[ -t 0 ]]; then
      read -r -p "Backup existing config and overwrite? [y/N] " reply
      if [[ $reply == [yY]* ]]; then
        BACKUP_DIR="$CONFIG_DIR.bak-$(date +%Y%m%d%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp "$CONFIG_FILE" "$BACKUP_DIR/config.yaml"
        echo "Backed up $CONFIG_FILE to $BACKUP_DIR/"
      else
        echo "Aborted." >&2
        exit 1
      fi
    else
      echo "ERROR: Config exists with custom_provider block and not in TTY mode" >&2
      echo "Set SAIA_API_KEY and use --yes to overwrite" >&2
      exit 1
    fi
  fi
fi

# ── Run the installer script ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/src/add-saia-mcode.sh"

echo ""
echo "✓ GWDG SAIA provider installed successfully!"
echo "  Provider ID: custom_provider:gwdg-saia"
echo "  Models: 16 ready SAIA models"
echo ""
echo "Usage: mcode --model custom_provider:gwdg-saia/<model>"
echo "       mcode --model custom_provider:gwdg-saia/deepseek-v4-flash-0731"
MCS_GEN_BODY

# ── Append the packed source files ───────────────────────────────────
echo "" >>"$TMP_OUT"
echo "# ── Packed source files ────────────────────────────────────────────" >>"$TMP_OUT"

for f in "${MANIFEST[@]}"; do
  echo "echo 'Extracting $f...'" >>"$TMP_OUT"
  echo "cat >\"$f\" <<'__MCS_EOF__'" >>"$TMP_OUT"
  cat "$f" >>"$TMP_OUT"
  echo "__MCS_EOF__" >>"$TMP_OUT"
  echo "" >>"$TMP_OUT"
done

# ── Finalize ─────────────────────────────────────────────────────────
mv "$TMP_OUT" "$OUT"
chmod +x "$OUT"

echo "Generated: $OUT"
echo "Commit: $COMMIT$DIRTY"
echo "Timestamp: $STAMP"
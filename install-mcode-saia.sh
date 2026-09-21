#!/usr/bin/env bash
#
# install-mcode-saia.sh — GENERATED FILE, DO NOT EDIT.
# Regenerate with: ./build.sh  (in the mcode-saia repo)
# Source: mcode-saia commit unknown-dirty, packed 2026-09-21T08:34:19Z
#
# Installs the GWDG SAIA setup for mcode: provider + 16 models.

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

# ── Check mcode is available ─────────────────────────────────────────
if ! command -v mcode &>/dev/null; then
  echo "ERROR: mcode not found in PATH." >&2
  echo "Install mcode first: npm install -g @minimax-ai/code" >&2
  exit 1
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

# ── Packed source files ────────────────────────────────────────────
echo 'Extracting src/add-saia-mcode.sh...'
cat >"src/add-saia-mcode.sh" <<__MCS_FILE_EOF__
#!/usr/bin/env bash
set -euo pipefail

# add-saia-mcode.sh — Add GWDG SAIA provider to mcode (MiniMax Code)
#
# Reads SAIA API key from environment variable SAIA_API_KEY or --key/--key-file.
# Registers all ready SAIA models with mcode provider add.
#
# Usage:
#   SAIA_API_KEY="your-key" ./add-saia-mcode.sh
#   ./add-saia-mcode.sh --key "your-key"
#   ./add-saia-mcode.sh --key-file ~/.local/share/opencode/auth.json
#
# Note: mcode v0.5.0 stores the API key directly in ~/.minimax/config.yaml
# regardless of --api-key-env. The key is written in plaintext with 600 perms.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_FILE="${SCRIPT_DIR}/models.txt"

# ── Parse arguments ──────────────────────────────────────────────────
KEY=""
KEY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)
      KEY="$2"
      shift 2
      ;;
    --key-file)
      KEY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: SAIA_API_KEY=... ./add-saia-mcode.sh [--key <key> | --key-file <path>]"
      echo ""
      echo "Options:"
      echo "  --key <value>       SAIA API key (overrides SAIA_API_KEY env)"
      echo "  --key-file <path>   File containing the SAIA API key"
      echo "  -h, --help          Show this help"
      echo ""
      echo "The API key is taken from:"
      echo "  1. SAIA_API_KEY environment variable (if set)"
      echo "  2. --key <value> argument (if provided)"
      echo "  3. --key-file <path> (reads first line)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ── Obtain API key ───────────────────────────────────────────────────
if [[ -n "$KEY" ]]; then
  SAIA_KEY="$KEY"
elif [[ -n "$SAIA_API_KEY" ]]; then
  SAIA_KEY="$SAIA_API_KEY"
elif [[ -n "$KEY_FILE" ]]; then
  if [[ ! -f "$KEY_FILE" ]]; then
    echo "ERROR: Key file not found: $KEY_FILE" >&2
    exit 1
  fi
  # Try to read as JSON (opencode auth.json format)
  if command -v python3 &>/dev/null; then
    SAIA_KEY=$(python3 -c "import json; d=json.load(open('$KEY_FILE')); print(d.get('saia-gwdg',{}).get('key',''))" 2>/dev/null || echo "")
  fi
  # Fallback: read first line
  if [[ -z "$SAIA_KEY" ]]; then
    SAIA_KEY=$(head -n 1 "$KEY_FILE" 2>/dev/null || echo "")
  fi
else
  echo "ERROR: No SAIA API key provided." >&2
  echo "Set SAIA_API_KEY env var, or use --key <value> or --key-file <path>." >&2
  exit 1
fi

if [[ -z "$SAIA_KEY" ]]; then
  echo "ERROR: SAIA_API_KEY is empty." >&2
  exit 1
fi

# ── Load models ──────────────────────────────────────────────────────
if [[ ! -f "$MODELS_FILE" ]]; then
  echo "ERROR: Models file not found: $MODELS_FILE" >&2
  exit 1
fi

MODELS=()
while IFS= read -r model || [[ -n "$model" ]]; do
  [[ -z "$model" || "$model" =~ ^# ]] && continue
  MODELS+=("$model")
done < "$MODELS_FILE"

if [[ ${#MODELS[@]} -eq 0 ]]; then
  echo "ERROR: No models found in $MODELS_FILE" >&2
  exit 1
fi

# ── Build --model flags ──────────────────────────────────────────────
MODEL_FLAGS=""
for m in "${MODELS[@]}"; do
  MODEL_FLAGS="$MODEL_FLAGS --model $m"
done

# ── Run provider add ─────────────────────────────────────────────────
echo "Adding GWDG SAIA provider to mcode..."
echo "Base URL: https://chat-ai.academiccloud.de/v1"
echo "API format: openai-completions"
echo "Models: ${#MODELS[@]} models"

mcode provider add \
  --name "GWDG SAIA" \
  --base-url "https://chat-ai.academiccloud.de/v1" \
  --api-format "openai-completions" \
  $MODEL_FLAGS \
  --api-key-env "SAIA_API_KEY"

echo ""
echo "Provider added. Verifying..."
mcode provider list --json | python3 -c "import json,sys; d=json.load(sys.stdin); providers=[p for p in d['providers'] if 'saia' in p.get('name','').lower()]; print(json.dumps(providers, indent=2))"
__MCS_FILE_EOF__

echo 'Extracting src/models.txt...'
cat >"src/models.txt" <<__MCS_FILE_EOF__
apertus-70b-instruct-2509
devstral-2-123b-instruct-2512
qwen3.8-27b
deepseek-v4-flash-0731
qwen3.5-122b-a10b
glm-5.3-flash
qwen3-coder-next
qwen3-omni-30b-a3b-instruct
mistral-medium-3.5-128b
glm-4.7
qwen3.5-397b-a17b
gemma-4-31b-it
qwen3.6-35b-a3b
meta-llama-3.1-8b-instruct
openai-gpt-oss-120b
qwen3-30b-a3b-instruct-2507
__MCS_FILE_EOF__


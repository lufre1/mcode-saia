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

# ── Drop any previous GWDG SAIA provider ─────────────────────────────
# `mcode provider add` does not replace an existing provider, it appends a
# suffixed clone (gwdg-saia-2, -3, ...). Remove first so re-running the
# installer is idempotent instead of accumulating duplicates.
for pid in $(mcode provider list --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for p in d.get('providers', []):
    pid = p.get('providerId', '')
    if pid.startswith('custom_provider:gwdg-saia'):
        print(pid)
"); do
  echo "Removing existing provider $pid"
  mcode provider remove "$pid" --yes >/dev/null 2>&1 || echo "  WARNING: could not remove $pid" >&2
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

DATA_DIR="${MINIMAX_DATA_DIR:-$HOME/.minimax}"
CONFIG_YAML="$DATA_DIR/config.yaml"
DEFAULT_MODEL="${SAIA_DEFAULT_MODEL:-deepseek-v4-flash-0731}"

# ── Make SAIA the default model ──────────────────────────────────────
# Not cosmetic: mcode gates every turn on a MiniMax account login whenever the
# DEFAULT model belongs to a managed-login provider — the check runs at startup,
# so even `--model custom_provider:gwdg-saia/...` still hits "Sign in to MiniMax
# to use Agent features". Pointing defaultModel at SAIA makes mcode usable with
# no MiniMax account at all.
echo ""
echo "Setting default model to custom_provider:gwdg-saia/$DEFAULT_MODEL..."

SAIA_CONFIG_YAML="$CONFIG_YAML" SAIA_DEFAULT="custom_provider:gwdg-saia/$DEFAULT_MODEL" python3 <<'PYDEFAULT'
import os

path = os.environ["SAIA_CONFIG_YAML"]
want = os.environ["SAIA_DEFAULT"]

with open(path) as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.startswith("defaultModel:"):
        current = line.split(":", 1)[1].strip()
        # Leave a default the user picked themselves alone; only take over one
        # that points at a managed-login provider (which is what gates mcode).
        if current and not current.startswith("minimax"):
            print("  left as-is: %s" % current)
            break
        lines[i] = "defaultModel: %s\n" % want
        print("  %s -> %s" % (current or "(empty)", want))
        break
else:
    lines.insert(0, "defaultModel: %s\n" % want)
    print("  added: %s" % want)

with open(path, "w") as f:
    f.writelines(lines)
PYDEFAULT


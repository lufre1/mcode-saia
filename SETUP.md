# GWDG SAIA Provider Setup for mcode

## Summary

This installer registers the GWDG SAIA provider in mcode (MiniMax Code) with all 16 ready models.

## Prerequisites

- **mcode** installed (`npm install -g @minimax-ai/code`)
- **SAIA API key** (from GWDG SAIA)

## Quick start

```bash
SAIA_API_KEY="your-key" bash install-mcode-saia.sh
```

## Detailed installation

### 1. Obtain your SAIA API key

Your key is stored in `~/.local/share/opencode/auth.json` (if you use opencode with SAIA), or you can generate a new one at the GWDG SAIA portal.

### 2. Run the installer

```bash
# Option A: via environment variable
SAIA_API_KEY="your-key" bash install-mcode-saia.sh

# Option B: via --key argument
bash install-mcode-saia.sh --key "your-key"

# Option C: via --key-file (reads from a file)
bash install-mcode-saia.sh --key-file ~/.local/share/opencode/auth.json
```

The installer will:
- Verify mcode is installed
- Back up your existing `~/.minimax/config.yaml` if it contains a `custom_provider:` block
- Run `mcode provider add` with all 16 ready SAIA models
- Verify the provider was added successfully

### 3. Verify installation

```bash
mcode provider list
```

You should see `custom_provider:gwdg-saia` listed.

### 4. Test the provider

```bash
mcode provider test custom_provider:gwdg-saia --model deepseek-v4-flash-0731
```

Expected output: `Provider available: custom_provider:gwdg-saia/deepseek-v4-flash-0731`

## Usage

### Start a session with a SAIA model

```bash
# Use the TUI
mcode

# Or start with a specific model
mcode --model "custom_provider:gwdg-saia/deepseek-v4-flash-0731"
```

### Available models

All 16 ready SAIA models:

- apertus-70b-instruct-2509
- devstral-2-123b-instruct-2512
- qwen3.8-27b
- deepseek-v4-flash-0731
- qwen3.5-122b-a10b
- glm-5.3-flash
- qwen3-coder-next
- qwen3-omni-30b-a3b-instruct
- mistral-medium-3.5-128b
- glm-4.7
- qwen3.5-397b-a17b
- gemma-4-31b-it
- qwen3.6-35b-a3b
- meta-llama-3.1-8b-instruct
- openai-gpt-oss-120b
- qwen3-30b-a3b-instruct-2507

## Config schema

The provider is stored in `~/.minimax/config.yaml` under `custom_provider:`:

```yaml
custom_provider:
  gwdg-saia:
    name: GWDG SAIA
    kind: custom
    enabled: true
    api: openai-completions
    options:
      apiKey: <your-key>
      baseURL: https://chat-ai.academiccloud.de/v1
      authMode: api-key
    models:
      <model-id>:
        reasoning: true
        thinking_config:
          mode: switchable
          default_value: 'true'
```

**Note**: mcode v0.5.0 stores the API key directly in `config.yaml` regardless of `--api-key-env`. The file has 600 permissions (owner read/write only).

## Troubleshooting

### Provider not showing in list

```bash
mcode provider list
mcode provider list --json | python3 -c "import json,sys; d=json.load(sys.stdin); providers=[p for p in d['providers'] if 'saia' in p.get('name','').lower()]; print(json.dumps(providers, indent=2))"
```

### Test provider

```bash
mcode provider test custom_provider:gwdg-saia --model deepseek-v4-flash-0731
```

### Remove provider

```bash
mcode provider remove custom_provider:gwdg-saia
```

### Re-add provider

```bash
SAIA_API_KEY="your-key" bash install-mcode-saia.sh
```

### mcode not found

Install mcode:

```bash
npm install -g @minimax-ai/code
```

### API key errors

- Ensure `SAIA_API_KEY` is set correctly (no quotes in the env var value)
- Verify the key is valid at the GWDG SAIA portal
- Check rate limits: 30 req/min, 200/hour, 1000/day, 3000/month per key

## Advanced: Regenerate the installer

If you modify `src/add-saia-mcode.sh` or `src/models.txt`, regenerate the installer:

```bash
./build.sh
```

This creates a new `install-mcode-saia.sh` with the changes embedded.

## License

MIT
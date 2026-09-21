# mcode-saia

GWDG SAIA provider for **mcode** (MiniMax Code)

This repo provides an installer that registers the [GWDG SAIA](https://chat-ai.academiccloud.de/) OpenAI-compatible API as a custom provider in mcode, giving you access to 16 ready models including Qwen, DeepSeek, GLM, and more.

## Quick start

```bash
SAIA_API_KEY="your-key" bash install-mcode-saia.sh --yes
```

This one-shot installer:
- Installs mcode (if missing) via the official GitHub installer
- Registers the GWDG SAIA provider with 16 ready models
- Works on macOS, Linux, and WSL

Or see `SETUP.md` for detailed instructions and troubleshooting.

## What's included

| File | Purpose |
|------|---------|
| `install-mcode-saia.sh` | Self-contained installer (generated; never edit directly) |
| `build.sh` | Regenerates the installer from source files |
| `src/add-saia-mcode.sh` | Live source script (portable key sourcing) |
| `src/models.txt` | List of 16 ready SAIA models |

## Architecture

```
SAIA_API_KEY → install-mcode-saia.sh → [mcode install] → src/add-saia-mcode.sh → mcode provider add → ~/.minimax/config.yaml
```

## Maintaining

After changing `src/add-saia-mcode.sh` or `src/models.txt`, regenerate the installer:

```bash
./build.sh
```

## License

MIT
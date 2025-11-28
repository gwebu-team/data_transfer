# AGENTS.md

## Build/Test Commands
- **Test script**: `bash -n nc_transfer.sh` (syntax check)
- **Manual test**: Run `./nc_transfer.sh -h` to verify help output
- **Integration test**: Test with actual file transfer using provided arguments
- **Lint**: Use `shellcheck nc_transfer.sh` if available for bash best practices

## Code Style Guidelines
- **Indentation**: 4 spaces (per .editorconfig)
- **Line length**: Max 120 characters
- **Shebang**: Always use `#!/usr/bin/env bash` for bash scripts
- **Error handling**: Use `set -eo pipefail` at script start
- **Functions**: Use lowercase with underscores, e.g., `cleanup()`
- **Variables**: UPPERCASE for constants/script-wide vars, lowercase for local vars
- **Quotes**: Always quote variables with `"${VAR}"` to handle spaces
- **Exit codes**: Use descriptive exit codes (11, 21, 31, etc.) for different error conditions
- **Comments**: Minimal, only for complex logic or user-facing messages
- **Dependencies**: Check for required commands (whiptail, ncat, pv, ssh) before use
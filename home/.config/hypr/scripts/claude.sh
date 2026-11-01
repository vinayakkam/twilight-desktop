#!/bin/sh
# Claude Code in a terminal, started through your login shell (fish) so the
# PATH that MCP servers need (pnpm, ~/.local/bin, …) is complete. Konsole gives
# a right-click Copy / Paste menu. The shell
# stays open after Claude exits.
cd "$HOME" || exit 1
exec konsole --profile Twilight -e fish -l -C claude

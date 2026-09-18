#!/usr/bin/env bash
# Tests the PATH-handling half of the Claude Code install one-liner.
# Runs against a throwaway HOME, so it never touches the real ~/.zshrc.
# It does not run the curl installer.

set -u
fail=0

# The exact snippet from the one-liner, minus the curl install and final echo.
path_snippet='{ grep -q "/.local/bin" ~/.zshrc 2>/dev/null || echo '"'"'export PATH="$HOME/.local/bin:$PATH"'"'"' >> ~/.zshrc; } && export PATH="$HOME/.local/bin:$PATH"'

check() { # name, condition-exit-code
  if [ "$2" -eq 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi
}

run_snippet() { HOME="$1" bash -c "$path_snippet; echo \"\$PATH\""; }

# 1. No .zshrc yet: it gets created with the PATH line.
h=$(mktemp -d)
run_snippet "$h" >/dev/null
grep -q '/.local/bin' "$h/.zshrc"; check "creates .zshrc with PATH line" $?

# 2. Running it twice does not duplicate the line.
run_snippet "$h" >/dev/null
[ "$(grep -c '/.local/bin' "$h/.zshrc")" -eq 1 ]; check "is idempotent (one line after two runs)" $?

# 3. Existing .zshrc content is preserved.
h2=$(mktemp -d)
echo 'alias ll="ls -l"' > "$h2/.zshrc"
run_snippet "$h2" >/dev/null
grep -q 'alias ll=' "$h2/.zshrc"; check "keeps existing .zshrc content" $?

# 4. A .zshrc that already mentions .local/bin is left untouched.
h3=$(mktemp -d)
echo 'export PATH="$HOME/.local/bin:$PATH"' > "$h3/.zshrc"
before=$(cat "$h3/.zshrc")
run_snippet "$h3" >/dev/null
[ "$before" = "$(cat "$h3/.zshrc")" ]; check "does not modify a .zshrc that already has it" $?

# 5. The current shell's PATH gets ~/.local/bin first.
out=$(run_snippet "$h")
case "$out" in "$h/.local/bin:"*) r=0 ;; *) r=1 ;; esac
check "puts ~/.local/bin at the front of PATH" $r

rm -rf "$h" "$h2" "$h3"
exit $fail

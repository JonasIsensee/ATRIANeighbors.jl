#!/bin/bash

# Example: Only run in remote environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

curl -fsSL https://install.julialang.org > juliaup.sh
sh juliaup.sh -y --default-channel lts

if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PATH="$PATH:$HOME/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
# Workaround: juliaup sometimes fails to create the julia symlink
# See: https://github.com/JuliaLang/juliaup/issues/574
if [ ! -e "$HOME/.juliaup/bin/julia" ]; then
  ln -s julialauncher "$HOME/.juliaup/bin/julia"
fi

# Add to PATH
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PATH="$PATH:$HOME/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
else
  # Fallback: add to .bashrc if CLAUDE_ENV_FILE not set
  if ! grep -q "/.juliaup/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/.juliaup/bin"' >> "$HOME/.bashrc"
  fi
fi

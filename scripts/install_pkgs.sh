#!/bin/bash

# Example: Only run in remote environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

curl -fsSL https://install.julialang.org > juliaup.sh
sh juliaup.sh -y --default-channel release
/root/.juliaup/bin/juliaup add release
/root/.juliaup/bin/juliaup add 1.11
/root/.juliaup/bin/juliaup add 1.10
/root/.juliaup/bin/juliaup default 1.10
/root/.juliaup/bin/juliaup config channelsymlinks true

if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
# Workaround: juliaup sometimes fails to create the julia symlink
# See: https://github.com/JuliaLang/juliaup/issues/574
if [ ! -e "/root/.juliaup/bin/julia" ]; then
  ln -s julialauncher "/root/.juliaup/bin/julia"
fi

# Add to PATH
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
else
  # Fallback: add to .bashrc if CLAUDE_ENV_FILE not set
  if ! grep -q "/.juliaup/bin" "/root/.bashrc" 2>/dev/null; then
    echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$HOME/.bashrc"
  fi
fi

#!/bin/bash

# Example: Only run in remote environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

curl -fsSL https://install.julialang.org > juliaup.sh
sh juliaup.sh -y
$HOME/.juliaup/bin/juliaup add release


if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PATH="$PATH:$HOME/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
fi

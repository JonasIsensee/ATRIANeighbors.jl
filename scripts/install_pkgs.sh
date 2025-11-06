#!/bin/bash

# Julia installation script with comprehensive logging
# Log files will be created in /tmp for debugging
#
# This script is designed to run as a SessionStart hook in Claude Code.
# It uses CLAUDE_ENV_FILE (available only in SessionStart hooks) to persist
# the PATH modification across all bash commands in the session.
#
# IMPORTANT: PATH is configured immediately after LTS installation (Step 5)
# to ensure Julia is available even if later installation steps timeout.
#
# See: https://code.claude.com/docs/en/hooks#sessionstart

LOGDIR="/tmp/julia_install_logs"
LOGFILE="${LOGDIR}/install_$(date +%Y%m%d_%H%M%S).log"
ERRORLOG="${LOGDIR}/install_errors_$(date +%Y%m%d_%H%M%S).log"

# Create log directory
mkdir -p "$LOGDIR"

# Function to log with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOGFILE" | tee -a "$ERRORLOG" >&2
}

log_command() {
  local cmd="$*"
  log "Executing: $cmd"
  eval "$cmd" 2>&1 | tee -a "$LOGFILE"
  local exit_code=${PIPESTATUS[0]}
  if [ $exit_code -ne 0 ]; then
    log_error "Command failed with exit code $exit_code: $cmd"
    return $exit_code
  else
    log "Command succeeded: $cmd"
  fi
  return 0
}

# Enable debug mode for detailed execution trace
set -x

log "========================================="
log "Julia Installation Script Starting"
log "========================================="
log "Log file: $LOGFILE"
log "Error log: $ERRORLOG"
log "Current user: $(whoami)"
log "Current directory: $(pwd)"
log "HOME: $HOME"
log "CLAUDE_CODE_REMOTE: $CLAUDE_CODE_REMOTE"
log "CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"

# Check if running in remote environment
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  log "Not running in remote environment (CLAUDE_CODE_REMOTE != true), exiting"
  exit 0
fi

log "Step 1: Downloading juliaup installer"
log_command "curl -fsSL https://install.julialang.org -o juliaup.sh"
if [ $? -ne 0 ]; then
  log_error "Failed to download juliaup installer"
  exit 1
fi

log "Step 2: Checking juliaup.sh contents"
log "File size: $(wc -c < juliaup.sh) bytes"
log "First 10 lines:"
head -10 juliaup.sh | tee -a "$LOGFILE"

log "Step 3: Running juliaup installer"
log_command "sh juliaup.sh -y --default-channel lts"
if [ $? -ne 0 ]; then
  log_error "Juliaup installer failed"
  exit 1
fi

log "Step 4: Checking if juliaup binary exists"
if [ -f "/root/.juliaup/bin/juliaup" ]; then
  log "juliaup binary found at /root/.juliaup/bin/juliaup"
  log_command "ls -lh /root/.juliaup/bin/"
else
  log_error "juliaup binary not found at /root/.juliaup/bin/juliaup"
  exit 1
fi

log "Step 5: Configuring PATH (moved early to ensure availability)"
if [ -n "$CLAUDE_ENV_FILE" ]; then
  log "Adding to CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"

  # Ensure the directory for CLAUDE_ENV_FILE exists
  CLAUDE_ENV_DIR=$(dirname "$CLAUDE_ENV_FILE")
  if [ ! -d "$CLAUDE_ENV_DIR" ]; then
    log "Creating directory for CLAUDE_ENV_FILE: $CLAUDE_ENV_DIR"
    mkdir -p "$CLAUDE_ENV_DIR" 2>&1 | tee -a "$LOGFILE"
    if [ $? -ne 0 ]; then
      log_error "Failed to create directory $CLAUDE_ENV_DIR"
    fi
  fi

  # Touch the file to ensure it exists
  if [ ! -f "$CLAUDE_ENV_FILE" ]; then
    log "Creating CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
    touch "$CLAUDE_ENV_FILE" 2>&1 | tee -a "$LOGFILE"
    if [ $? -ne 0 ]; then
      log_error "Failed to create file $CLAUDE_ENV_FILE"
    fi
  fi

  # Add Julia to PATH in CLAUDE_ENV_FILE
  echo 'export PATH="/root/.juliaup/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
  log "Added Julia to CLAUDE_ENV_FILE"

  # Show contents
  if [ -f "$CLAUDE_ENV_FILE" ]; then
    log "Contents of CLAUDE_ENV_FILE:"
    cat "$CLAUDE_ENV_FILE" | tee -a "$LOGFILE"
  else
    log_error "CLAUDE_ENV_FILE still does not exist after creation attempt"
  fi
else
  log "CLAUDE_ENV_FILE not set, adding to .bashrc"
  if ! grep -q "/.juliaup/bin" "/root/.bashrc" 2>/dev/null; then
    echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$HOME/.bashrc"
    log "Added to .bashrc"
  else
    log ".bashrc already contains juliaup path"
  fi
fi

log "Step 6: Enabling channel symlinks"
log_command "/root/.juliaup/bin/juliaup config channelsymlinks true"

log "Step 7: Checking juliaup status"
log_command "/root/.juliaup/bin/juliaup status"

log "Step 8: Checking for julia symlink"
if [ ! -e "/root/.juliaup/bin/julia" ]; then
  log "julia symlink not found, creating workaround symlink"
  # Workaround: juliaup sometimes fails to create the julia symlink
  # See: https://github.com/JuliaLang/juliaup/issues/574
  log_command "ln -s julialauncher /root/.juliaup/bin/julia"
else
  log "julia symlink already exists"
fi

log "Step 9: Verifying julia executable"
log_command "ls -lh /root/.juliaup/bin/julia*"

log "Step 10: Testing julia execution"
if [ -e "/root/.juliaup/bin/julia" ]; then
  log_command "/root/.juliaup/bin/julia --version"
else
  log_error "julia executable still not found after symlink creation"
fi

log "Step 11: Final verification"
log "Directory listing of /root/.juliaup/bin/:"
ls -lha /root/.juliaup/bin/ | tee -a "$LOGFILE"

log "Directory listing of /root/.julia/juliaup/:"
ls -lha /root/.julia/juliaup/ | tee -a "$LOGFILE"

log "Contents of juliaup.json:"
if [ -f "/root/.julia/juliaup/juliaup.json" ]; then
  cat /root/.julia/juliaup/juliaup.json | tee -a "$LOGFILE"
else
  log_error "juliaup.json not found"
fi

log "Step 12: Verifying PATH configuration (configured in Step 5)"
if [ -n "$CLAUDE_ENV_FILE" ] && [ -f "$CLAUDE_ENV_FILE" ]; then
  log "SUCCESS: CLAUDE_ENV_FILE is configured and will be loaded by Claude Code"
  log "Julia should be available in PATH for all subsequent bash commands"
elif grep -q "/.juliaup/bin" "/root/.bashrc" 2>/dev/null; then
  log "SUCCESS: Julia PATH added to .bashrc"
  log "Note: In Claude Code remote environment, you may need to manually export PATH in this session:"
  log "  export PATH=\"/root/.juliaup/bin:\$PATH\""
else
  log_error "Julia PATH not configured in CLAUDE_ENV_FILE or .bashrc"
fi

log "========================================="
log "Julia Installation Script Completed"
log "========================================="
log "Check logs at:"
log "  Main log: $LOGFILE"
log "  Error log: $ERRORLOG"

# Disable debug mode
set +x

#!/bin/bash

# Julia installation script with comprehensive logging
# Log files will be created in /tmp for debugging

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

log "Step 6: Adding Julia 1.11"
log_command "/root/.juliaup/bin/juliaup add 1.11"

log "Step 7: Adding Julia 1.10"
log_command "/root/.juliaup/bin/juliaup add 1.10"

log "Step 8: Setting default Julia version to 1.10"
log_command "/root/.juliaup/bin/juliaup default 1.10"

log "Step 9: Enabling channel symlinks"
log_command "/root/.juliaup/bin/juliaup config channelsymlinks true"

log "Step 10: Checking juliaup status"
log_command "/root/.juliaup/bin/juliaup status"

log "Step 11: Checking for julia symlink"
if [ ! -e "/root/.juliaup/bin/julia" ]; then
  log "julia symlink not found, creating workaround symlink"
  # Workaround: juliaup sometimes fails to create the julia symlink
  # See: https://github.com/JuliaLang/juliaup/issues/574
  log_command "ln -s julialauncher /root/.juliaup/bin/julia"
else
  log "julia symlink already exists"
fi

log "Step 12: Verifying julia executable"
log_command "ls -lh /root/.juliaup/bin/julia*"

log "Step 13: Testing julia execution"
if [ -e "/root/.juliaup/bin/julia" ]; then
  log_command "/root/.juliaup/bin/julia --version"
else
  log_error "julia executable still not found after symlink creation"
fi

log "Step 14: Adding to PATH"
if [ -n "$CLAUDE_ENV_FILE" ]; then
  log "Adding to CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
  echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$CLAUDE_ENV_FILE"
  log "Contents of CLAUDE_ENV_FILE:"
  cat "$CLAUDE_ENV_FILE" | tee -a "$LOGFILE"
else
  log "CLAUDE_ENV_FILE not set, adding to .bashrc"
  if ! grep -q "/.juliaup/bin" "/root/.bashrc" 2>/dev/null; then
    echo 'export PATH="$PATH:/root/.juliaup/bin"' >> "$HOME/.bashrc"
    log "Added to .bashrc"
  else
    log ".bashrc already contains juliaup path"
  fi
fi

log "Step 15: Final verification"
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

log "========================================="
log "Julia Installation Script Completed"
log "========================================="
log "Check logs at:"
log "  Main log: $LOGFILE"
log "  Error log: $ERRORLOG"

# Disable debug mode
set +x

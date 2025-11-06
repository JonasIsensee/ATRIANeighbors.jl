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

# Function to retry commands with exponential backoff
retry_command() {
  local max_attempts=3
  local timeout=120
  local attempt=1
  local exitCode=0
  local cmd="$*"

  while [ $attempt -le $max_attempts ]; do
    log "Attempt $attempt/$max_attempts: $cmd"

    if timeout "$timeout" bash -c "$cmd" 2>&1 | tee -a "$LOGFILE"; then
      log "Command succeeded on attempt $attempt"
      return 0
    fi

    exitCode=$?

    if [ $exitCode -eq 124 ]; then
      log_error "Command timed out after ${timeout}s on attempt $attempt"
    else
      log_error "Command failed with exit code $exitCode on attempt $attempt"
    fi

    if [ $attempt -lt $max_attempts ]; then
      local wait_time=$((2 ** attempt))
      log "Waiting ${wait_time}s before retry..."
      sleep $wait_time
    fi

    attempt=$((attempt + 1))
  done

  log_error "Command failed after $max_attempts attempts: $cmd"
  return $exitCode
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

log "Step 3: Running juliaup installer (skip default channel)"
# Use --default-channel none to avoid auto-installing Julia 1.12
log_command "sh juliaup.sh -y --default-channel none"
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

log "Step 5: Remove any auto-installed versions"
if /root/.juliaup/bin/juliaup status | grep -q "1.12"; then
  log "Removing Julia 1.12"
  log_command "/root/.juliaup/bin/juliaup remove 1.12" || log "1.12 removal failed or not needed"
fi

log "Step 6: Adding Julia 1.10 (with retry)"
if ! retry_command "/root/.juliaup/bin/juliaup add 1.10"; then
  log_error "Failed to add Julia 1.10 after retries"
  exit 1
fi

log "Step 7: Verifying Julia 1.10 installation"
if /root/.juliaup/bin/juliaup status | grep -q "1.10"; then
  log "Julia 1.10 successfully installed"
else
  log_error "Julia 1.10 not found in juliaup status"
  exit 1
fi

log "Step 8: Adding Julia 1.11 (with retry)"
if ! retry_command "/root/.juliaup/bin/juliaup add 1.11"; then
  log_error "Failed to add Julia 1.11 after retries"
  exit 1
fi

log "Step 9: Verifying Julia 1.11 installation"
if /root/.juliaup/bin/juliaup status | grep -q "1.11"; then
  log "Julia 1.11 successfully installed"
else
  log_error "Julia 1.11 not found in juliaup status"
  exit 1
fi

log "Step 10: Setting default Julia version to 1.10"
log_command "/root/.juliaup/bin/juliaup default 1.10"
if [ $? -ne 0 ]; then
  log_error "Failed to set default Julia version"
  exit 1
fi

log "Step 11: Enabling channel symlinks"
log_command "/root/.juliaup/bin/juliaup config channelsymlinks true"

log "Step 12: Checking juliaup status"
log_command "/root/.juliaup/bin/juliaup status"

log "Step 13: Checking for julia symlink"
if [ ! -e "/root/.juliaup/bin/julia" ]; then
  log "julia symlink not found, creating workaround symlink"
  # Workaround: juliaup sometimes fails to create the julia symlink
  # See: https://github.com/JuliaLang/juliaup/issues/574
  log_command "cd /root/.juliaup/bin && ln -sf julialauncher julia && cd -"
else
  log "julia symlink already exists"
fi

log "Step 14: Verifying julia executable"
log_command "ls -lh /root/.juliaup/bin/julia*"

log "Step 15: Testing julia execution"
if [ -e "/root/.juliaup/bin/julia" ]; then
  if ! retry_command "/root/.juliaup/bin/julia --version"; then
    log_error "Julia execution test failed after retries"
    exit 1
  fi
else
  log_error "julia executable still not found after symlink creation"
  exit 1
fi

log "Step 16: Adding to PATH"
# First check if .bashrc has the juliaup path (juliaup installer should have added it)
if grep -q "/.juliaup/bin" "/root/.bashrc" 2>/dev/null; then
  log ".bashrc already contains juliaup path from installer"
else
  log ".bashrc missing juliaup path, adding manually"
  echo 'export PATH="/root/.juliaup/bin:$PATH"' >> "$HOME/.bashrc"
fi

# Also add to CLAUDE_ENV_FILE if it exists and is writable
if [ -n "$CLAUDE_ENV_FILE" ]; then
  # Create parent directory if needed
  CLAUDE_ENV_DIR=$(dirname "$CLAUDE_ENV_FILE")
  if [ ! -d "$CLAUDE_ENV_DIR" ]; then
    log "Creating CLAUDE_ENV_FILE directory: $CLAUDE_ENV_DIR"
    mkdir -p "$CLAUDE_ENV_DIR" || log_error "Failed to create CLAUDE_ENV_FILE directory"
  fi

  if [ -d "$CLAUDE_ENV_DIR" ]; then
    log "Adding to CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
    echo 'export PATH="/root/.juliaup/bin:$PATH"' >> "$CLAUDE_ENV_FILE" 2>/dev/null && \
      log "Successfully wrote to CLAUDE_ENV_FILE" || \
      log_error "Failed to write to CLAUDE_ENV_FILE (may not be writable)"
  fi
else
  log "CLAUDE_ENV_FILE not set, skipping"
fi

# Export PATH for current session
export PATH="/root/.juliaup/bin:$PATH"
log "Exported PATH for current session: $PATH"

log "Step 17: Final verification"
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

log "Step 18: Final working test"
log "Testing julia, juliaup, and julialauncher commands:"
if command -v julia &> /dev/null; then
  log "✓ julia command is available in PATH"
  julia --version | tee -a "$LOGFILE" || log_error "julia --version failed"
else
  log_error "✗ julia command not found in PATH"
fi

if command -v juliaup &> /dev/null; then
  log "✓ juliaup command is available in PATH"
  juliaup --version | tee -a "$LOGFILE" || log_error "juliaup --version failed"
else
  log_error "✗ juliaup command not found in PATH"
fi

if command -v julialauncher &> /dev/null; then
  log "✓ julialauncher command is available in PATH"
else
  log_error "✗ julialauncher command not found in PATH"
fi

log "========================================="
log "Julia Installation Script Completed"
log "========================================="
log "Check logs at:"
log "  Main log: $LOGFILE"
log "  Error log: $ERRORLOG"
log ""
log "To use Julia in your current shell, run:"
log "  export PATH=\"/root/.juliaup/bin:\$PATH\""
log "Or start a new shell session."

# Disable debug mode
set +x

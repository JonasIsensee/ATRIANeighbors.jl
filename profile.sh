#!/bin/bash
#
# profile.sh - Convenience wrapper for profiling ATRIANeighbors.jl
#
# Usage:
#   ./profile.sh              # Run minimal profiling
#   ./profile.sh full         # Run comprehensive profiling (requires benchmark deps)
#   ./profile.sh setup        # Install dependencies
#   ./profile.sh view         # View profiling results
#

set -e

JULIA="${JULIA:-$HOME/.juliaup/bin/julia}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_julia() {
    if [ ! -x "$JULIA" ]; then
        error "Julia not found at $JULIA. Set JULIA environment variable or install Julia."
    fi
    info "Using Julia: $JULIA"
}

setup() {
    info "Installing dependencies..."
    check_julia

    # Install main project dependencies
    info "Installing main project dependencies..."
    cd "$PROJECT_DIR"
    $JULIA --project=. -e 'using Pkg; Pkg.instantiate()' || \
        warn "Main project dependencies failed (may be network issue)"

    # Install benchmark dependencies
    info "Installing benchmark dependencies..."
    cd "$PROJECT_DIR/benchmark"
    $JULIA --project=. -e 'using Pkg; Pkg.instantiate()' || \
        warn "Benchmark dependencies failed (may be network issue)"

    # Try to install PProf (optional)
    info "Installing PProf.jl (optional)..."
    $JULIA --project=. -e 'using Pkg; Pkg.add("PProf")' || \
        warn "PProf.jl installation failed (optional, can continue without it)"

    info "Setup complete!"
}

profile_minimal() {
    info "Running minimal profiling (built-in Profile module only)..."
    check_julia
    cd "$PROJECT_DIR"
    $JULIA --project=. profile_minimal.jl
}

profile_full() {
    info "Running comprehensive profiling (requires benchmark dependencies)..."
    check_julia
    cd "$PROJECT_DIR"
    $JULIA --project=benchmark benchmark/profile_atria.jl
}

view_results() {
    RESULTS_DIR="$PROJECT_DIR/profile_results"

    if [ ! -d "$RESULTS_DIR" ]; then
        error "No profiling results found. Run './profile.sh' first."
    fi

    info "Profiling results:"
    echo

    # Summary
    if [ -f "$RESULTS_DIR/profile_summary.txt" ]; then
        echo "================================ SUMMARY ================================"
        cat "$RESULTS_DIR/profile_summary.txt"
        echo
    fi

    info "Available result files:"
    ls -lh "$RESULTS_DIR"
    echo
    info "To view detailed results:"
    echo "  Tree view:  less $RESULTS_DIR/profile_tree.txt"
    echo "  Flat view:  less $RESULTS_DIR/profile_flat.txt"

    if [ -f "$RESULTS_DIR/profile.pb.gz" ]; then
        echo "  PProf:      pprof -http=:8080 $RESULTS_DIR/profile.pb.gz"
    fi
}

usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    (none)    Run minimal profiling (default)
    full      Run comprehensive profiling with PProf
    setup     Install dependencies
    view      View profiling results
    help      Show this help message

Environment Variables:
    JULIA     Path to Julia executable (default: ~/.juliaup/bin/julia)

Examples:
    $0                      # Quick profiling
    $0 full                 # Comprehensive profiling
    $0 view                 # View results
    JULIA=/usr/bin/julia $0 # Use custom Julia path

EOF
}

# Main
case "${1:-}" in
    setup)
        setup
        ;;
    full)
        profile_full
        ;;
    view)
        view_results
        ;;
    help|--help|-h)
        usage
        ;;
    "")
        profile_minimal
        ;;
    *)
        error "Unknown command: $1. Run '$0 help' for usage."
        ;;
esac

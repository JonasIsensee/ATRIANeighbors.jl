# Profiling Scripts

This directory contains scripts for profiling the ATRIANeighbors package.

## Setup

This directory uses Julia 1.12's workspace feature to depend on local versions of:
- `ATRIANeighbors` (from the parent directory)
- `ProfilingAnalysis.jl` (from `../ProfilingAnalysis.jl`)

To set up the environment:

```bash
cd profiling
export PATH="$HOME/.juliaup/bin:$PATH"
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Running Profiling Scripts

All profiling scripts should be run with the profiling environment:

```bash
# Run a profiling script
julia --project=. profile_minimal.jl

# Run intensive profiling
julia --project=. profile_intensive.jl

# Analyze profiling results
julia --project=. profile_analyzer.jl
```

## Scripts

- `profile_minimal.jl` - Minimal profiling with small datasets
- `profile_intensive.jl` - Intensive profiling with larger datasets
- `profile_analyzer.jl` - Analyze and visualize profiling results
- `test_profile_scalability.jl` - Test how profiling scales with data size
- `demo_profiling_improvements.jl` - Demonstrate profiling improvements

## Workspace Feature

The workspace feature in Julia 1.12+ allows this environment to depend on local packages without needing to install or develop them. Changes to ATRIANeighbors or ProfilingAnalysis.jl are immediately reflected when running profiling scripts.

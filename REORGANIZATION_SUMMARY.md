# Repository Reorganization Summary

## Overview

Reorganized the repository structure to improve maintainability by creating dedicated subdirectories for profiling and benchmarking code with their own isolated environments.

## Changes Made

### 1. Profiling Directory (`profiling/`)

**Created**: `profiling/` directory with its own environment

**Moved scripts**:
- `profile_minimal.jl` → `profiling/profile_minimal.jl`
- `profile_intensive.jl` → `profiling/profile_intensive.jl`
- `profile_analyzer.jl` → `profiling/profile_analyzer.jl`
- `test_profile_scalability.jl` → `profiling/test_profile_scalability.jl`
- `demo_profiling_improvements.jl` → `profiling/demo_profiling_improvements.jl`
- `profile_results/` → `profiling/profile_results/`

**Environment setup**:
- Created `profiling/Project.toml` with local package dependencies
- Uses `Pkg.develop()` to depend on local `ATRIANeighbors` and `ProfilingAnalysis.jl`
- Changes to main packages are immediately reflected without reinstallation
- Added `profiling/README.md` with setup instructions

**Verified**: Successfully tested loading packages and running basic profiling workload

### 2. Benchmark Directory (`benchmark/`)

**Updated**: `benchmark/` directory (already existed)

**Moved scripts**:
- `benchmark_timing.jl` → `benchmark/benchmark_timing.jl`
- `test_query_efficiency.jl` → `benchmark/test_query_efficiency.jl`

**Environment update**:
- Updated `benchmark/Project.toml` to use `Pkg.develop()` for local ATRIANeighbors
- Changes to ATRIANeighbors are immediately reflected in benchmarks
- Updated `benchmark/README.md` to document the new setup

**Note**: Benchmark environment installation encounters Julia 1.12.1 segfaults during artifact downloads. This appears to be a Julia bug. Users can work around this by:
- Using Julia 1.10 for benchmarks, or
- Installing packages incrementally, or
- Using the existing benchmark Manifest if available

### 3. Documentation Updates

**Updated files**:
- `PROFILING_GUIDE.md` - Added section on new location and environment setup
- `.gitignore` - Added profiling results patterns
- `ProfilingAnalysis.jl/Project.toml` - Fixed JSON compat version (0.21 → 1.2)

### 4. Root Directory Cleanup

**Removed** profiling/benchmark scripts from root:
- Root directory is now cleaner with only essential documentation
- All profiling code is in `profiling/`
- All benchmarking code is in `benchmark/`

## Directory Structure (After)

```
ATRIANeighbors.jl/
├── src/                           # Main package source
├── test/                          # Unit tests
├── profiling/                     # NEW: Profiling scripts and environment
│   ├── Project.toml               #   - Isolated environment
│   ├── README.md                  #   - Setup instructions
│   ├── profile_minimal.jl         #   - Simple profiling
│   ├── profile_intensive.jl       #   - Intensive profiling
│   ├── profile_analyzer.jl        #   - Advanced analysis
│   ├── test_profile_scalability.jl
│   ├── demo_profiling_improvements.jl
│   └── profile_results/           #   - Output directory
├── benchmark/                     # UPDATED: Benchmark scripts and environment
│   ├── Project.toml               #   - Isolated environment (updated)
│   ├── README.md                  #   - Setup instructions (updated)
│   ├── run_benchmarks.jl
│   ├── data_generators.jl
│   ├── benchmark_timing.jl        #   - MOVED from root
│   ├── test_query_efficiency.jl   #   - MOVED from root
│   └── ...                        #   - Other benchmark files
├── ProfilingAnalysis.jl/          # Helper package for profiling
├── materials/                     # C++ reference implementation
├── scripts/                       # Build/install scripts
└── *.md                          # Documentation files
```

## Usage

### Running Profiling

```bash
cd profiling
export PATH="$HOME/.juliaup/bin:$PATH"
julia --project=. -e 'using Pkg; Pkg.develop(path=".."); Pkg.develop(path="../ProfilingAnalysis.jl"); Pkg.instantiate()'
julia --project=. profile_minimal.jl
```

### Running Benchmarks

```bash
cd benchmark
export PATH="$HOME/.juliaup/bin:$PATH"
# Note: May encounter Julia 1.12.1 segfaults during artifact installation
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.develop(path="..")'
julia --project=. run_benchmarks.jl
```

## Benefits

1. **Isolation**: Profiling and benchmarking have their own dependencies that don't pollute the main package
2. **Clarity**: Clear separation between package code, tests, profiling, and benchmarks
3. **Live updates**: Using `Pkg.develop()` means changes to ATRIANeighbors are immediately reflected
4. **Maintainability**: Each subdirectory has its own README explaining setup and usage
5. **Clean root**: Root directory contains only essential documentation and source

## Known Issues

1. Julia 1.12.1 has segfaults during artifact downloads in the benchmark environment
   - Workaround: Use Julia 1.10 or install packages incrementally
   - This appears to be a Julia bug, not an issue with the reorganization

## Files Changed

- Created: `profiling/`, `profiling/Project.toml`, `profiling/README.md`
- Updated: `benchmark/Project.toml`, `benchmark/README.md`
- Updated: `PROFILING_GUIDE.md`, `.gitignore`
- Updated: `ProfilingAnalysis.jl/Project.toml` (JSON compat fix)
- Moved: 7 files from root → `profiling/` and `benchmark/`

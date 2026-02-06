# ATRIANeighbors.jl Benchmark Suite

Comprehensive benchmarking suite for evaluating ATRIANeighbors.jl performance against multiple nearest neighbor search libraries.

## Quick Start

### Setup

First, clone the repository and set up the benchmark environment:

```bash
# Clone the repository
git clone https://github.com/JonasIsensee/ATRIANeighbors.jl
cd ATRIANeighbors.jl

# Navigate to the benchmark directory
cd benchmark

# Install dependencies and link local ATRIANeighbors package
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.develop(path="..")'
```

**Important:** The `Pkg.develop(path="..")` step ensures the benchmark uses your local ATRIANeighbors source code rather than trying to fetch from a package registry. This is required for running benchmarks from the repository.

### Run Benchmarks

**Single unified entry point** for all benchmarks:

```bash
# Quick sanity check (data distribution demonstration)
julia --project=. benchmark.jl quick

# Generate README performance table
julia --project=. benchmark.jl readme

# Library comparison (quick/standard/comprehensive)
julia --project=. benchmark.jl compare quick
julia --project=. benchmark.jl compare standard
julia --project=. benchmark.jl compare comprehensive

# Profile memory allocations
julia --project=. benchmark.jl profile-alloc

# Profile performance bottlenecks
julia --project=. benchmark.jl profile-perf

# Show help
julia --project=. benchmark.jl help
```

## Benchmark Commands

### `quick` - Data Distribution Demo

Fast demonstration (< 1 minute) showing how ATRIA performance depends on data structure:

- **Random data**: Poor performance (~0.5x vs brute force) - no structure to exploit
- **Clustered data**: Good performance (~2x vs brute force) - 89% pruning
- **Very clustered**: Excellent performance (~3x vs brute force) - 97% pruning

**Example output:**

```
Random data:        f_k=1.0, speedup=0.49x
Clustered data:     f_k=0.11, speedup=2.0x
Very clustered:     f_k=0.03, speedup=2.85x
```

This validates ATRIA's design for low-dimensional manifolds in high-D space.

### `readme` - README Performance Table

Generates the two performance tables for the README (2–5 minutes):

- **Scenario A (low-D):** 3D Lorenz attractor — NearestNeighbors (KDTree/BallTree) typically wins.
- **Scenario B (high-D, low fractal):** 24D delay-embedded Lorenz — ATRIA typically wins.
- Compares ATRIA vs KDTree, BallTree, and brute force; N=50,000, k=10, 100 queries.
- Copy the printed tables into the main README to reflect your hardware.

### `compare` - Library Comparison

Comprehensive benchmarks comparing multiple libraries across datasets:

**Modes:**

- `quick`: Small test (2-5 minutes) - 3 datasets, N≤10k, 3 trials
- `standard`: Standard suite (15-30 minutes) - 5 datasets, N≤50k, 5 trials
- `comprehensive`: Full suite (1-2 hours) - 8 datasets, N≤100k, 10 trials

**Output:**

- Markdown report (`BENCHMARK_REPORT.md`) with comparative analysis
- PNG plots comparing performance across all libraries
- Detailed results table with all metrics
- Results cached in `results/library_comparison_*/`

### `profile-alloc` - Allocation Profiling

Profiles memory allocations showing the benefit of SearchContext reuse:

```
WITHOUT context reuse: 32752 bytes (511 allocations)
WITH context reuse:    288 bytes (2 allocations)
Reduction: 32464 bytes (99.1%)
```

**Recommendation:** Always use `SearchContext` for batch queries!

**Example:**

```julia
ctx = SearchContext(tree, k)
for query in queries
    neighbors = knn(tree, query, k=k, ctx=ctx)
end
```

### `profile-perf` - Performance Profiling

Detailed performance analysis identifying bottlenecks:

- Type stability checks with `@code_warntype`
- Memory allocation analysis
- CPU profiling with sample counts
- Cache behavior analysis (sequential vs random access)

## File Structure

```
benchmark/
├── benchmark.jl              # ⭐ Single unified entry point
├── analyze_bottlenecks.jl    # Detailed profiling (used by profile-perf)
├── library_comparison.jl     # Library comparison infrastructure
├── run_full_comparison.jl    # Full comparison runner (used by compare)
├── utils/
│   ├── data_generators.jl    # Dataset generation utilities
│   ├── cache.jl              # Result caching system
│   └── plotting.jl           # Visualization utilities
└── results/                  # Cached results and reports
```

## Libraries Compared

- **ATRIANeighbors.jl** (this package) - ATRIA algorithm optimized for chaotic time series
- **NearestNeighbors.jl** - KDTree, BallTree, and BruteTree implementations
- **HNSW.jl** - Hierarchical Navigable Small World graphs (optional)

## Dataset Types

Available via `generate_dataset()` in `utils/data_generators.jl`:

### Time Series Attractors (ATRIA's primary use case)

- `:lorenz` - Lorenz attractor (3D, chaotic; low-D regime where NearestNeighbors excels)
- `:lorenz_delay` - Delay-embedded Lorenz (configurable D; high-D, low fractal dimension — ATRIA regime)
- `:rossler` - Rössler attractor (3D, chaotic)
- `:henon` - Henon map (2D, chaotic)
- `:logistic` - Logistic map (1D)

### Clustered Data

- `:gaussian_mixture` - Gaussian mixture model (configurable clusters)
- `:hierarchical` - Hierarchically clustered data

### Manifold Data

- `:swiss_roll` - Swiss roll (2D manifold in 3D)
- `:s_curve` - S-curve (2D manifold in 3D)
- `:sphere` - Points on sphere (configurable D)
- `:torus` - Torus (3D)

### Uniform Data (baseline)

- `:uniform_hypercube` - Uniform in [0,1]^D
- `:uniform_hypersphere` - Uniform in hypersphere
- `:gaussian` - Standard Gaussian

### Pathological Cases

- `:line` - Points on a line (1D manifold in high-D space)
- `:grid` - Regular grid
- `:skewed_gaussian` - Highly skewed distribution

## When ATRIA Excels

ATRIA outperforms KDTree/BallTree on:

- **Reasonably high embedding dimension (e.g. 20–40D)** with **low fractal dimension**
- Delay embeddings of chaotic attractors or chaotic maps
- Time series / nonlinear dynamics applications where intrinsic dimension << embedding dimension
- Large datasets (N > 10,000) with manifold-like structure

## When NearestNeighbors Excels

Use KDTree/BallTree (NearestNeighbors.jl) for:

- **Low-dimensional data (e.g. D ≤ 5)** — they are very fast and highly effective
- General spatial data in 2D/3D (e.g. points in the plane or in 3D space)

## When ATRIA Struggles

ATRIA may be slower on:

- **Low-D data** — prefer NearestNeighbors.jl
- **Random high-dimensional data** (no structure to exploit, 0% pruning)
- Very small datasets (N < 1,000, tree overhead dominates)
- Grid-like structured data

## Advanced Usage

### Running from Julia REPL

```julia
# Start Julia from the benchmark/ directory with the benchmark project
# cd benchmark
# julia --project=.

# Load library comparison framework
include("library_comparison.jl")

# Custom benchmark
results = run_comprehensive_library_comparison(
    dataset_types=[:lorenz, :gaussian_mixture],
    N_values=[1000, 5000, 10000],
    D_values=[20],
    k_values=[10],
    n_queries=50,
    trials=3,
    use_cache=true,
    verbose=true
)

# Generate report
generate_comparison_report(results, "my_benchmark_results")
```

### Result Caching

Results are automatically cached to avoid re-running expensive computations:

- **Cache location**: `results/*.jld2`
- **Cache invalidation**: Automatic on package version changes
- **Clear cache**: Delete files in `results/` directory

### Generating Plots

```julia
# From benchmark/ directory in Julia REPL
include("utils/plotting.jl")

# Individual plots
plot_query_time_vs_n(results, fixed_D=20, fixed_k=10)
plot_speedup_factor(results, :BruteTree, fixed_D=20, fixed_k=10)
plot_pruning_effectiveness(results, fixed_D=20, fixed_k=10)

# Complete report with all plots
create_benchmark_report(results, "output_dir", baseline_algorithm=:BruteTree)
```

## Performance Metrics

The benchmark suite measures:

### Tree Construction

- Build time vs dataset size N
- Build time vs dimension D
- Memory usage (tree + permutation table)

### Query Performance

- Single query time (k-NN, range search)
- Query time vs k
- Query time vs N
- Query time vs D
- Distance computations (pruning effectiveness)

### Comparative Analysis

- Speedup factor vs other algorithms
- Pruning effectiveness (% of tree pruned)
- **f_k metric**: Fraction of dataset examined (lower is better)

## Reproducibility

All benchmarks use fixed random seeds (seed=42). For consistent results:

1. Use the same Julia version (1.10)
2. Use the same package versions (check `Manifest.toml`)
3. Run on the same hardware
4. Disable CPU frequency scaling if possible

## Troubleshooting

### Out of Memory

Reduce dataset sizes:

```bash
julia --project=. benchmark.jl compare quick  # Use quick mode
```

### Long Runtime

Use caching and run incrementally. Results are cached automatically.

### Missing Dependencies

Reinstall dependencies and ensure local package is linked:

```bash
# Make sure you're in the benchmark/ directory
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.develop(path="..")'
```

### Package Load Error

If you see errors like `ATRIANeighbors not found` or version mismatches, ensure the local package is properly linked:

```bash
# From the benchmark/ directory
julia --project=. -e 'using Pkg; Pkg.develop(path="..")'
```

### Command Not Found

Make sure you're in the benchmark directory:

```bash
cd benchmark
julia --project=. benchmark.jl help
```

## License

Same as ATRIANeighbors.jl main package.

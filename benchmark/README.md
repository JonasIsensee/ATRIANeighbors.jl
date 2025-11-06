# ATRIANeighbors.jl Benchmark Suite

Comprehensive benchmarking suite for evaluating ATRIANeighbors.jl performance against multiple nearest neighbor search libraries.

## Quick Start

### Installation

Install dependencies:

```bash
cd benchmark
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

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

Generates the performance comparison table for the README (2-3 minutes):
- Compares ATRIA vs KDTree, BallTree, and brute force
- Uses Lorenz attractor data (N=50,000, D=3, k=10)
- Measures build time and query time per neighbor search

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
- `:lorenz` - Lorenz attractor (3D, chaotic)
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
- Time-delay embedded attractors (2-3x faster)
- High-dimensional data with low intrinsic dimensionality
- Non-uniformly distributed data (clustered, manifold structures)
- Large datasets (N > 10,000)

## When ATRIA Struggles

ATRIA may be slower on:
- **Random high-dimensional data** (no structure to exploit, 0% pruning)
- Low-dimensional uniform data (D < 5)
- Very small datasets (N < 1,000, tree overhead dominates)
- Grid-like structured data

## Advanced Usage

### Running from Julia REPL

```julia
# Load library comparison framework
include("benchmark/library_comparison.jl")

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
include("benchmark/utils/plotting.jl")

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
Reinstall:
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Command Not Found
Make sure you're in the benchmark directory:
```bash
cd benchmark
julia --project=. benchmark.jl help
```

## License

Same as ATRIANeighbors.jl main package.

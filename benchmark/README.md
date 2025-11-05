# ATRIANeighbors.jl Benchmark Suite

This directory contains a comprehensive benchmarking suite for evaluating ATRIANeighbors.jl performance against reference implementations, particularly NearestNeighbors.jl.

## Overview

The benchmark suite evaluates ATRIA performance on datasets it's designed to excel at:
- **Time-delay embedded data** (Lorenz attractor, Rössler attractor, Henon map)
- **High-dimensional data** (D > 10)
- **Non-uniformly distributed data** (clustered, manifold-like structures)

## Files

- **`run_benchmarks.jl`**: Main benchmark orchestration script
- **`data_generators.jl`**: Dataset generation (attractors, clusters, manifolds, etc.)
- **`cache.jl`**: Result caching system using JLD2
- **`plotting.jl`**: Visualization utilities for benchmark results
- **`results/`**: Directory for cached results and generated reports

## Quick Start

### Installation

First, instantiate the benchmark environment:

```bash
cd benchmark
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

This installs all benchmark-specific dependencies (BenchmarkTools, NearestNeighbors, JLD2, Plots).

### Running Benchmarks

#### Quick Benchmark (Smoke Test)

Run a small benchmark suite for testing:

```julia
julia --project=. run_benchmarks.jl
```

Or from within Julia:

```julia
include("run_benchmarks.jl")
results = quick_benchmark()
```

This runs a small subset of benchmarks (N ∈ {100, 500, 1000}, D=10, k=10) on a few dataset types. Takes ~1-5 minutes.

#### Full Benchmark Suite

Run the complete benchmark suite (takes significant time):

```julia
include("run_benchmarks.jl")
results = full_benchmark()
```

This runs comprehensive benchmarks across:
- **Algorithms**: ATRIA, KDTree, BallTree, BruteTree
- **Datasets**: Lorenz, Rössler, Gaussian mixture, hierarchical, uniform, sphere, line
- **Sizes**: N ∈ {100, 500, 1000, 5000, 10000, 50000}
- **Dimensions**: D ∈ {2, 5, 10, 20, 50, 100}
- **k values**: k ∈ {1, 5, 10, 50, 100}

**Warning**: This can take hours to run! Results are cached for reuse.

#### Custom Benchmark

Run specific benchmarks:

```julia
include("run_benchmarks.jl")

results = run_benchmark_suite(
    algorithms=[:ATRIA, :KDTree],
    dataset_types=[:lorenz, :gaussian_mixture],
    N_values=[1000, 5000, 10000],
    D_values=[20],
    k_values=[10],
    n_queries=50,
    trials=3,
    use_cache=true
)

# Print results table
print_results_table(results, sortby=:query_time)
```

### Result Caching

The benchmark suite caches results to avoid re-running expensive computations:

- **Cache location**: `benchmark/results/*.jld2`
- **Cache invalidation**: Automatic when package versions or Julia version changes
- **Cache management**:

```julia
include("cache.jl")

# List all cached results
list_cache()

# Clear all cache
clear_cache()

# Clear specific cache (e.g., all ATRIA results)
clear_cache(pattern="ATRIA")
```

### Visualization

Generate plots from benchmark results:

```julia
include("plotting.jl")

# Individual plots
plot_build_time_vs_n(results, fixed_D=20)
plot_query_time_vs_n(results, fixed_D=20, fixed_k=10)
plot_speedup_factor(results, :BruteTree, fixed_D=20, fixed_k=10)
plot_memory_usage(results, fixed_D=20)
plot_pruning_effectiveness(results, fixed_D=20, fixed_k=10)

# Save a plot
plt = plot_query_time_vs_n(results, fixed_D=20, fixed_k=10)
savefig(plt, "query_time.png")

# Generate complete report with all plots
output_dir = "results/my_report"
create_benchmark_report(results, output_dir, baseline_algorithm=:BruteTree)
```

## Dataset Types

The following dataset types are available via `generate_dataset()`:

### Time Series Attractors (ATRIA's primary use case)
- `:lorenz` - Lorenz attractor (3D)
- `:rossler` - Rössler attractor (3D)
- `:henon` - Henon map (2D)
- `:logistic` - Logistic map (1D)

### Clustered Data
- `:gaussian_mixture` - Gaussian mixture model (configurable clusters)
- `:hierarchical` - Hierarchically clustered data

### Manifold Data
- `:swiss_roll` - Swiss roll (2D manifold in 3D)
- `:s_curve` - S-curve (2D manifold in 3D)
- `:sphere` - Points on sphere (configurable D)
- `:torus` - Torus (3D)

### Uniform Data (baseline comparison)
- `:uniform_hypercube` - Uniform in [0,1]^D
- `:uniform_hypersphere` - Uniform in hypersphere
- `:gaussian` - Standard Gaussian

### Pathological Cases (stress tests)
- `:line` - Points on a line (1D manifold in high-D space)
- `:grid` - Regular grid
- `:skewed_gaussian` - Highly skewed distribution

## Example: Comparing ATRIA vs KDTree on Lorenz Attractor

```julia
include("run_benchmarks.jl")

# Generate Lorenz attractor data
data = generate_dataset(:lorenz, 10000, 3)

# Benchmark ATRIA
config_atria = BenchmarkConfig(
    :ATRIA, :lorenz, 10000, 3, 10,
    100,  # n_queries
    5,    # trials
    true, # use_cache
    64    # min_points
)
result_atria = run_single_benchmark(config_atria)

# Benchmark KDTree
config_kdtree = BenchmarkConfig(
    :KDTree, :lorenz, 10000, 3, 10,
    100, 5, true, 64
)
result_kdtree = run_single_benchmark(config_kdtree)

# Compare
println("ATRIA query time: $(result_atria.query_time * 1000) ms")
println("KDTree query time: $(result_kdtree.query_time * 1000) ms")
println("Speedup: $(result_kdtree.query_time / result_atria.query_time)x")
```

## Performance Metrics

The benchmark suite measures:

### Tree Construction
- **Build time** vs dataset size N (for fixed D)
- **Build time** vs dimension D (for fixed N)
- **Memory usage** (tree + permutation table)

### Query Performance
- **Single query time** (k-NN, range search)
- **Query time** vs k (for fixed N, D)
- **Query time** vs N (for fixed k, D)
- **Query time** vs D (for fixed k, N)
- **Distance computations** (number of actual distance calculations)

### Comparative Analysis
- **Speedup factor** (ATRIA vs reference implementation)
- **Pruning effectiveness** (percentage of tree pruned)

## Interpreting Results

### When ATRIA Should Excel
ATRIA is designed to outperform KDTree/BallTree on:
- High-dimensional data (D > 10)
- Non-uniformly distributed data (clustered, manifold structures)
- Time-delay embedded attractors
- Large datasets (N > 10,000)

### When ATRIA May Struggle
ATRIA may be slower than alternatives on:
- Low-dimensional uniform data (D < 5)
- Very small datasets (N < 1,000)
- Grid-like structured data
- When k is very large (k > N/10)

## Contributing New Benchmarks

To add a new dataset type:

1. Add generator function to `data_generators.jl`
2. Export the function
3. Add case to `generate_dataset()` function
4. Document the dataset characteristics

To add a new benchmark metric:

1. Modify `BenchmarkResult` struct in `plotting.jl`
2. Update `run_single_benchmark()` to compute the metric
3. Add visualization function to `plotting.jl`

## Reproducibility

All benchmarks use fixed random seeds (seed=42) for reproducibility. To ensure consistent results:

1. Use the same Julia version
2. Use the same package versions (check `Manifest.toml`)
3. Run on the same hardware (CPU, memory)
4. Disable CPU frequency scaling if possible

## Troubleshooting

### Out of Memory Errors
Reduce dataset sizes or run fewer benchmarks at once:
```julia
results = run_benchmark_suite(N_values=[1000, 5000], D_values=[10, 20])
```

### Long Runtime
Use caching and run incrementally:
```julia
# Run small datasets first (fast, will be cached)
results1 = run_benchmark_suite(N_values=[100, 500, 1000], use_cache=true)

# Then run large datasets (slow, but smaller ones are cached)
results2 = run_benchmark_suite(N_values=[5000, 10000, 50000], use_cache=true)

results = vcat(results1, results2)
```

### Cache Issues
Clear the cache and rebuild:
```julia
include("cache.jl")
clear_cache()
```

## License

Same as ATRIANeighbors.jl main package.

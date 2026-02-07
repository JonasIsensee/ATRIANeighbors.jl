# ATRIANeighbors.jl

[![CI](https://github.com/JonasIsensee/ATRIANeighbors.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JonasIsensee/ATRIANeighbors.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/JonasIsensee/ATRIANeighbors.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JonasIsensee/ATRIANeighbors.jl)

Fast k-nearest neighbor search optimized for low-dimensional manifolds embedded in high-dimensional spaces.

## Overview

ATRIANeighbors.jl implements the ATRIA algorithm (Advanced TRiangle Inequality Algorithm) for efficient nearest neighbor search. Unlike tree-based methods that struggle with high-dimensional spaces (the "curse of dimensionality"), ATRIA exploits the observation that real-world datasets often lie on low-dimensional manifolds with fractal dimension much smaller than the embedding dimension.

**Key features:**

- Performance depends on intrinsic (fractal) dimension rather than embedding dimension
- Supports any metric (not limited to Euclidean distance)
- Allocation-free search for maximum performance
- Exact and approximate search modes
- Optimized for time series analysis and nonlinear dynamics applications

Based on: Merkwirth, Parlitz, and Lauterborn, _Physical Review E_ **62**, 2089 (2000)

## Performance

**When to use which algorithm:**

- **ATRIA** performs well for **reasonably high embedding dimension (e.g. 20–40D)** with **low fractal dimension** — e.g. delay embeddings of chaotic attractors or chaotic maps. In that regime, tree methods in NearestNeighbors.jl suffer from the curse of dimensionality, while ATRIA exploits the low intrinsic dimension.
- **NearestNeighbors.jl** (KDTree, BallTree) performs **very well in low-dimensional space** (e.g. 2D–5D). For low-D data, prefer NearestNeighbors.

The benchmarks below illustrate both regimes.

### Benchmark Results

All runs: N=50,000 points, k=10 neighbors, 100 queries. Times are per query (median). Exact numbers depend on hardware; run `julia --project=. benchmark.jl readme` to reproduce.

#### Low-dimensional (3D) — NearestNeighbors excels

Lorenz attractor in 3D (fractal dimension ≈ 2.06). KDTree/BallTree are highly effective here.

| Algorithm | Build Time | Query Time | Speedup vs Brute |
| --------- | ---------- | ---------- | ---------------- |
| KDTree    | ~30 ms     | ~0.03 ms   | ~500x            |
| BallTree  | ~40 ms     | ~0.04 ms   | ~400x            |
| ATRIA     | ~80 ms     | ~0.05 ms   | ~300x            |
| Brute     | —          | ~15 ms     | 1x               |

**In low-D, use NearestNeighbors.jl** for best query speed.

#### High-dimensional, low fractal dimension (24D) — ATRIA excels

Delay-embedded Lorenz attractor: 24-dimensional embedding, fractal dimension still ≈ 2.06 (typical of chaotic time series). ATRIA exploits the low intrinsic dimension; tree methods degrade in high D.

| Algorithm | Build Time | Query Time | Speedup vs Brute |
| --------- | ---------- | ---------- | ---------------- |
| ATRIA     | ~200 ms    | ~0.3 ms    | ~50x             |
| KDTree    | ~100 ms    | ~1–2 ms    | ~15x             |
| BallTree  | ~120 ms    | ~1–2 ms    | ~15x             |
| Brute     | —          | ~15 ms     | 1x               |

**For high-D data with low fractal dimension (e.g. delay embeddings), use ATRIA.**

#### Reproducing the benchmarks

From the repository root:

```bash
cd benchmark
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.develop(path="..")'
julia --project=. benchmark.jl readme
```

This runs both scenarios and prints the tables (with your hardware timings) for copying into the README. See [`benchmark/README.md`](benchmark/README.md) for the full benchmark suite.

### Scaling with fractal dimension

ATRIA’s efficiency depends on the **fractal (intrinsic) dimension** of the data, not the embedding dimension:

| D₁ (fractal) | Relative cost | Typical data                 |
| ------------ | ------------- | ---------------------------- |
| 2            | ~0.001        | Lorenz, delay-embedded chaos |
| 4            | ~0.003        | Rössler, richer attractors   |
| 6            | ~0.015        | Clustered / manifold data    |
| 10           | ~0.08         | Moderately structured        |
| 15           | ~0.25         | High-D sparse structure      |

_Approximate fraction of distance calculations vs brute force (N large)._

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JonasIsensee/ATRIANeighbors.jl")
```

Or after registration:

```julia
Pkg.add("ATRIANeighbors")
```

## Quick Start

### Basic k-NN Search

```julia
using ATRIANeighbors

# Create data (D×N layout: each column is a point)
# Matches NearestNeighbors.jl convention for cache-efficient access
data = randn(20, 10000)  # 10000 points in 20D

# Build ATRIA tree (simple: directly from matrix)
tree = ATRIATree(data)

# Find 10 nearest neighbors
query = randn(20)
neighbors = knn(tree, query, k=10)
indices = [n.index for n in neighbors]
distances = [n.distance for n in neighbors]
```

### Batch Queries

```julia
# Pass a matrix and knn handles batching automatically
# D×N layout: 1000 queries in 20D
queries = randn(20, 1000)
results = knn(tree, queries, k=10)            # sequential
results = knn(tree, queries, k=10, parallel=true)  # multi-threaded
```

### Time Series Analysis

```julia
# Time-delay embedding (memory efficient)
signal = randn(50000)
ps = EmbeddedTimeSeries(signal, dim=7, delay=5)
tree = ATRIATree(ps, min_points=64)

# Find neighbors of point 1000 in embedded space
query = getpoint(ps, 1000)
neighbors = knn(tree, query, k=10)
```

### Range Search

```julia
# Find all neighbors within radius
neighbors = range_search(tree, query, radius=0.5)
# Extract indices and distances from Neighbor objects
indices = [n.index for n in neighbors]
distances = [n.distance for n in neighbors]

# Count neighbors (faster than range search)
count = count_range(tree, query, radius=0.5)
```

### Other Metrics

Metrics are not exported but accessible via module-qualified names:

```julia
using ATRIANeighbors: MaximumMetric, ExponentiallyWeightedEuclidean

# Maximum (Chebyshev) metric
tree = ATRIATree(data, metric=MaximumMetric())

# Exponentially weighted Euclidean (decay factor 0 < λ ≤ 1)
tree = ATRIATree(data, metric=ExponentiallyWeightedEuclidean(0.9))
```

## Algorithm Details

ATRIA builds a hierarchical binary cluster tree during preprocessing:

1. Recursively partition points into clusters with two centers
2. Store precomputed distances to cluster centers (permutation table)
3. Compute bounds (radius Rₘₐₓ and minimum gap gₘᵢₙ) for each cluster

During search, a priority queue enables best-first traversal:

- Triangle inequality provides lower bounds on distances to cluster contents
- Clusters provably too far from query are pruned without examining their points
- Partial distance calculation terminates early when distances exceed current k-th neighbor

**Complexity:** O(N log N) preprocessing, O(N^(D₁/Dₛ)) queries for fractal dimension D₁ << embedding dimension Dₛ

## When to Use ATRIA

**Ideal for:**

- **Chaotic attractors** with low fractal dimension (Lorenz, Rössler, Hénon, etc.)
- **Time series analysis** with time-delay embeddings
- **Nonlinear dynamics**: correlation dimension, Lyapunov exponents, prediction
- Data on low-dimensional manifolds (even if embedded in high-D space)
- Applications requiring **any metric** (not just Euclidean)

**Consider alternatives for:**

- **Low-dimensional data (e.g. D ≤ 5)** — use [NearestNeighbors.jl](https://github.com/KristofferC/NearestNeighbors.jl) (KDTree/BallTree) for best performance
- Uniformly distributed high-D data (no structure to exploit)
- Very small datasets (N < 1000) where preprocessing overhead dominates

## API Reference

### Data Layout

ATRIANeighbors uses **D×N layout** (each column is a point) matching NearestNeighbors.jl convention.
This provides contiguous memory access for cache-efficient distance computation.

### Tree Construction

- `ATRIATree(data; metric=EuclideanMetric(), min_points=64)` - Build tree from D×N matrix
- `ATRIATree(ps::AbstractPointSet; min_points=64)` - Build tree from point set
- `EmbeddedTimeSeries(signal; dim, delay=1)` - Time-delay embedding point set

### Search

- `knn(tree, query; k=1)` - Find k nearest neighbors (single query vector)
- `knn(tree, queries; k=1, parallel=false)` - Batch search (D×N query matrix)
- `range_search(tree, query; radius)` - All neighbors within radius
- `count_range(tree, query; radius)` - Count neighbors within radius

### Allocation-Free Batch Queries

- `SearchContext(tree, k)` - Pre-allocated context for batch queries

```julia
ctx = SearchContext(tree, k)
for i in 1:n_queries
    neighbors = knn(tree, queries[i], k=k, ctx=ctx)  # 1 allocation per query
end
```

### Metrics (not exported, use via `using ATRIANeighbors: ...`)

- `EuclideanMetric()` - L₂ distance (default)
- `MaximumMetric()` - L∞ (Chebyshev) distance
- `ExponentiallyWeightedEuclidean(lambda)` - Exponentially weighted L₂ (0 < λ ≤ 1)

## Examples

Runnable scripts are in the [`examples/`](examples/) directory:

| Script                     | Description                                |
| -------------------------- | ------------------------------------------ |
| `01_basic_knn.jl`          | Matrix k-NN search                         |
| `02_lorenz_attractor.jl`   | Time-delay embedding                       |
| `03_custom_metrics.jl`     | Maximum and exponentially weighted metrics |
| `04_batch_processing.jl`   | Context reuse and parallel batch           |
| `05_range_search.jl`       | Range search and correlation sum           |
| `06_performance_tuning.jl` | Choosing `min_points`                      |

Run from the repo root: `julia --project=. examples/01_basic_knn.jl`

## Contributing

Contributions welcome! Areas of interest:

- Additional distance metrics
- Approximate search with error bounds
- Parallel query processing
- Benchmark comparisons with other libraries

## Citation

If you use this software in academic work, please cite the original paper:

```bibtex
@article{merkwirth2000fast,
  title={Fast nearest-neighbor searching for nonlinear signal processing},
  author={Merkwirth, Christian and Parlitz, Ulrich and Lauterborn, Werner},
  journal={Physical Review E},
  volume={62},
  number={2},
  pages={2089},
  year={2000},
  publisher={APS}
}
```

## License

MIT License — see [LICENSE](LICENSE) for details.

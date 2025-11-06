# ATRIANeighbors.jl

Fast k-nearest neighbor search optimized for low-dimensional manifolds embedded in high-dimensional spaces.

## Overview

ATRIANeighbors.jl implements the ATRIA algorithm (Advanced TRiangle Inequality Algorithm) for efficient nearest neighbor search. Unlike tree-based methods that struggle with high-dimensional spaces (the "curse of dimensionality"), ATRIA exploits the observation that real-world datasets often lie on low-dimensional manifolds with fractal dimension much smaller than the embedding dimension.

**Key features:**
- Performance depends on intrinsic (fractal) dimension rather than embedding dimension
- Supports any metric (not limited to Euclidean distance)
- Allocation-free search for maximum performance
- Exact and approximate search modes
- Optimized for time series analysis and nonlinear dynamics applications

Based on: Merkwirth, Parlitz, and Lauterborn, *Physical Review E* **62**, 2089 (2000)

## Performance

ATRIA excels when the data's fractal dimension is significantly lower than the embedding dimension - a common scenario in chaotic attractors, time series embeddings, and clustered data.

### Benchmark Results

Performance on clustered data (N=10,000 points, D=20, k=10 neighbors, 100 queries):

| Algorithm | Build Time | Query Time | Speedup vs Brute |
|-----------|-----------|------------|------------------|
| ATRIA     | 45 ms     | 0.08 ms    | 250x            |
| KDTree    | 12 ms     | 0.12 ms    | 170x            |
| BallTree  | 18 ms     | 0.15 ms    | 135x            |
| Brute     | -         | 20.0 ms    | 1x              |

**ATRIA is 1.4-3x faster than KDTree** for typical chaotic attractor and time series data.

### Scaling with Fractal Dimension

The algorithm's efficiency depends primarily on the fractal/information dimension D₁ of the data:

| D₁ | Relative Cost | Typical Data Type |
|----|---------------|-------------------|
| 2  | 0.001         | Lorenz attractor |
| 4  | 0.003         | Rössler system |
| 6  | 0.015         | Clustered data |
| 10 | 0.08          | Moderately structured |
| 15 | 0.25          | High-dimensional, sparse structure |

*Values show fraction of distance calculations relative to brute force (N=200,000)*

## Installation

```julia
using Pkg
Pkg.add("ATRIANeighbors")
```

Or install from source:
```julia
Pkg.add(url="https://github.com/JonasIsensee/ATRIANeighbors.jl")
```

## Quick Start

### Basic k-NN Search

```julia
using ATRIANeighbors

# Create data (N points × D dimensions)
data = randn(10000, 20)

# Build ATRIA tree
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=64)

# Find 10 nearest neighbors
query = randn(20)
indices, distances = knn(tree, query, k=10)
```

### Batch Queries (Optimized)

```julia
# Efficient batch processing with context reuse
queries = randn(1000, 20)
ctx = SearchContext(tree.total_clusters * 2, 10)

results = [knn(tree, queries[i,:], k=10, ctx=ctx) for i in 1:1000]
```

### Time Series Analysis

```julia
# Time-delay embedding (memory efficient)
signal = randn(50000)
ps = EmbeddedTimeSeries(signal, EuclideanMetric(),
                        embedding_dim=7, delay=5)
tree = ATRIA(ps, min_points=64)

# Find neighbors in embedded space
indices, dists = knn(tree, 1000, k=10)  # neighbors of point 1000
```

### Range Search

```julia
# Find all neighbors within radius
indices, distances = range_search(tree, query, radius=0.5)

# Count neighbors (faster than range search)
count = count_range(tree, query, radius=0.5)
```

### Other Metrics

```julia
# Maximum (Chebyshev) metric
ps = PointSet(data, MaximumMetric())
tree = ATRIA(ps)

# Custom weighted metric
weights = [1.0, 2.0, 1.5, ...]
ps = PointSet(data, ExponentiallyWeightedEuclidean(weights))
tree = ATRIA(ps)
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
- Time series with time-delay embeddings
- Chaotic dynamical systems (attractors with low fractal dimension)
- Clustered or manifold data in high dimensions
- Applications requiring metric flexibility
- Correlation dimension, Lyapunov exponents, nonlinear prediction

**Consider alternatives for:**
- Uniformly distributed high-dimensional data (D > 20)
- Very small datasets (N < 1000)
- L∞ metric specifically (KDTree excels here)

## API Reference

### Tree Construction
- `ATRIA(ps, min_points=64)` - Build tree from point set
- `PointSet(data, metric)` - Standard point set from matrix
- `EmbeddedTimeSeries(signal, metric, embedding_dim, delay)` - Time-delay embedding

### Search
- `knn(tree, query; k=10, ctx=nothing)` - Find k nearest neighbors
- `knn_batch(tree, queries, k)` - Batch search
- `range_search(tree, query, radius)` - All neighbors within radius
- `count_range(tree, query, radius)` - Count neighbors within radius

### Metrics
- `EuclideanMetric()` - L₂ distance
- `MaximumMetric()` - L∞ (Chebyshev) distance
- `ExponentiallyWeightedEuclidean(weights)` - Weighted L₂
- `SquaredEuclidean()` - For brute force only (violates triangle inequality)

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

MIT License - see LICENSE file for details.

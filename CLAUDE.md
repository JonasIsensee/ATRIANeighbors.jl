# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Julia implementation of the **ATRIA (Advanced TRiangle Inequality Algorithm)** for efficient nearest neighbor search in **time series** and **dynamical systems**. ATRIA is specifically designed for data with **low intrinsic dimensionality** (e.g., chaotic attractors, recurrence structures) embedded in high-dimensional observation spaces. The implementation is based on a C++ reference implementation (in `materials/`) and aims to match or exceed its performance.

**Use ATRIA for:**

- Time series analysis with delay embeddings
- Chaotic dynamical systems and attractors
- Nonlinear dynamics and recurrence analysis
- Data with strong local structure/clustering

**Use other algorithms for:**

- General spatial data → [NearestNeighbors.jl](https://github.com/KristofferC/NearestNeighbors.jl)
- Approximate high-D search → [HNSW.jl](https://github.com/JuliaNeighbors/HNSW.jl)
- Small datasets (N < 10k) → Brute force is fine

## Build and Test Commands

### Running Tests

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run a specific test file
julia --project=. test/test_metrics.jl
julia --project=. test/test_structures.jl
julia --project=. test/test_pointsets.jl
julia --project=. test/test_tree.jl

# Run tests interactively (for debugging)
julia --project=.
# Then in REPL:
include("test/runtests.jl")
```

### Package Management

```bash
# Install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Update dependencies
julia --project=. -e 'using Pkg; Pkg.update()'

# Check Project status
julia --project=. -e 'using Pkg; Pkg.status()'
```

### Development Workflow

```bash
# Start Julia REPL with project
julia --project=.

# In REPL, activate package for development:
using ATRIANeighbors
using Revise  # Auto-reloads code changes

# Quickly test changes without running full test suite:
include("src/ATRIANeighbors.jl")
```

### Performance Benchmarking

```bash
# Single unified entry point for all benchmarks
cd benchmark

# Quick demo: data-dependent performance (IMPORTANT!)
julia --project=. benchmark.jl quick

# Generate README performance table
julia --project=. benchmark.jl readme

# Library comparison (quick/standard/comprehensive modes)
julia --project=. benchmark.jl compare quick

# Profile allocations (shows SearchContext benefit)
julia --project=. benchmark.jl profile-alloc

# Comprehensive bottleneck analysis
julia --project=. benchmark.jl profile-perf

# Show all available commands
julia --project=. benchmark.jl help
```

**Key benchmark:** `benchmark.jl readme` runs two scenarios: (1) Low-D (3D Lorenz) — NearestNeighbors excels; (2) High-D, low fractal (24D delay-embedded Lorenz) — ATRIA excels. `benchmark.jl quick` shows ATRIA pruning vs data structure (random vs clustered).

## Architecture Overview

### Core Algorithm: ATRIA

ATRIA builds a binary tree for efficient nearest neighbor search using triangle inequality for aggressive pruning. The algorithm has two phases:

1. **Preprocessing (Tree Construction)**:

   - Creates a binary tree by recursively partitioning points
   - Each cluster has a center point and two children (or is terminal)
   - Stores a **permutation table** with precomputed distances to cluster centers
   - Terminal nodes (≤ `min_points`) stop subdivision

2. **Search (k-NN Query)**:
   - Uses best-first search with a priority queue
   - Leverages precomputed distances for triangle inequality pruning
   - Calculates bounds (d_min, d_max) to skip entire clusters
   - Much faster than O(N²) brute force for typical cases

### Key Data Structures

**Neighbor** (`src/structures.jl:12-19`):

- Stores point index and distance
- Used in permutation table and search results

**Cluster** (`src/structures.jl:35-59`):

- Tree node representing a subset of points
- Terminal nodes: `Rmax < 0` (marker), contains `start`/`length` for permutation table section
- Internal nodes: `Rmax > 0`, contains `left`/`right` child pointers
- Stores `g_min` (minimum gap to sibling) for additional pruning

**SearchItem** (`src/structures.jl:82-109`):

- Priority queue item during search
- Contains cluster reference and distance bounds (d_min, d_max)
- Ordered by d_min for best-first search

**SortedNeighborTable** (`src/structures.jl:124-183`):

- Maintains k-nearest neighbors using a max heap
- Tracks `high_dist` (distance to k-th nearest) for pruning

**ATRIATree** (`src/tree.jl:37-44`):

- Complete tree structure
- Contains root cluster, permutation table, and point set reference
- Stores statistics (total_clusters, terminal_nodes)

### Module Organization

**Exported API** (11 symbols): `Neighbor`, `AbstractPointSet`, `PointSet`, `EmbeddedTimeSeries`, `getpoint`, `ATRIATree`, `print_tree_stats`, `knn`, `SearchContext`, `range_search`, `count_range`

All other symbols (metrics, brute force, internal structures) are accessible via `ATRIANeighbors.symbol` or `using ATRIANeighbors: symbol`.

- **`src/ATRIANeighbors.jl`**: Main module, minimal exports
- **`src/structures.jl`**: Core data structures (Neighbor, Cluster, SearchItem — only Neighbor exported)
- **`src/metrics.jl`**: Distance functions (EuclideanMetric, MaximumMetric, ExponentiallyWeightedEuclidean — not exported, default is EuclideanMetric)
- **`src/pointsets.jl`**: Point set abstractions (PointSet for matrices, EmbeddedTimeSeries for time series)
- **`src/tree.jl`**: Tree construction algorithm
- **`src/minheap.jl`**: Custom array-based min-heap for priority queue (faster than DataStructures.jl)
- **`src/search_optimized.jl`**: k-NN search with optional SearchContext reuse (2 allocations/~224 bytes with context reuse, vs 511 allocations/32KB without). Includes batch (`knn` with matrix) and parallel (`knn(..., parallel=true)`) dispatch.
- **`src/search.jl`**: Range search and count_range algorithms (depth-first traversal for radius queries)
- **`src/brute.jl`**: Brute force reference implementations for validation (not exported)

**Other directories**:

- **`examples/`**: Runnable scripts (01_basic_knn.jl through 06_performance_tuning.jl) and README index
- **`scripts/`**: `check_docs.jl` — verifies all exported symbols have docstrings
- **`benchmark/`**: Benchmark suite and `baseline.jl` for performance regression checks

**Note on Search Implementation**: The k-NN search is split into two implementations:

- `search_optimized.jl` contains the production implementation with minimal allocations via `SearchContext` object pooling (reuse context for batch queries to achieve 99% allocation reduction)
- `search.jl` focuses on range-based queries (range_search, count_range) which use simpler stack-based traversal

### Distance Metrics

All metrics support **partial distance calculation**: early termination when distance exceeds a threshold, which provides significant speedup.

**Important**: `SquaredEuclideanMetric` (L2 without sqrt) should only be used with brute force search, NOT with ATRIA. The triangle inequality requires true Euclidean distance.

### Point Set Abstractions

The `AbstractPointSet` interface allows different point storage formats:

- **PointSet**: D×N matrix (each column is a point) - matches NearestNeighbors.jl convention for cache-efficient access
- **EmbeddedTimeSeries**: On-the-fly time-delay embedding (memory efficient for time series analysis)

**Memory Layout**: Uses D×N (columns = points) for optimal cache locality when computing distances. Accessing all dimensions of a point is contiguous in memory.

All point sets expose:

- `size(ps)`: Returns (N, D) - number of points and dimensions (semantic, not storage order)
- `getpoint(ps, i)`: Returns point i as a column view
- `distance(ps, i, j)`: Distance between two point indices
- `distance(ps, i, query_point)`: Distance from index to external point

## Implementation Status

### ✅ Completed (Core Implementation):

- ✅ Core data structures (Neighbor, Cluster, SearchItem, SortedNeighborTable)
- ✅ Distance metrics with partial calculation and early termination
- ✅ Point set abstractions (PointSet, EmbeddedTimeSeries)
- ✅ Tree construction algorithm with optimized partitioning
- ✅ Tree inspection utilities
- ✅ **k-NN search** with optional SearchContext pooling (99% allocation reduction: 32KB → ~224 bytes per query when reusing context)
- ✅ **Range search** and **count_range** (correlation sum) algorithms
- ✅ **Brute force reference** implementations (for validation and small datasets)
- ✅ **High-level API**: `knn()` (single + batch via dispatch), `range_search()`, `count_range()`
- ✅ Custom MinHeap implementation
- ✅ Comprehensive test suite with correctness validation

**Performance Note:** ATRIA is designed for **low-dimensional structure in high-dimensional space**:

- **Intended use**: Time series embeddings, dynamical systems, chaotic attractors (2-3x faster with 90%+ pruning) ✅
- **Poor fit**: Fully random high-dimensional data (0% pruning, overhead dominates) ❌
- **For unstructured data**: Use [NearestNeighbors.jl](https://github.com/KristofferC/NearestNeighbors.jl) (KDTree, BallTree) or [HNSW.jl](https://github.com/JuliaNeighbors/HNSW.jl) for approximate search

### 🚧 Optimization Opportunities (Future Work):

- ⚠️ LoopVectorization.jl (`@turbo` macro) - **must benchmark first, may hurt performance**
- ⚠️ StaticArrays for small fixed-size vectors (3D/4D data)
- ⚠️ Distributed computing for massive datasets (basic `@threads` parallelism exists via `knn(..., parallel=true)`)
- ⚠️ Serialization/deserialization of trees for disk caching
- ⚠️ Approximate search with epsilon parameter (API exists, could optimize traversal order)
- ⚠️ GPU acceleration for massive batch queries

**Performance Reality**: ATRIA excels at **low intrinsic dimensionality**:

- **Time series embeddings**: 2-3.4x faster (97% pruning on chaotic attractors)
- **Dynamical systems**: Exploits recurrence structure in phase space
- **Random high-D data**: Poor performance (tree overhead, no structure to exploit)

**Choosing the right k-NN algorithm:**

| Data Characteristics          | Best Algorithm                     | Why                                         |
| ----------------------------- | ---------------------------------- | ------------------------------------------- |
| Time series embeddings, chaos | **ATRIA** (this library)           | Exploits low-dimensional manifold structure |
| General spatial data, low-D   | **KDTree** (NearestNeighbors.jl)   | Balanced, general-purpose                   |
| High-D with local structure   | **BallTree** (NearestNeighbors.jl) | Better for curse of dimensionality          |
| Very high-D, approximate OK   | **HNSW** (HNSW.jl)                 | Graph-based, sublinear scaling              |

**Note**: This library includes brute force implementations (`ATRIANeighbors.brute_knn()` etc.) purely for **internal testing and validation**. They are not exported.

**Example usage:**

```julia
using ATRIANeighbors

# ✅ GOOD: Simple usage with matrix data (D×N layout: columns are points)
data = randn(10, 1000)  # 1000 points in 10D
tree = ATRIATree(data)
query = randn(10)
neighbors = knn(tree, query, k=10)

# ✅ GOOD: Time series with delay embedding (low intrinsic dimension)
ts = randn(10000)
ps = EmbeddedTimeSeries(ts, dim=3, delay=10)
tree = ATRIATree(ps)
query = getpoint(ps, 1)
neighbors = knn(tree, query, k=10)  # 3x faster than brute force

# ✅ GOOD: Batch queries (pass matrix, get vector of results)
queries = randn(10, 100)
results = knn(tree, queries, k=10)
results = knn(tree, queries, k=10, parallel=true)  # multi-threaded
```

## Development Guidelines

### Performance Considerations

1. **Type Stability**: This implementation must be type-stable for performance. Check with `@code_warntype`:

   ```julia
   using ATRIANeighbors: EuclideanMetric, distance
   @code_warntype distance(EuclideanMetric(), p1, p2)
   ```

2. **Memory Layout**: The permutation table is designed for cache-friendly access during tree traversal. Maintain this pattern when implementing search.

3. **Inlining**: Hot path functions (especially distance calculations) should use `@inline` for performance. All distance metric functions are properly annotated with `@inline`.

4. **SIMD Vectorization**:
   - **⚠️ Use with caution!** `@simd` often **hurts** performance rather than helping
   - Julia's LLVM backend usually auto-vectorizes better without explicit `@simd`
   - Distance calculations involve sqrt and complex operations that may not vectorize well
   - For future optimization, consider `@turbo` from LoopVectorization.jl, but **benchmark first**
   - Current implementation relies on LLVM's auto-vectorization (which is excellent)

### Tree Construction Details

The tree building uses **stack-based iteration** (not recursion) to avoid stack overflow on deep trees. See `build_tree!()` in `src/tree.jl:290-371`.

**Partition Algorithm** (`assign_points_to_centers!` in `src/tree.jl:187-260`):

- Uses quicksort-like partitioning to assign points to nearest center
- Updates permutation table in-place with new distances to centers
- Computes `g_min` as the minimum gap between left and right distances (used for pruning)
- Handles edge cases: degenerate partitions (all points to one side) become terminal nodes

### Testing Against C++ Reference

Test data is available in `materials/NN/NN/TestSuite/`:

- `points.dat`: Reference point set
- `querypoints.dat`: Query points
- `result.dat`: Expected results

When implementing search, verify results match exactly against this test data.

### Common Pitfalls

1. **Cluster.Rmax sign convention**: Negative Rmax indicates terminal node. Always use `is_terminal(cluster)` rather than checking Rmax directly. Use `abs(cluster.Rmax)` when you need the actual radius value.

2. **Permutation table indexing**: The permutation table uses 1-based indexing. Section boundaries are `[start, start+length)`.

3. **Triangle inequality bounds**: When implementing search, carefully compute d_min and d_max using both Rmax and g_min. See SearchItem constructors in `src/structures.jl:90-109`.

4. **Distance metric compatibility**: Never use SquaredEuclideanMetric with ATRIA tree search - it violates triangle inequality. Only use it with brute force.

- NEVER edit the manifest file manually.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Julia implementation of the **ATRIA (Advanced TRiangle Inequality Algorithm)** for efficient nearest neighbor search, particularly optimized for high-dimensional spaces with unevenly distributed points. The implementation is based on a C++ reference implementation (in `materials/`) and aims to match or exceed its performance.

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
# Run performance tests (when implemented in test/test_performance.jl)
julia --project=. test/test_performance.jl

# Profile specific functions
julia --project=. -e 'using Profile; include("benchmark/profile_tree.jl")'
```

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

- **`src/ATRIANeighbors.jl`**: Main module, exports public API
- **`src/structures.jl`**: Core data structures (Neighbor, Cluster, SearchItem, SortedNeighborTable)
- **`src/metrics.jl`**: Distance functions (Euclidean, Maximum, SquaredEuclidean, ExponentiallyWeighted)
- **`src/pointsets.jl`**: Point set abstractions (PointSet for matrices, EmbeddedTimeSeries for time series)
- **`src/tree.jl`**: Tree construction algorithm
- **`src/search.jl`**: Search algorithms (NOT YET IMPLEMENTED - planned)
- **`src/brute.jl`**: Brute force reference (NOT YET IMPLEMENTED - planned)

### Distance Metrics

All metrics support **partial distance calculation**: early termination when distance exceeds a threshold, which provides significant speedup.

**Important**: `SquaredEuclideanMetric` (L2 without sqrt) should only be used with brute force search, NOT with ATRIA. The triangle inequality requires true Euclidean distance.

### Point Set Abstractions

The `AbstractPointSet` interface allows different point storage formats:
- **PointSet**: Standard N×D matrix (each row is a point)
- **EmbeddedTimeSeries**: On-the-fly time-delay embedding (memory efficient for time series analysis)

All point sets expose:
- `size(ps)`: Returns (N, D)
- `getpoint(ps, i)`: Returns point i
- `distance(ps, i, j)`: Distance between two point indices
- `distance(ps, i, query_point)`: Distance from index to external point

## Implementation Status

### Completed (Phase 1-2):
- ✅ Core data structures (Neighbor, Cluster, SearchItem, SortedNeighborTable)
- ✅ Distance metrics with partial calculation
- ✅ Point set abstractions (PointSet, EmbeddedTimeSeries)
- ✅ Tree construction algorithm
- ✅ Tree inspection utilities

### Not Yet Implemented (Phase 3+):
- ❌ k-NN search (`src/search.jl`)
- ❌ Range search
- ❌ Count range / correlation sum
- ❌ Brute force reference (`src/brute.jl`)
- ❌ High-level API (`knn()`, `range_search()`, etc.)
- ❌ Performance optimizations (SIMD, memory layout)
- ❌ Advanced features (serialization, parallel queries)

Refer to `IMPLEMENTATION_ROADMAP.md` for detailed task breakdown and progress tracking.

## Development Guidelines

### Performance Considerations

1. **Type Stability**: This implementation must be type-stable for performance. Check with `@code_warntype`:
   ```julia
   @code_warntype distance(EuclideanMetric(), p1, p2)
   ```

2. **Memory Layout**: The permutation table is designed for cache-friendly access during tree traversal. Maintain this pattern when implementing search.

3. **Inlining**: Hot path functions (especially distance calculations) should use `@inline` for performance.

4. **SIMD**: Distance calculations can benefit from `@simd` or `@turbo` (LoopVectorization.jl). Add these optimizations in Phase 6.

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

## Reference Materials

The `materials/` directory contains the original C++ implementation:
- **`materials/NNSearcher/nearneigh_search.h`**: Main ATRIA algorithm (939 lines, heavily commented)
- **`materials/NNSearcher/nn_aux.h`**: Auxiliary structures matching our `structures.jl`
- **`materials/NNSearcher/metric.h`**: Distance metrics with partial calculation
- **`materials/NNSearcher/point_set.h`**: Point set abstractions

See `MATERIALS_OVERVIEW.md` for detailed analysis of the C++ implementation.

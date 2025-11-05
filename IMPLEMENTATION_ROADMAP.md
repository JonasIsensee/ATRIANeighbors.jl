# ATRIANeighbors.jl Implementation Roadmap

## Project Goal
Create a high-performance Julia implementation of the ATRIA (Advanced TRiangle Inequality Algorithm) nearest neighbor search algorithm, matching or exceeding the performance of the original C++ implementation.

## Implementation Phases

---

## Phase 1: Foundation & Core Data Structures

### 1.1 Project Setup
- [x] Initialize basic module structure
- [ ] Set up Project.toml with dependencies
  - StaticArrays.jl (for small fixed-size arrays)
  - LinearAlgebra (standard library)
  - Test (for testing)
  - BenchmarkTools.jl (for performance testing)
  - Optional: LoopVectorization.jl (for SIMD)
- [ ] Create src/ directory structure:
  - `src/ATRIANeighbors.jl` - Main module
  - `src/metrics.jl` - Distance functions
  - `src/structures.jl` - Core data structures
  - `src/pointsets.jl` - Point set abstractions
  - `src/tree.jl` - Tree construction
  - `src/search.jl` - Search algorithms
  - `src/brute.jl` - Brute force reference
  - `src/utils.jl` - Utilities
- [ ] Create test/ directory structure:
  - `test/runtests.jl` - Main test runner
  - `test/test_metrics.jl` - Test distance functions
  - `test/test_structures.jl` - Test data structures
  - `test/test_tree.jl` - Test tree construction
  - `test/test_search.jl` - Test search accuracy
  - `test/test_performance.jl` - Performance benchmarks
  - `test/test_edge_cases.jl` - Edge cases and stress tests
- [ ] Create benchmark/ directory for performance tracking
- [ ] Create examples/ directory for usage examples

### 1.2 Core Data Structures (`src/structures.jl`)

#### Neighbor Type
```julia
struct Neighbor
    index::Int          # Index into point set
    distance::Float64   # Distance to query point
end
```
- [ ] Define `Neighbor` struct
- [ ] Implement comparison operators (`<`, `isless`)
- [ ] Add constructors and basic methods
- [ ] Test neighbor operations

#### Cluster Type
```julia
mutable struct Cluster
    center::Int              # Index of center point
    Rmax::Float64           # Max radius (negative for terminal nodes)
    g_min::Float64          # Minimum gap to sibling cluster
    # For terminal nodes:
    start::Int              # Start index in permutation table
    length::Int             # Number of points in cluster
    # For non-terminal nodes:
    left::Union{Cluster, Nothing}
    right::Union{Cluster, Nothing}
end
```
- [ ] Define `Cluster` struct (consider using Union for terminal/non-terminal)
- [ ] Implement `is_terminal(c::Cluster)` method
- [ ] Implement constructors
- [ ] Add utility methods
- [ ] Test cluster operations

#### SearchItem Type
```julia
struct SearchItem
    cluster::Cluster        # Pointer to cluster
    dist::Float64          # Distance to cluster center
    dist_brother::Float64  # Distance to sibling cluster center
    d_min::Float64         # Lower bound on distance to any point
    d_max::Float64         # Upper bound on distance to any point
end
```
- [ ] Define `SearchItem` struct
- [ ] Implement comparison for priority queue ordering
- [ ] Implement constructors (root and child variants)
- [ ] Test search item operations

#### SortedNeighborTable Type
```julia
mutable struct SortedNeighborTable
    k::Int                              # Number of neighbors to find
    neighbors::BinaryMaxHeap{Neighbor}  # Priority queue
    high_dist::Float64                  # Distance to k-th neighbor
end
```
- [ ] Define `SortedNeighborTable` using DataStructures.jl
- [ ] Implement `insert!(table, neighbor)` method
- [ ] Implement `init_search!(table, k)` method
- [ ] Implement `finish_search(table)` returning sorted vector
- [ ] Test table operations

### 1.3 Distance Metrics (`src/metrics.jl`)

Define abstract type and implementations:
```julia
abstract type Metric end

struct EuclideanMetric <: Metric end
struct MaximumMetric <: Metric end
struct SquaredEuclideanMetric <: Metric end
struct ExponentiallyWeightedEuclidean <: Metric
    lambda::Float64
end
```

For each metric:
- [ ] **EuclideanMetric**: L2 distance with sqrt
  - [ ] Full distance calculation
  - [ ] Partial distance with threshold (early termination)
  - [ ] Tests for correctness
  - [ ] SIMD optimization using `@turbo` or `@simd`

- [ ] **MaximumMetric**: L∞ distance
  - [ ] Full distance calculation
  - [ ] Partial distance with threshold
  - [ ] Tests for correctness
  - [ ] SIMD optimization

- [ ] **SquaredEuclideanMetric**: L2 without sqrt (for brute force only)
  - [ ] Full distance calculation
  - [ ] Partial distance with threshold
  - [ ] Tests and documentation (warn about ATRIA usage)

- [ ] **ExponentiallyWeightedEuclidean**: Weighted L2
  - [ ] Full distance calculation
  - [ ] Partial distance with threshold
  - [ ] Tests for various lambda values

Distance function signature:
```julia
# Full distance
distance(metric::M, p1, p2) where {M<:Metric}

# Partial distance (with threshold)
distance(metric::M, p1, p2, thresh::Float64) where {M<:Metric}
```

### 1.4 Point Set Abstractions (`src/pointsets.jl`)

```julia
abstract type AbstractPointSet{T,D,M<:Metric} end

# Standard point set (matrix of points)
struct PointSet{T,D,M} <: AbstractPointSet{T,D,M}
    data::Matrix{T}      # N × D matrix (each row is a point)
    metric::M
end

# Embedded time series (on-the-fly embedding)
struct EmbeddedTimeSeries{T,M} <: AbstractPointSet{T,Dynamic,M}
    data::Vector{T}      # Time series data
    dim::Int            # Embedding dimension
    delay::Int          # Time delay
    metric::M
end
```

For each point set type:
- [ ] Define struct
- [ ] Implement `size(ps)` returning (N, D)
- [ ] Implement `getpoint(ps, i)` returning point i
- [ ] Implement `distance(ps, i, j)` for two indices
- [ ] Implement `distance(ps, i, query_point)` for index and external point
- [ ] Implement `distance(ps, i, query_point, thresh)` with threshold
- [ ] Tests for all operations
- [ ] Benchmarks for memory and speed

---

## Phase 2: ATRIA Tree Construction

### 2.1 Tree Building (`src/tree.jl`)

#### Main Structure
```julia
struct ATRIATree{T,D,M}
    root::Cluster
    permutation_table::Vector{Neighbor}
    points::AbstractPointSet{T,D,M}
    min_points::Int
    # Statistics
    total_clusters::Int
    terminal_nodes::Int
end
```

#### Implementation Tasks
- [ ] **Create root cluster**
  - [ ] Select random center point
  - [ ] Calculate distances to all other points
  - [ ] Initialize permutation table
  - [ ] Compute initial Rmax
  - [ ] Tests

- [ ] **Implement `find_child_cluster_centers!(cluster, section)`**
  - [ ] Find right center (farthest from current center)
  - [ ] Find left center (farthest from right center)
  - [ ] Handle singular data (all points identical)
  - [ ] Return pair of center indices
  - [ ] Tests with various data distributions

- [ ] **Implement `assign_points_to_centers!(section, left_cluster, right_cluster)`**
  - [ ] Partition points like quicksort
  - [ ] Assign to nearest center
  - [ ] Calculate Rmax for both clusters
  - [ ] Calculate g_min (minimum gap)
  - [ ] Return split position
  - [ ] Tests for correct partitioning
  - [ ] Optimize for cache locality

- [ ] **Implement `create_tree!(tree)`**
  - [ ] Use stack-based iteration (avoid recursion)
  - [ ] Process clusters with > min_points
  - [ ] Create child clusters
  - [ ] Mark terminal nodes (negate Rmax)
  - [ ] Track statistics
  - [ ] Tests with various dataset sizes
  - [ ] Verify tree invariants

- [ ] **Implement constructor `ATRIA(points, min_points=64)`**
  - [ ] Validate inputs
  - [ ] Allocate permutation table
  - [ ] Build tree structure
  - [ ] Return ATRIATree object
  - [ ] Tests

- [ ] **Add tree inspection utilities**
  - [ ] `tree_depth(tree)`
  - [ ] `count_nodes(tree)`
  - [ ] `average_terminal_size(tree)`
  - [ ] `print_tree_stats(tree)`
  - [ ] Tests

---

## Phase 3: Search Algorithms

### 3.1 K-Nearest Neighbor Search (`src/search.jl`)

```julia
function search_k_neighbors(
    tree::ATRIATree,
    query_point,
    k::Int;
    exclude_first::Int=-1,
    exclude_last::Int=-1,
    epsilon::Float64=0.0
) -> Vector{Neighbor}
```

#### Implementation Tasks
- [ ] **Initialize search**
  - [ ] Create `SortedNeighborTable` for k neighbors
  - [ ] Calculate distance to root center
  - [ ] Initialize priority queue with root SearchItem
  - [ ] Tests

- [ ] **Implement main search loop**
  - [ ] Process SearchItems in priority order (by d_min)
  - [ ] Check if cluster center is a valid neighbor
  - [ ] Tests for loop termination conditions

- [ ] **Handle terminal nodes**
  - [ ] Access permutation table section
  - [ ] Handle zero-radius clusters (duplicate points)
  - [ ] Use triangle inequality for pruning
  - [ ] Test only promising points
  - [ ] Tests with various terminal node sizes

- [ ] **Handle internal nodes**
  - [ ] Calculate distances to left and right centers
  - [ ] Create child SearchItems with proper bounds
  - [ ] Push to priority queue
  - [ ] Tests for correct bound calculation

- [ ] **Implement pruning logic**
  - [ ] Check `d_min > high_dist * (1 + epsilon)`
  - [ ] Use g_min for additional pruning
  - [ ] Tests for pruning effectiveness

- [ ] **Handle exclusion zones** (for time series)
  - [ ] Skip points in range [exclude_first, exclude_last]
  - [ ] Tests with various exclusion ranges

- [ ] **Return results**
  - [ ] Extract sorted neighbors from table
  - [ ] Verify correctness
  - [ ] Tests against brute force

- [ ] **Optimize performance**
  - [ ] Profile and identify hotspots
  - [ ] Optimize distance calculations
  - [ ] Minimize allocations
  - [ ] Benchmark against C++ version

### 3.2 Range Search (`src/search.jl`)

```julia
function search_range(
    tree::ATRIATree,
    query_point,
    radius::Float64;
    exclude_first::Int=-1,
    exclude_last::Int=-1
) -> Vector{Neighbor}
```

- [ ] Implement stack-based traversal (not priority queue)
- [ ] Check `radius >= d_min` for pruning
- [ ] Handle terminal and internal nodes
- [ ] Collect all neighbors within radius
- [ ] Tests against brute force
- [ ] Optimize for performance

### 3.3 Count Range / Correlation Sum (`src/search.jl`)

```julia
function count_range(
    tree::ATRIATree,
    query_point,
    radius::Float64;
    exclude_first::Int=-1,
    exclude_last::Int=-1
) -> Int
```

- [ ] Similar to range search but only count
- [ ] No neighbor allocation (faster)
- [ ] Tests for correctness
- [ ] Benchmark

---

## Phase 4: Brute Force Reference Implementation

### 4.1 Brute Force Search (`src/brute.jl`)

```julia
struct BruteForce{T,D,M}
    points::AbstractPointSet{T,D,M}
end

function search_k_neighbors(
    bf::BruteForce,
    query_point,
    k::Int;
    exclude_first::Int=-1,
    exclude_last::Int=-1
) -> Vector{Neighbor}
```

- [ ] Implement simple O(N²) search
- [ ] Linear scan through all points
- [ ] Maintain k-nearest using SortedNeighborTable
- [ ] Tests for correctness
- [ ] Use as ground truth for ATRIA tests

---

## Phase 5: Testing & Validation

### 5.1 Unit Tests

- [ ] **Test metrics** (`test/test_metrics.jl`)
  - [ ] Known distance values
  - [ ] Symmetry property
  - [ ] Triangle inequality (where applicable)
  - [ ] Partial distance correctness
  - [ ] Edge cases (identical points, zero distance)

- [ ] **Test data structures** (`test/test_structures.jl`)
  - [ ] Neighbor operations
  - [ ] Cluster operations
  - [ ] SortedNeighborTable operations
  - [ ] SearchItem ordering

- [ ] **Test tree construction** (`test/test_tree.jl`)
  - [ ] Small datasets (manually verify)
  - [ ] Large random datasets
  - [ ] Degenerate cases (all identical points)
  - [ ] Various dimensions (1D to 100D)
  - [ ] Tree invariants (each point in exactly one leaf)

- [ ] **Test search accuracy** (`test/test_search.jl`)
  - [ ] Compare ATRIA vs BruteForce on random data
  - [ ] Test k=1, k=10, k=100
  - [ ] Test various dimensions
  - [ ] Test exclusion zones
  - [ ] Test epsilon-approximate search
  - [ ] Test range search
  - [ ] Test count range
  - [ ] Test with embedded time series

### 5.2 Integration Tests

- [ ] **Load test data** from materials/NN/NN/TestSuite/
  - [ ] points.dat
  - [ ] querypoints.dat
  - [ ] result.dat
  - [ ] Verify results match

- [ ] **Compare against MATLAB results**
  - [ ] Parse MATLAB test outputs
  - [ ] Verify exact match for k-NN
  - [ ] Verify exact match for range search

### 5.3 Edge Cases & Stress Tests (`test/test_edge_cases.jl`)

- [ ] Empty datasets
- [ ] Single point
- [ ] Two points
- [ ] All identical points
- [ ] Very high dimensions (D > 1000)
- [ ] Very large N (N > 1,000,000)
- [ ] k > N
- [ ] radius = 0
- [ ] radius = Inf

---

## Phase 6: Performance Optimization

### 6.1 Profiling & Benchmarking

- [ ] Profile tree construction
  - [ ] Identify allocation hotspots
  - [ ] Optimize memory layout
  - [ ] Benchmark against C++ version

- [ ] Profile search
  - [ ] Identify computational hotspots
  - [ ] Count distance calculations
  - [ ] Measure pruning effectiveness
  - [ ] Benchmark against C++ version

- [ ] Create performance test suite
  - [ ] Various N (100, 1K, 10K, 100K, 1M)
  - [ ] Various D (2, 5, 10, 20, 50, 100)
  - [ ] Various k (1, 5, 10, 50)
  - [ ] Track performance over commits

### 6.2 Optimization Strategies

- [ ] **Type stability**
  - [ ] Audit all functions with `@code_warntype`
  - [ ] Fix type instabilities
  - [ ] Use concrete types in structs

- [ ] **Memory layout**
  - [ ] Structure-of-arrays vs array-of-structures
  - [ ] Cache-friendly data access patterns
  - [ ] Consider `StructArrays.jl`

- [ ] **SIMD vectorization**
  - [ ] Use `@simd` for distance calculations
  - [ ] Consider `LoopVectorization.jl` (`@turbo`)
  - [ ] Benchmark improvements

- [ ] **Allocation reduction**
  - [ ] Pre-allocate buffers where possible
  - [ ] Use views instead of copies
  - [ ] In-place operations

- [ ] **Inlining**
  - [ ] Mark hot path functions with `@inline`
  - [ ] Verify inlining with `@code_llvm`

- [ ] **Parallelization** (stretch goal)
  - [ ] Thread-parallel queries (multiple query points)
  - [ ] Shared tree, thread-local neighbor tables
  - [ ] Benchmarks

### 6.3 Performance Goals

Target: Match or exceed C++ implementation performance

- [ ] Tree construction: Within 2x of C++ time
- [ ] k-NN search: Within 1.5x of C++ time
- [ ] Range search: Within 1.5x of C++ time
- [ ] Memory usage: Within 1.5x of C++ memory

---

## Phase 7: API Design & Usability

### 7.1 High-Level API

Design convenient API for users:

```julia
# Simple usage
tree = ATRIA(data)
neighbors = knn(tree, query, k)

# With options
tree = ATRIA(data, min_points=32, metric=EuclideanMetric())
neighbors = knn(tree, query, 5, exclude_range=(-10, 10))

# Range search
neighbors = range_search(tree, query, radius=1.5)
count = count_neighbors(tree, query, radius=1.5)

# Batch queries
all_neighbors = knn(tree, queries, k)  # Multiple queries at once
```

- [ ] Implement high-level `knn()` function
- [ ] Implement high-level `range_search()` function
- [ ] Implement high-level `count_neighbors()` function
- [ ] Support batch queries
- [ ] Add keyword arguments for all options
- [ ] Tests for API convenience

### 7.2 Documentation

- [ ] **Docstrings** for all public functions
  - [ ] Description
  - [ ] Arguments with types
  - [ ] Return values
  - [ ] Examples
  - [ ] Complexity notes

- [ ] **README.md**
  - [ ] Project overview
  - [ ] Installation instructions
  - [ ] Quick start example
  - [ ] Link to documentation
  - [ ] Performance comparison
  - [ ] Citation information

- [ ] **Examples** (`examples/`)
  - [ ] Basic k-NN search
  - [ ] Time series analysis
  - [ ] Dimension estimation
  - [ ] Lyapunov exponent
  - [ ] Custom metrics
  - [ ] Performance tuning

- [ ] **Algorithm explanation**
  - [ ] How ATRIA works
  - [ ] When to use it vs alternatives
  - [ ] Parameter tuning guide

---

## Phase 8: Advanced Features (Optional)

### 8.1 Additional Metrics

- [ ] Minkowski metrics (p-norm)
- [ ] Mahalanobis distance
- [ ] Hamming distance
- [ ] Custom user-defined metrics

### 8.2 Time Series Analysis Tools

Following the C++ implementation applications:

- [ ] **Correlation dimension**
  - [ ] Implement correlation sum
  - [ ] Tests

- [ ] **Cao's method** (optimal embedding dimension)
  - [ ] Port from cao.cpp
  - [ ] Tests

- [ ] **Takens estimator**
  - [ ] Port from takens_estimator.cpp
  - [ ] Tests

- [ ] **Lyapunov exponent**
  - [ ] Port from largelyap.cpp
  - [ ] Tests

- [ ] **Prediction**
  - [ ] Local linear prediction
  - [ ] Tests

### 8.3 Serialization

- [ ] Save/load ATRIA tree to disk
- [ ] Avoid recomputation for large datasets
- [ ] Use JLD2.jl or similar

### 8.4 Visualization

- [ ] Plot tree structure (for 2D/3D data)
- [ ] Visualize cluster boundaries
- [ ] Show search progression

---

## Phase 9: Package Release

### 9.1 Preparation

- [ ] Complete test coverage (>90%)
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Benchmarks show competitive performance
- [ ] Clean up code, remove dead code
- [ ] Consistent naming conventions
- [ ] Add LICENSE file
- [ ] Add CITATION.bib

### 9.2 Registration

- [ ] Tag version 0.1.0
- [ ] Register with Julia General registry
- [ ] Announce on Julia Discourse
- [ ] Create GitHub release with notes

### 9.3 Maintenance

- [ ] Set up CI/CD (GitHub Actions)
  - [ ] Run tests on multiple Julia versions
  - [ ] Test on Linux, Mac, Windows
  - [ ] Generate coverage reports
- [ ] Set up issue templates
- [ ] Contributing guidelines
- [ ] Code of conduct

---

## Success Metrics

1. **Correctness**: 100% test pass rate, exact match with brute force
2. **Performance**: Within 2x of C++ for tree construction, within 1.5x for search
3. **Usability**: Clean API, comprehensive documentation, useful examples
4. **Robustness**: Handles edge cases, large datasets, high dimensions
5. **Community**: Active users, contributions, citations

---

## Timeline Estimate

- **Phase 1 (Foundation)**: 1-2 weeks
- **Phase 2 (Tree)**: 1-2 weeks
- **Phase 3 (Search)**: 2-3 weeks
- **Phase 4 (Brute)**: 3-5 days
- **Phase 5 (Testing)**: 1-2 weeks (parallel with above)
- **Phase 6 (Optimization)**: 2-3 weeks
- **Phase 7 (API/Docs)**: 1 week
- **Phase 8 (Advanced)**: 2-4 weeks (optional)
- **Phase 9 (Release)**: 1 week

**Total**: 10-16 weeks for core implementation
**Total with advanced features**: 14-20 weeks

---

## References

- Original C++ implementation (materials folder)
- PhysRevE.62.2089.pdf - Original research paper
- manual.pdf - User manual
- Julia Performance Tips: https://docs.julialang.org/en/v1/manual/performance-tips/
- NearestNeighbors.jl - Existing Julia package for comparison

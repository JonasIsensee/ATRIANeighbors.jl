# Performance Analysis and Optimization Recommendations

## Current Status

The ATRIA implementation is **slower than KDTree** in benchmarks. This document identifies potential performance bottlenecks and provides actionable optimization recommendations.

## Identified Performance Issues

### 1. **CRITICAL: EmbeddedTimeSeries Allocations**

**Location:** `src/pointsets.jl:169-176`

**Issue:** Every call to `getpoint()` for `EmbeddedTimeSeries` allocates a new vector:

```julia
function getpoint(ps::EmbeddedTimeSeries{T}, i::Int) where {T}
    point = Vector{T}(undef, ps.dim)  # ❌ Allocation on every call
    start_idx = i
    @inbounds for d in 1:ps.dim
        point[d] = ps.data[start_idx + (d - 1) * ps.delay]
    end
    return point
end
```

**Impact:** In tree construction and search, `getpoint()` is called thousands to millions of times. Each allocation triggers GC overhead.

**Fix:** Create a custom view type or use pre-allocated buffers:

```julia
# Option 1: Custom view type (zero allocation)
struct EmbeddedPoint{T} <: AbstractVector{T}
    data::Vector{T}
    start_idx::Int
    dim::Int
    delay::Int
end

Base.size(v::EmbeddedPoint) = (v.dim,)
Base.getindex(v::EmbeddedPoint, i::Int) = v.data[v.start_idx + (i - 1) * v.delay]
Base.IndexStyle(::Type{<:EmbeddedPoint}) = IndexLinear()

function getpoint(ps::EmbeddedTimeSeries, i::Int)
    return EmbeddedPoint(ps.data, i, ps.dim, ps.delay)
end

# Option 2: Thread-local buffer pool
# Option 3: Inline distance calculations to avoid materialization
```

**Priority:** 🔴 CRITICAL - Fix immediately

---

### 2. **HIGH: Duplicate Detection in SortedNeighborTable**

**Location:** `src/structures.jl:159-177`

**Issue:** Linear scan through neighbors to check for duplicates on every insertion:

```julia
function Base.insert!(table::SortedNeighborTable, neighbor::Neighbor)
    # Check if this point index is already in the table
    for existing in table.neighbors  # ❌ O(k) linear search
        if existing.index == neighbor.index
            # ...
        end
    end
    # ...
end
```

**Impact:** For k=10, this adds 10 comparisons per insertion. In a search visiting 100 nodes, that's 1000 extra comparisons.

**Fix:** Track seen indices with a BitSet or small hash set:

```julia
mutable struct SortedNeighborTable
    k::Int
    neighbors::Vector{Neighbor}
    high_dist::Float64
    seen::BitSet  # ✅ O(1) lookup for reasonable point indices
end

function Base.insert!(table::SortedNeighborTable, neighbor::Neighbor)
    idx = neighbor.index
    if idx in table.seen
        return table  # Already processed
    end
    push!(table.seen, idx)

    # Normal heap insertion (no linear scan needed)
    # ...
end
```

**Alternative:** Remove duplicate checking entirely if tree construction guarantees no duplicates (verify this assumption).

**Priority:** 🟠 HIGH - Fix soon

---

### 3. **HIGH: Set Operations in Range Search**

**Location:** `src/search.jl:157, 278`

**Issue:** Using `Set{Int}` for duplicate detection in `range_search` and `count_range`:

```julia
seen_indices = Set{Int}()  # Allocates hash table
# ...
if !(c.center in seen_indices)  # Hash lookup overhead
    push!(results, Neighbor(c.center, si.dist))
    push!(seen_indices, c.center)  # Hash insertion overhead
end
```

**Impact:** Set operations have overhead (hashing, memory allocation). For small result sets, a BitSet or simple vector scan might be faster.

**Fix:**

```julia
# For small N (< 10000), use BitSet
seen_indices = falses(N)  # ✅ Preallocated, O(1) lookup

if !seen_indices[c.center]
    push!(results, Neighbor(c.center, si.dist))
    seen_indices[c.center] = true
end
```

For very large N, current approach is OK, but could benchmark BitSet.

**Priority:** 🟠 HIGH - Fix for typical use cases

---

### 4. **MEDIUM: PriorityQueue Overhead**

**Location:** `src/search.jl:42`

**Issue:** Using `DataStructures.PriorityQueue` which has some overhead:

```julia
pq = PriorityQueue{SearchItem, Float64}()
```

**Impact:** PriorityQueue is a general-purpose structure. A specialized binary heap might be faster.

**Fix:** Consider implementing a simple binary heap specialized for SearchItem:

```julia
# Simple binary heap (lighter weight)
heap = SearchItem[]
push_heap!(heap, si)  # Custom functions with @inbounds
si = pop_heap!(heap)
```

Or use `BinaryHeap` from DataStructures.jl (lighter than PriorityQueue).

**Priority:** 🟡 MEDIUM - Profile first to confirm impact

---

### 5. **MEDIUM: View Type Instability**

**Location:** `src/pointsets.jl:66`

**Issue:** `getpoint()` returns a `SubArray` (view), which might cause type instability in distance functions:

```julia
@inline function getpoint(ps::PointSet, i::Int)
    return view(ps.data, i, :)  # Returns SubArray{Float64, 1, Matrix{Float64}, ...}
end
```

**Impact:** Julia's compiler can handle this well in most cases, but the `SubArray` type parameters are complex. In tight loops, this might prevent some optimizations.

**Fix:**

```julia
# Option 1: Return a custom view type with simpler parameters
struct PointView{T} <: AbstractVector{T}
    data::Matrix{T}
    row::Int
end
Base.size(v::PointView) = (size(v.data, 2),)
Base.getindex(v::PointView, i::Int) = v.data[v.row, i]
Base.IndexStyle(::Type{<:PointView}) = IndexLinear()

# Option 2: Use @views macro in calling code
# Option 3: Return a slice (allocates, but type is simpler)
```

**Test:** Run `test/test_type_stability.jl` to check if this is actually causing instability.

**Priority:** 🟡 MEDIUM - Test first

---

### 6. **LOW: Missing @inbounds in Hot Paths**

**Location:** Various search functions

**Issue:** Not all hot loops use `@inbounds`:

```julia
# src/search.jl:104-118
for i in section_start:section_end
    neighbor = tree.permutation_table[i]  # Could use @inbounds
    # ...
end
```

**Impact:** Bounds checking overhead in tight loops.

**Fix:** Add `@inbounds` after verifying bounds are correct:

```julia
@inbounds for i in section_start:section_end
    neighbor = tree.permutation_table[i]
    # ...
end
```

**Priority:** 🟢 LOW - Minor improvement, easy to add

---

### 7. **LOW: Potential SIMD Opportunities**

**Location:** Distance calculations already use `@simd`, but could use `@turbo` from LoopVectorization.jl

**Issue:** `@simd` provides hints, but `@turbo` from LoopVectorization.jl can be significantly faster:

```julia
# Current (metrics.jl:33-37)
@inbounds @simd for i in eachindex(p1)
    diff = p1[i] - p2[i]
    sum_sq += diff * diff
end

# Potential improvement
using LoopVectorization
@turbo for i in eachindex(p1)
    diff = p1[i] - p2[i]
    sum_sq += diff * diff
end
```

**Impact:** Can be 2-5x faster for distance calculations.

**Caveat:** LoopVectorization.jl adds a dependency and may not work on all platforms.

**Priority:** 🟢 LOW - Nice to have, benchmark first

---

## Type Stability Testing

Run the type stability test script:

```bash
julia --project=. test/test_type_stability.jl
```

Look for:
- `::Any` in function signatures (type instability)
- `Union{...}` in hot paths (type uncertainty)
- Allocation counts in hot functions

Use `@code_warntype` to inspect individual functions:

```julia
using ATRIANeighbors
ps = PointSet(rand(100, 10), EuclideanMetric())
@code_warntype distance(ps, 1, 2)
```

---

## Profiling

### Step 1: Profile a Slow Benchmark

```julia
using ATRIANeighbors, Profile

# Setup
data = rand(1000, 20)
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=10)
queries = rand(100, 20)

# Profile search
Profile.clear()
@profile for i in 1:100
    ATRIANeighbors.knn(tree, queries[i, :], k=10)
end

# View results
using ProfileView
ProfileView.view()  # Or: Profile.print()
```

Look for:
- Functions taking most time (hotspots)
- Unexpected allocations (garbage collection overhead)
- Type inference issues

### Step 2: Allocation Profiling

```julia
using BenchmarkTools

# Identify allocating functions
@time ATRIANeighbors.knn(tree, queries[1, :], k=10)
# Look at "X allocations: Y MiB"

# Detailed allocation tracking
@allocated ATRIANeighbors.knn(tree, queries[1, :], k=10)
```

---

## Recommended Optimization Order

### Phase 1: Critical Fixes (Expected 2-5x speedup)
1. ✅ Fix EmbeddedTimeSeries allocations (custom view type)
2. ✅ Replace duplicate checking with BitSet in SortedNeighborTable
3. ✅ Use BitSet for seen_indices in range_search/count_range
4. ✅ Test type stability with test_type_stability.jl

### Phase 2: Profiling & Targeted Fixes (Expected 1.5-2x additional speedup)
1. Profile knn search to identify hotspots
2. Optimize hotspots (likely tree traversal or distance calculations)
3. Consider replacing PriorityQueue with simple binary heap
4. Add @inbounds to verified safe loops

### Phase 3: Advanced Optimizations (Expected 1.2-1.5x additional speedup)
1. Consider LoopVectorization.jl for distance calculations
2. Optimize memory layout (StructArrays.jl for permutation table?)
3. Consider StaticArrays.jl for small, fixed-size points
4. Parallel batch queries with threading

---

## Benchmarking After Optimizations

After each optimization phase, re-run benchmarks:

```bash
julia --project=benchmark benchmark/quick_test.jl
```

Track improvements in a table:

| Optimization | ATRIA (ms) | KDTree (ms) | Speedup vs Before | Speedup vs KDTree |
|--------------|------------|-------------|-------------------|-------------------|
| Baseline     | ???        | ???         | 1.0x              | ???x              |
| Phase 1      | ???        | ???         | ???x              | ???x              |
| Phase 2      | ???        | ???         | ???x              | ???x              |
| Phase 3      | ???        | ???         | ???x              | ???x              |

---

## Expected Performance Characteristics

ATRIA should be **faster than KDTree** in these scenarios:
- **High-dimensional data** (D > 15)
- **Non-uniform distributions** (clustered, manifold data)
- **Time-delay embedded data** (attractors from dynamical systems)
- **Large k** (k > 20)

ATRIA may be **slower than KDTree** in:
- **Low-dimensional uniform data** (D < 5)
- **Small k** (k = 1)
- **Very small datasets** (N < 1000)

If ATRIA is slower in favorable scenarios after optimization, compare:
1. Number of distance calculations (ATRIA should compute fewer)
2. Tree construction time (ATRIA builds a more complex tree)
3. Per-distance overhead (ensure distance functions are equally fast)

---

## Additional Tools

### Code Coverage for Hot Paths
Use `--track-allocation=user` to find allocation hotspots:

```bash
julia --project=. --track-allocation=user test/test_search.jl
# Check *.mem files for allocation counts per line
```

### LLVM IR Inspection
Check generated code quality:

```julia
@code_llvm distance(EuclideanMetric(), p1, p2)
@code_native distance(EuclideanMetric(), p1, p2)
```

Look for:
- Vectorized instructions (SIMD)
- Minimal branching
- No unnecessary allocations

---

## Questions to Answer

1. **Is the tree construction slower than KDTree?**
   - If yes: Profile `build_tree!` and optimize partitioning

2. **Is the search slower than KDTree?**
   - If yes: Profile `knn` and optimize traversal/distance calculations

3. **Are we computing too many distances?**
   - Add counters to track distance calls
   - Compare vs KDTree (ATRIA should compute fewer in theory)

4. **Is memory layout causing cache misses?**
   - Profile with `perf` (Linux) or Instruments (Mac)
   - Consider structure-of-arrays layout

---

## Reference: Type Stability Guide

**Type Stable:** Return type can be inferred from input types at compile time
```julia
function good(x::Float64)
    return x * 2.0  # Always returns Float64
end
```

**Type Unstable:** Return type depends on runtime values
```julia
function bad(x::Float64)
    if x > 0
        return x  # Float64
    else
        return "negative"  # String
    end
end
```

**Check with @code_warntype:**
- ✅ Green/Blue text: type stable
- ⚠️ Yellow text: inferred but complex
- ❌ Red text (or "::Any"): type unstable - FIX THIS

---

## Summary

The main performance issues are likely:

1. **Allocations** (EmbeddedTimeSeries, duplicate checking) - HIGHEST IMPACT
2. **Data structure overhead** (PriorityQueue, Set) - MEDIUM IMPACT
3. **Missing SIMD/optimizations** (LoopVectorization, @inbounds) - LOW-MEDIUM IMPACT

After fixing these, ATRIA should be competitive with or faster than KDTree in its intended use cases (high-D, non-uniform data).

# Profiling Results

**Date:** 2025-11-05
**Workload:** 3 scenarios (1K, 5K, 10K points, D=10-20, k=10-20, 50-100 queries)

## Running Profiling

```bash
~/.juliaup/bin/julia --project=. profile_minimal.jl
cat profile_results/profile_summary.txt
```

## Results

**Total samples:** 2,424
**ATRIANeighbors:** 234 samples (9.65%)

The low percentage is expected for small test datasets. Most time is in Julia runtime overhead. For production workloads (100K+ points), ATRIA percentage would be much higher.

## Bottlenecks Found

### 1. Priority Queue Operations (10 samples)
- `DataStructures.PriorityQueue` uses Dict internally
- Hashing `SearchItem` objects is expensive (nested Cluster struct)
- Location: `src/search.jl:42`

### 2. Distance Calculations (15 samples)
- Already optimized with `@inbounds @simd`
- Location: `src/metrics.jl:33`, `src/pointsets.jl:122`

### 3. Search Loop (53 samples)
- General function overhead
- Location: `src/search.jl:26`

### 4. Permutation Table Access (19 samples)
- Missing `@inbounds` annotation
- Location: `src/search.jl:113`

## Recommendations

**High priority:**
- Consider custom binary heap instead of PriorityQueue (avoids hashing)

**Low priority:**
- Add `@inbounds` to permutation table access in `_search_terminal_node!`
- Add `@inline` to small helper functions

**Don't bother:**
- Distance calculations are already well optimized

## Next Steps

1. Profile with larger datasets to get better statistics
2. Implement highest-impact optimization only
3. Re-profile to measure actual improvement

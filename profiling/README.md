# Profiling Scripts

This directory contains scripts for profiling the ATRIANeighbors package using representative workloads.

## 💡 Recommended: ProfilingAnalysis.jl

For the most comprehensive profiling (runtime + allocations + categorization + smart recommendations), use the **ProfilingAnalysis.jl** package:

```julia
# From project root
using ProfilingAnalysis

# Collect profiles with workload
runtime = collect_profile_data(() -> my_workload())
allocs = collect_allocation_profile(() -> my_workload(), sample_rate=0.1)

# Auto-categorize and get recommendations
categorized = categorize_entries(runtime.entries)
recs = generate_smart_recommendations(categorized, runtime.total_samples)
```

See `../ProfilingAnalysis.jl/` and `../PROFILING_IMPROVEMENTS.md` for full documentation.

## Setup

This directory uses Julia's development environment to depend on local versions of:
- `ATRIANeighbors` (from the parent directory)
- `ProfilingAnalysis.jl` (from `../ProfilingAnalysis.jl`)

To set up the environment:

```bash
cd /home/user/ATRIANeighbors.jl
export PATH="$HOME/.juliaup/bin:$PATH"

# Using Julia 1.10 (recommended)
julia +1.10 --project=profiling -e 'using Pkg; Pkg.instantiate()'
```

Changes to ATRIANeighbors or ProfilingAnalysis.jl are immediately reflected when running profiling scripts.

## Running Profiling Scripts

### Comprehensive Profiling (Recommended)

The comprehensive profiling script tests all major operations on various data types:

```bash
julia +1.10 --project=profiling profiling/profile_comprehensive.jl
```

**Workloads profiled:**
- Lorenz attractor k-NN search (5000 points, 200 queries)
- Rössler attractor k-NN search (5000 points, 200 queries)
- High-dimensional clustered data (3000 points, D=20, 150 queries)
- Very high-dimensional data (2000 points, D=50, 100 queries)
- Range search on Lorenz attractor (100 queries)
- Count range on clustered data (100 queries)

**Output:**
- `profile_results/profile_flat.txt` - Function-level statistics sorted by sample count
- `profile_results/profile_tree.txt` - Call hierarchy with up to 25 levels of depth
- `profile_results/profile_summary.txt` - Bottleneck analysis with actionable recommendations

**Runtime:** ~30-60 seconds (including compilation)

### Minimal Profiling (Quick Test)

For quick profiling with smaller datasets:

```bash
julia +1.10 --project=profiling profiling/profile_minimal.jl
```

**Workloads:**
- Simple Gaussian data at various sizes (1000, 5000, 10000 points)
- k-NN search only

**Runtime:** ~10-20 seconds

### Other Profiling Scripts

Additional profiling utilities:

```bash
# Intensive profiling with larger datasets
julia +1.10 --project=profiling profiling/profile_intensive.jl

# Analyze existing profiling results
julia +1.10 --project=profiling profiling/profile_analyzer.jl

# Test profiling scalability
julia +1.10 --project=profiling profiling/test_profile_scalability.jl
```

## Interpreting Results

### Profile Summary

The `profile_summary.txt` file contains:

1. **Top Hotspots** - Functions consuming the most CPU time
2. **ATRIANeighbors-Specific Hotspots** - Bottlenecks within our code
3. **Performance Bottleneck Analysis** - Categorized by operation type:
   - Distance calculations
   - Heap/priority queue operations
   - Tree construction
   - Point access
   - Search operations
4. **Optimization Recommendations** - Specific suggestions with estimated impact

### Understanding Percentages

- **>20%**: Major bottleneck, high-priority optimization target
- **10-20%**: Significant, worth optimizing
- **5-10%**: Moderate impact
- **<5%**: Minor, optimize only if easy

### Common Patterns

**Distance calculations dominate** → Optimize with `@inbounds`, `@simd`, better early termination

**Heap operations are expensive** → Consider StaticArrays for small k, optimize SortedNeighborTable

**Tree construction takes time** → Normal for large datasets, optimize partition algorithm

**Many point accesses** → Ensure getpoint() is inlined and type-stable

## Tips for Profiling

### Getting Clean Profiles

1. **Always warm up first** - Compilation overhead can skew results
2. **Run long enough** - Short workloads (<1s) may not collect enough samples
3. **Increase workload if needed** - Add more queries or larger datasets
4. **Profile release builds** - Use `julia -O3` for production-like performance

### Focused Profiling

To profile a specific operation:

```julia
using Profile
using ATRIANeighbors

# Your setup code here
data = randn(10000, 20)
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=64)

# Profile a specific operation
Profile.clear()
@profile for i in 1:1000
    query = randn(20)
    knn(tree, query, k=10)
end

# View results
Profile.print(format=:flat, sortedby=:count)

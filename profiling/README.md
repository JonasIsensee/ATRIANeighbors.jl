# Profiling Tools for ATRIANeighbors.jl

This directory contains comprehensive profiling and performance analysis tools optimized for CLI-based workflows and LLM agents.

## 🚀 Quick Start (Recommended)

The fastest way to profile your code:

```bash
# Quick runtime profile (takes ~2 seconds)
julia --project=. profiling/profile_cli.jl quick

# Comprehensive profile with allocations (takes ~10 seconds)
julia --project=. profiling/profile_cli.jl deep

# Guided step-by-step profiling session
julia --project=. profiling/profile_cli.jl guided
```

## 📚 What's Available

### 1. **ProfileTools.jl** - Core Profiling Library

A comprehensive, self-contained profiling library with:
- **Runtime profiling** - CPU hotspot detection
- **Allocation profiling** - Memory allocation tracking
- **Type stability analysis** - Dynamic dispatch detection
- **Concise reports** - Optimized for LLM analysis and CLI output

### 2. **profile_cli.jl** - Streamlined CLI Interface

User-friendly command-line interface with guided workflows:
- `quick` - Fast runtime profiling
- `deep` - Runtime + allocation analysis
- `allocs` - Detailed allocation profiling
- `guided` - Interactive step-by-step profiling
- `type-check` - Type stability checking guide

### 3. Legacy Scripts

Older profiling scripts (still functional):
- `profile_comprehensive.jl` - Detailed profiling with multiple workloads
- `profile_minimal.jl` - Quick test with simple workloads
- `profile_analyzer.jl` - Advanced analysis (requires ProfilingAnalysis.jl)

## 🎯 Using the CLI Tool

### Basic Commands

```bash
# Show all available commands
julia --project=. profiling/profile_cli.jl help

# Quick runtime profile with different workload sizes
julia --project=. profiling/profile_cli.jl quick small    # 1K points, fast
julia --project=. profiling/profile_cli.jl quick medium   # 5K points, default
julia --project=. profiling/profile_cli.jl quick large    # 10K points, thorough

# Deep analysis (runtime + allocations)
julia --project=. profiling/profile_cli.jl deep

# Allocation-focused profiling
julia --project=. profiling/profile_cli.jl allocs

# Interactive guided session (best for first-time users)
julia --project=. profiling/profile_cli.jl guided
```

### Understanding the Output

**Runtime Profile:**
- Shows where CPU time is spent
- Categorizes by operation type (distance, search, heap, etc.)
- Focus on categories with >15% of samples

**Allocation Profile:**
- Shows memory allocation hotspots
- "Total bytes" matters more than count
- Look for allocations in hot inner loops

**Recommendations:**
- Prioritized list of optimizations
- Start from the top
- Re-profile after each major change

## 📖 Using ProfileTools.jl Directly

For custom profiling in your own scripts:

```julia
using ProfileTools

# Quick runtime profile
result = @profile_quick begin
    # Your code here
    tree = ATRIA(ps, min_points=64)
    knn(tree, query, k=10)
end

# Deep profile with allocations
result = @profile_deep begin
    # Your code here
end

# Allocation-only profile
result = @profile_allocs begin
    # Your code here
end

# Print detailed report
ProfileTools.print_report(result)

# Check type stability
report = ProfileTools.check_type_stability(my_function, (ArgType1, ArgType2))
```

## 🔧 Setup

No special setup required! The tools use only Julia's standard library:
- `Profile` - CPU profiling
- `Profile.Allocs` - Allocation profiling
- `InteractiveUtils` - Code introspection

Changes to ATRIANeighbors are immediately reflected when running profiling scripts.

## 🎓 Optimization Workflow

The recommended workflow for performance optimization:

1. **Initial Profile**: Run `julia --project=. profiling/profile_cli.jl quick`
2. **Identify Bottleneck**: Look at the categorized hotspots (distance, search, heap, etc.)
3. **Deep Dive**: Run `deep` profile on the bottleneck area
4. **Fix Issues**: Address top 1-2 issues based on recommendations
5. **Verify**: Re-run `quick` profile to measure improvement
6. **Repeat**: Iterate until performance goals are met

### Common Optimization Patterns

**🔥 Distance Calculations (>15% of runtime)**
```julia
# Before
function distance(p1, p2)
    sum = 0.0
    for i in 1:length(p1)
        sum += (p1[i] - p2[i])^2
    end
    return sqrt(sum)
end

# After
@inline function distance(p1, p2)
    sum = 0.0
    @inbounds @simd for i in 1:length(p1)
        sum += (p1[i] - p2[i])^2
    end
    return sqrt(sum)
end
```

**📦 Heap Operations (>10% of runtime)**
- Use `StaticArrays` for small fixed k
- Avoid allocations in `insert!` operations
- Consider custom heap implementation for k-NN

**🔍 Search Operations (>20% of runtime)**
- Use `@inbounds` for permutation table access (after bounds checking)
- Minimize allocations in search loop
- Cache frequently accessed cluster data

**🏗️ Tree Construction (>15% of runtime)**
- Pre-allocate temporary arrays
- Optimize `assign_points_to_centers!` partition algorithm
- Improve memory access patterns for cache efficiency

## 🔬 Advanced Analysis

### Type Stability Checking

Type instabilities cause dynamic dispatch and are a major performance killer:

```julia
# In Julia REPL
using ATRIANeighbors

# Check a function
@code_warntype knn(tree, query, k=10)

# Look for:
# 🔴 Body::Any - Complete type instability (fix immediately!)
# 🟡 Body::Union{...} - Partial instability (should fix)
# ✅ Body::ConcreteType - Type stable (good!)
```

### Allocation Tracking

Find unexpected allocations:

```julia
using BenchmarkTools

# Measure allocations
@allocated knn(tree, query, k=10)  # Should be 0 or very small

# Detailed timing with allocations
@btime knn($tree, $query, k=10)
```

### Interactive Profiling

For deep investigation:

```julia
using Profile
using ProfileView  # or ProfileSVG, PProf, etc.

# Profile your code
@profile my_workload()

# View flame graph
ProfileView.view()
```

### Type Inference Analysis (Advanced)

```julia
using Cthulhu

# Interactive descent through type inference
@descend knn(tree, query, k=10)

# Look for red highlights indicating type instability
```

## 📊 Performance Metrics

### What's "Good" Performance?

Based on typical ATRIA use cases:

**Runtime:**
- k-NN query on 10K points, D=20: < 1ms per query
- Tree construction on 10K points: < 100ms

**Allocations:**
- k-NN query should be allocation-free (0 bytes) after warmup
- Tree construction: ~O(N) allocations is acceptable

**Comparison to KDTree:**
- ATRIA should be 1.5-3x faster than KDTree on chaotic attractors
- ATRIA should be 1.2-2x faster on high-dimensional data (D>15)

## 🐛 Troubleshooting

### "No ATRIA-specific code found in profile"

This means:
- Workload is too fast (< 1 second) - use larger workload
- Julia internals dominate - this is normal for very fast operations
- Need more samples - increase number of queries

**Solution**: Use `large` workload or increase queries in custom workload.

### "Profile data is empty"

- Workload completed too quickly
- Need to increase Profile buffer size

**Solution**:
```julia
using Profile
Profile.init(n=10_000_000)  # Increase sample buffer
```

### Type Instability in Reports

If you see dynamic dispatch warnings:
1. Use `@code_warntype` to find the unstable function
2. Add type annotations to function arguments
3. Ensure return types are concrete
4. Use type assertions `::T` where needed

## 🔗 Related Tools

- **BenchmarkTools.jl**: Precise micro-benchmarking
- **ProfileView.jl**: Graphical flame graphs
- **PProf.jl**: Google's pprof format (web viewer)
- **Cthulhu.jl**: Interactive type inference explorer
- **JET.jl**: Static analysis for type issues

## 📚 Legacy Scripts

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

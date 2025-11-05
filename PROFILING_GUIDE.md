# Julia Profiling Guide for ATRIANeighbors.jl

## Overview

This guide explains how to profile ATRIANeighbors.jl and interpret the results. It's designed to be used by both humans and AI models to identify and fix performance bottlenecks.

## Quick Start

### Prerequisites

```bash
# Install dependencies (one-time setup)
~/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Run Profiling

```bash
# Run minimal profiling (uses only built-in Profile module)
~/.juliaup/bin/julia --project=. profile_minimal.jl

# Or run comprehensive profiling (requires PProf.jl)
~/.juliaup/bin/julia --project=benchmark benchmark/profile_atria.jl
```

### View Results

```bash
# View summary with bottleneck analysis
cat profile_results/profile_summary.txt

# View tree view (shows call hierarchy)
less profile_results/profile_tree.txt

# View flat view (function-level statistics)
less profile_results/profile_flat.txt
```

## Profiling Methods in Julia

### 1. Built-in Profile Module

Julia's built-in `Profile` module is a sampling profiler that periodically samples the call stack.

**Advantages:**
- No external dependencies required
- Low overhead
- Works in all environments
- Produces text output that AI models can easily parse

**Usage:**
```julia
using Profile

# Clear previous data
Profile.clear()

# Run with profiling
@profile my_function()

# View results
Profile.print(format=:tree)  # Tree view (shows call hierarchy)
Profile.print(format=:flat)  # Flat view (sorted by count)
```

**Output Formats:**
- `:tree` - Shows call hierarchy with indentation (default)
- `:flat` - Flat list sorted by sample count

**Key Parameters:**
- `sortedby=:count` - Sort by number of samples (for `:flat`)
- `maxdepth=20` - Limit tree depth (for `:tree`)
- `noisefloor=2.0` - Filter out functions with < 2% of samples

### 2. PProf.jl (Google pprof format)

PProf.jl exports Julia profiling data to the pprof format for interactive visualization.

**Installation:**
```julia
using Pkg
Pkg.add("PProf")
```

**Usage:**
```julia
using Profile, PProf

@profile my_function()

# Export and open web interface
pprof()

# Or export to file without web interface
pprof(out="profile.pb.gz", web=false)
```

**View with pprof CLI:**
```bash
# Interactive web interface
pprof -http=:8080 profile.pb.gz

# Text report
pprof -text profile.pb.gz

# Flamegraph (SVG)
pprof -svg profile.pb.gz > flamegraph.svg
```

### 3. StatProfilerHTML.jl (Static HTML Reports)

Generates explorable HTML reports with flamegraphs.

**Installation:**
```julia
using Pkg
Pkg.add("StatProfilerHTML")
```

**Usage:**
```julia
using Profile, StatProfilerHTML

# Using macro
@profilehtml my_function()

# Or manually
@profile my_function()
statprofilehtml()
```

Opens an HTML file in your browser with an interactive flamegraph.

## Interpreting Profile Results

### Understanding the Output

**Sample Count:** Each entry shows how many times a function appeared in sampled call stacks. Higher counts = more time spent.

**Percentage:** Proportion of total samples. Functions with >5% are usually worth investigating.

**Tree View Indentation:** Deeper indentation = called from parent function. Shows the calling relationship.

### Common Patterns and What They Mean

#### 1. Distance Calculations in Hot Path

```
500 samples (25%) - distance (metrics.jl:45)
  480 samples (24%) - loop iteration
```

**Meaning:** Distance calculations are consuming 25% of runtime.

**Fixes:**
- Add `@inbounds` for array access (removes bounds checking)
- Use `@simd` for vectorization
- Implement early termination more aggressively
- Use `@inline` for small distance functions

**Example:**
```julia
# Before
function distance(x, y)
    s = 0.0
    for i in 1:length(x)
        s += (x[i] - y[i])^2
    end
    return sqrt(s)
end

# After
@inline function distance(x, y)
    s = 0.0
    @inbounds @simd for i in 1:length(x)
        s += (x[i] - y[i])^2
    end
    return sqrt(s)
end
```

#### 2. Heap Operations in Hot Path

```
350 samples (17.5%) - heap_insert! (structures.jl:150)
```

**Meaning:** Priority queue/heap operations are expensive.

**Fixes:**
- Use `StaticArrays` for fixed-size structures
- Reduce allocations (check with `@allocated`)
- Consider binary heap alternatives (e.g., pairing heap)
- Pre-allocate arrays

#### 3. Partition Algorithm Hotspot

```
400 samples (20%) - assign_points_to_centers! (tree.jl:187)
```

**Meaning:** Tree construction partitioning is slow.

**Fixes:**
- Optimize cache locality (access memory sequentially)
- Reduce allocations in partition loop
- Use `@inbounds` where safe
- Consider SIMD for distance comparisons

#### 4. Point Access Overhead

```
250 samples (12.5%) - getpoint (pointsets.jl:30)
```

**Meaning:** Point data access is expensive.

**Fixes:**
- Ensure `getpoint()` is type-stable (check with `@code_warntype`)
- Add `@inline` annotation
- Use `@inbounds` for array access
- Consider caching frequently accessed points

### Red Flags to Look For

1. **Type Instability:** Look for `Any` in types
   ```bash
   julia --project=. -e 'using ATRIANeighbors; @code_warntype distance(...)'
   ```

2. **Allocations:** Check if functions allocate unexpectedly
   ```julia
   @allocated my_function()  # Should be 0 or very small for hot paths
   ```

3. **Small Functions Not Inlined:** Hot path functions should be `@inline`

4. **Bounds Checking:** Use `@inbounds` where safe (after testing)

## AI Model Guide: Identifying Bottlenecks

### Step 1: Read profile_summary.txt

Look for the "ATRIANeighbors-specific hotspots" section. Focus on functions with:
- >5% of total samples
- Located in ATRIANeighbors source files (tree.jl, search.jl, metrics.jl, etc.)

### Step 2: Categorize Bottlenecks

**Distance Calculations:**
- Functions containing "distance", "metric", or in metrics.jl
- Fix: Add @inbounds, @simd, @inline, early termination

**Heap/Priority Queue:**
- Functions containing "heap", "push!", "SortedNeighborTable"
- Fix: Use StaticArrays, reduce allocations, better data structures

**Tree Construction:**
- Functions containing "assign_points", "partition", "build_tree"
- Fix: Cache locality, reduce allocations, @inbounds

**Search Operations:**
- Functions containing "knn", "search", "SearchItem"
- Fix: Optimize priority queue, reduce allocations, @inbounds

**Point Access:**
- Functions containing "getpoint", "pointset"
- Fix: Ensure type stability and inlining

### Step 3: Read Source Code

Use the file:line information from profile_tree.txt to locate the exact code:

```
assign_points_to_centers! (tree.jl:187)
```

Read `/home/user/ATRIANeighbors.jl/src/tree.jl` starting at line 187.

### Step 4: Apply Fixes

**Common optimizations:**

1. Add `@inbounds` to remove bounds checking:
```julia
@inbounds for i in 1:n
    x[i] = y[i]
end
```

2. Add `@simd` for vectorization:
```julia
@inbounds @simd for i in 1:n
    sum += (x[i] - y[i])^2
end
```

3. Add `@inline` for small hot-path functions:
```julia
@inline function small_hot_function(x)
    # ...
end
```

4. Replace dynamic arrays with StaticArrays (for small fixed sizes):
```julia
using StaticArrays
neighbors = MVector{10, Neighbor}()  # Instead of Vector{Neighbor}()
```

5. Pre-allocate arrays:
```julia
# Before
function f()
    result = []
    push!(result, x)  # Allocates on every call
end

# After
function f(result)
    empty!(result)
    push!(result, x)  # Reuses pre-allocated array
end
```

### Step 5: Verify Improvements

After applying fixes:

1. Re-run profiling
2. Compare sample counts (should decrease for optimized functions)
3. Run benchmarks to measure actual speedup
4. Ensure correctness with tests

## Example Workflow

```bash
# 1. Run profiling
~/.juliaup/bin/julia --project=. profile_minimal.jl

# 2. Identify bottleneck
grep -A 10 "ATRIANeighbors-specific hotspots" profile_results/profile_summary.txt

# Example output:
#   1. [450 samples, 22.5%] distance (metrics.jl:45)

# 3. Read source code
cat -n src/metrics.jl | sed -n '40,55p'

# 4. Apply fix (add @inbounds @simd @inline)
# Edit src/metrics.jl

# 5. Re-run profiling
~/.juliaup/bin/julia --project=. profile_minimal.jl

# 6. Compare results (should see reduction in distance samples)
diff -u profile_results_old/profile_summary.txt profile_results/profile_summary.txt

# 7. Run benchmarks to measure speedup
~/.juliaup/bin/julia --project=benchmark benchmark/quick_test.jl
```

## Profiling Best Practices

### DO:
- ✅ Profile realistic workloads (not toy examples)
- ✅ Warm up code first (avoid profiling compilation)
- ✅ Focus on hot paths (>5% of samples)
- ✅ Verify fixes with benchmarks
- ✅ Test correctness after optimizations

### DON'T:
- ❌ Profile code that hasn't been run yet (compilation dominates)
- ❌ Optimize functions with <1% of samples (not worth it)
- ❌ Use `@inbounds` without testing (can cause silent corruption)
- ❌ Sacrifice readability for tiny gains (<1% speedup)

## Troubleshooting

### "No profile data collected"

**Cause:** Workload too fast, not enough samples.

**Fix:** Increase workload size or run more iterations:
```julia
for _ in 1:100  # Run 100 times
    my_function()
end
```

### "Most time in compilation/codegen"

**Cause:** Profiling before code is compiled.

**Fix:** Run function once before profiling (warm-up):
```julia
my_function()  # Warm up
Profile.clear()
@profile my_function()  # Now profile
```

### "Can't identify bottleneck"

**Cause:** Samples spread across many small functions.

**Fix:**
- Increase `noisefloor` to filter noise
- Look at cumulative time in tree view
- Profile longer workloads

## References

- [Julia Profile Documentation](https://docs.julialang.org/en/v1/manual/profile/)
- [PProf.jl GitHub](https://github.com/JuliaPerf/PProf.jl)
- [StatProfilerHTML.jl GitHub](https://github.com/tkluck/StatProfilerHTML.jl)
- [Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)

## For AI Models: Summary Checklist

When profiling Julia code:

1. ☐ Run profiling script (`profile_minimal.jl`)
2. ☐ Read `profile_summary.txt` to identify hotspots (>5% samples)
3. ☐ Categorize bottlenecks (distance, heap, partition, etc.)
4. ☐ Read source code at reported file:line locations
5. ☐ Apply appropriate optimizations:
   - Distance: `@inbounds @simd @inline`
   - Heap: StaticArrays, reduce allocations
   - Partition: cache locality, @inbounds
   - Point access: type stability, @inline
6. ☐ Re-run profiling to verify improvements
7. ☐ Run benchmarks to measure actual speedup
8. ☐ Run tests to ensure correctness
9. ☐ Commit changes with clear description of optimizations

Remember: **Measure first, optimize second, verify always!**

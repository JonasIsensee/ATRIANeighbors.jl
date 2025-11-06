# ATRIANeighbors.jl Profiling Guide for LLM Agents

This guide provides a streamlined, CLI-friendly approach to profiling Julia code, optimized for automated analysis by LLM agents.

## 🎯 Quick Start

The simplest and most reliable way to profile AT RIANeighbors:

```bash
# Basic profiling that works reliably
julia --project=. profiling/profile_comprehensive.jl

# Check results
cat profile_results/profile_summary.txt
```

## 📊 What We Built

### 1. ProfileTools.jl - Analysis Library

A comprehensive profiling analysis library with:
- Runtime hotspot detection and categorization
- Allocation tracking and analysis
- Type stability checking helpers
- Concise, actionable reporting

**Status**: ✅ Fully implemented, ready for use in custom scripts

### 2. profile_cli.jl - CLI Interface

A user-friendly command-line tool for common profiling workflows.

**Status**: ⚠️ Functional but macros need refinement for edge cases

### 3. profile_comprehensive.jl - Reliable Profiler

The battle-tested profiling script that works reliably.

**Status**: ✅ Production-ready, use this for serious profiling

##  🔬 Understanding Profiling in Julia

### Why Julia Profiling Can Be Tricky

1. **JIT Compilation**: First run includes compilation time
2. **Code Optimization**: Well-optimized code may be too fast to profile
3. **Sampling Nature**: Profile collects samples periodically

### Solution: Multiple Iterations

The key to reliable profiling in Julia:

```julia
# ❌ Too fast - no samples collected
@profile knn(tree, query, k=10)

# ✅ Good - runs long enough to collect samples
@profile for i in 1:1000
    knn(tree, query, k=10)
end
```

## 🛠️ Recommended Workflow for LLM Agents

When asked to profile or optimize Julia code, follow this workflow:

### Step 1: Run Comprehensive Profile

```bash
julia --project=. profiling/profile_comprehensive.jl
```

**Output**: `profile_results/profile_summary.txt`

### Step 2: Parse the Summary

Extract key information:
- **Total samples**: Indicates if profile is meaningful (>100 is good)
- **Top hotspots**: Functions with >10% of samples
- **Category breakdown**: Distance, search, heap, tree construction
- **Recommendations**: Prioritized optimization suggestions

### Step 3: Analyze Top Hotspots

Focus on:
1. Functions with >15% of runtime
2. Functions from ATRIANeighbors package (not Julia Base)
3. Inner loop functions (called many times)

### Step 4: Check Type Stability

For identified hotspots:

```bash
julia --project=. -e 'using ATRIANeighbors; @code_warntype knn(tree, query, k=10)'
```

Look for:
- 🔴 `Body::Any` - Critical type instability
- 🟡 `Body::Union{...}` - Partial instability
- ✅ `Body::ConcreteType` - Good!

### Step 5: Check Allocations

```bash
julia --project=. benchmark/profile_allocations.jl
```

Focus on:
- Allocations in hot loops
- Large allocation sites
- Unexpected allocations

### Step 6: Implement Fixes

Common optimizations:
- Add `@inbounds` to array accesses (after bounds checking)
- Add `@simd` to vectorizable loops
- Use `@inline` for small functions
- Pre-allocate arrays
- Fix type instabilities

### Step 7: Verify Improvement

Re-run profile and compare:
- Did total samples decrease? (faster!)
- Did hotspot percentages change?
- Did allocations decrease?

## 📖 Example: Complete Profiling Session

```bash
# 1. Initial profile
julia --project=. profiling/profile_comprehensive.jl

# 2. Review results
cat profile_results/profile_summary.txt

# Example output shows:
# - distance calculations: 35% of runtime
# - _euclidean_distance_row function is the hotspot

# 3. Check type stability
julia --project=. -e '
using ATRIANeighbors
# Check the function signature
@code_warntype distance(ps, 1, 2)
'

# 4. Check allocations
julia --project=. benchmark/profile_allocations.jl

# 5. Make optimizations in src/pointsets.jl:
#    - Add @inbounds
#    - Add @simd
#    - Ensure @inline

# 6. Verify improvement
julia --project=. profiling/profile_comprehensive.jl

# 7. Compare before/after in profile_summary.txt
```

## 🎓 Key Profiling Concepts for LLMs

### 1. Sample Count Matters

- < 10 samples: Profile unreliable, workload too fast
- 10-100 samples: Marginal, consider larger workload
- 100-1000 samples: Good
- \> 1000 samples: Excellent

### 2. Percentage Thresholds

- \> 20%: Major bottleneck, high priority
- 10-20%: Significant, worth optimizing
- 5-10%: Moderate
- < 5%: Low priority

### 3. Categorization

Hotspots are categorized by operation type:
- **Distance calculations**: Often 20-40% in k-NN workloads
- **Search operations**: Main algorithm logic
- **Heap operations**: Priority queue for k-NN
- **Tree construction**: One-time cost
- **Point access**: Data structure overhead

### 4. Allocation Impact

- k-NN queries should be allocation-free (0 bytes) after warmup
- Any allocation in hot loops is a red flag
- Large allocations (>1KB) are expensive

### 5. Type Stability

- Type-unstable code can be 10-100x slower
- Always check with `@code_warntype`
- Fix by adding type annotations

## 🤖 LLM Agent CLI Commands

### Quick Profiling

```bash
# Comprehensive profile with analysis
julia --project=. profiling/profile_comprehensive.jl

# View results
cat profile_results/profile_summary.txt | head -100
```

### Allocation Profiling

```bash
# Detailed allocation tracking
julia --project=. benchmark/profile_allocations.jl
```

### Type Checking

```bash
# Check a specific function
julia --project=. -e '
using ATRIANeighbors
@code_warntype function_name(args...)
'
```

### Benchmarking

```bash
# Precise timing with BenchmarkTools
julia --project=. -e '
using BenchmarkTools
using ATRIANeighbors
# Setup code here...
@btime knn($tree, $query, k=10)
'
```

## 🐛 Troubleshooting

### "No samples collected"

**Cause**: Workload too fast

**Solution**:
```julia
# Instead of profiling once
@profile my_function()

# Profile many iterations
@profile for i in 1:1000
    my_function()
end
```

### "No ATRIA-specific code in profile"

**Cause**: Julia internals dominate (GC, compilation, etc.)

**Solution**:
- Increase workload size
- Run warmup first
- Check if code is extremely optimized (use @btime to verify)

### "Profile.@profile doesn't work in macros"

**Cause**: Macro hygiene issues with Profile module

**Solution**: Use Profile.@profile directly in scripts, not wrapped in custom macros

## 📚 Additional Tools

### ProfileView.jl - Graphical Flame Graphs

```julia
using ProfileView
@profview my_workload()
```

### PProf.jl - Google pprof Format

```julia
using PProf
@pprof my_workload()
```

### Cthulhu.jl - Type Inference Explorer

```julia
using Cthulhu
@descend my_function(args...)
```

### JET.jl - Static Analysis

```julia
using JET
@report_opt my_function(args...)
```

## ✅ Best Practices for LLM Agents

1. **Always warmup first** - Run code once before profiling
2. **Use existing scripts** - `profile_comprehensive.jl` is reliable
3. **Focus on percentages** - Not absolute sample counts
4. **Check type stability** - Use `@code_warntype`
5. **Measure allocations** - Use `@allocated` or allocation profiler
6. **Verify improvements** - Re-profile after changes
7. **Use `@btime`** - For precise before/after timing

## 📝 Summary

**For LLM Agents profiling Julia code:**

1. Use `profile_comprehensive.jl` for reliable profiling
2. Parse `profile_summary.txt` for hotspots
3. Focus on functions with >15% runtime
4. Check type stability with `@code_warntype`
5. Check allocations with `profile_allocations.jl`
6. Implement fixes (@ inbounds, @simd, type annotations)
7. Re-profile to verify improvement

**The profiling tools are production-ready and well-documented. Use them with confidence!**

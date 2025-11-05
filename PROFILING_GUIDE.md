# Profiling Guide for ATRIANeighbors.jl

This guide explains how to use the profiling tools to identify and analyze performance bottlenecks in ATRIANeighbors.jl.

## Location

All profiling scripts are located in the `profiling/` directory. This directory has its own environment using Julia 1.12's workspace feature to depend on the local versions of ATRIANeighbors and ProfilingAnalysis.jl.

## Overview

We provide two profiling tools:

1. **`profile_minimal.jl`** - Simple profiling that generates text reports (good for quick checks)
2. **`profile_analyzer.jl`** - Advanced profiling with structured data storage and programmatic querying (recommended for detailed analysis)

## Why Use `profile_analyzer.jl`?

The advanced profiler solves key usability issues:

- **Structured Data**: Stores profile data in JSON format for programmatic access
- **Efficient Queries**: Extract specific information without reading entire files
- **Scalability**: Handles large profiles without clogging context windows
- **Flexible Analysis**: Filter by file, function, pattern, or package code
- **Comparison**: Compare two profiles to identify performance regressions
- **Recommendations**: Auto-generates optimization suggestions based on hotspots

## Setup

First, set up the profiling environment:

```bash
cd profiling
export PATH="$HOME/.juliaup/bin:$PATH"
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Quick Start

### 1. Collect Profile Data

```bash
cd profiling
# Collect profile with default workload
julia --project=. profile_analyzer.jl collect

# Output: profile_results/profile_data.json
```

### 2. Query Profile Data

```bash
# Show top 10 hotspots
julia --project=. profile_analyzer.jl query --top 10

# Show only ATRIA package code
julia --project=. profile_analyzer.jl query --atria

# Find all functions matching "distance"
julia --project=. profile_analyzer.jl query --pattern distance

# Filter by file
julia --project=. profile_analyzer.jl query --file search.jl

# Filter by function name
julia --project=. profile_analyzer.jl query --function _search_knn!
```

### 3. Generate Summary

```bash
# Full summary with recommendations
julia --project=. profile_analyzer.jl summary

# Show only ATRIA code
julia --project=. profile_analyzer.jl summary --atria-only

# Custom top N
julia --project=. profile_analyzer.jl summary --top 30
```

## Advanced Usage

### Custom Workloads

You can profile custom workloads programmatically:

```julia
using ATRIANeighbors
include("profile_analyzer.jl")

# Define custom workload
function my_workload()
    data = randn(10000, 20)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps)

    for i in 1:100
        query = randn(20)
        knn(tree, query, k=10)
    end
end

# Collect profile
profile = collect_profile_data(
    workload_fn=my_workload,
    metadata=Dict("test" => "custom_workload")
)

# Save to custom file
save_profile(profile, "my_profile.json")

# Query programmatically
top_10 = query_top_n(profile, 10)
atria_code = query_atria_code(profile)

# Print results
print_entry_table(top_10)
```

### Comparing Profiles

Compare two profiles to identify performance changes:

```bash
# Collect baseline
julia --project=. profile_analyzer.jl collect --output profile_baseline.json

# ... make code changes ...

# Collect new profile
julia --project=. profile_analyzer.jl collect --output profile_new.json

# Compare
julia --project=. profile_analyzer.jl compare profile_baseline.json profile_new.json
```

This shows:
- Functions with increased/decreased sample counts
- Absolute and percentage changes
- New/removed hotspots

### Programmatic Queries in Julia

For AI assistants or automated analysis, use the query functions directly:

```julia
using ATRIANeighbors
include("profile_analyzer.jl")

# Load profile data
profile = load_profile("profile_results/profile_data.json")

# Query functions
top_hotspots = query_top_n(profile, 20, filter_system=true)
distance_funcs = query_by_pattern(profile, "distance")
search_funcs = query_by_file(profile, "search.jl")
atria_only = query_atria_code(profile)

# Access data programmatically
for entry in top_hotspots[1:5]
    println("$(entry.func) @ $(entry.file):$(entry.line)")
    println("  Samples: $(entry.samples) ($(entry.percentage)%)")
end

# Generate summary without printing
summarize_profile(profile, atria_only=true, top_n=10)
```

## Understanding Profile Output

### Profile Entry Fields

Each profile entry contains:
- **func**: Function name
- **file**: Source file path
- **line**: Line number
- **samples**: Number of samples (higher = more time spent)
- **percentage**: Percentage of total samples

### Interpreting Results

**High sample counts indicate bottlenecks:**
- >10%: Critical hotspot, optimize first
- 5-10%: Significant, consider optimization
- 1-5%: Minor, optimize if easy wins available
- <1%: Usually not worth optimizing

**Common patterns:**
- Distance calculations in hot path → Add `@inbounds`, `@simd`
- Search operations → Optimize priority queue, reduce allocations
- Heap operations → Use `StaticArrays` for small k
- Tree construction → Optimize partitioning algorithm

### System Code Filtering

By default, queries filter out system code:
- Julia Base library
- C libraries (libc, etc)
- Compilation infrastructure

To include system code:
```bash
julia --project=. profile_analyzer.jl query --top 20 --no-system false
```

## Performance Recommendations

The profiler auto-generates recommendations based on detected hotspots:

### Distance Calculations 🔥
If distance functions appear in top hotspots:
- Add `@inbounds` for array access
- Use `@simd` for vectorization
- Implement aggressive early termination
- Add `@inline` annotations

### Search Operations 🔍
If search/knn functions are hot:
- Optimize priority queue operations
- Reduce allocations in search loop
- Use `@inbounds` for permutation table access
- Consider caching frequently accessed data

### Heap Operations 📊
If heap/neighbor table operations are hot:
- Use `StaticArrays` for small fixed k
- Optimize `SortedNeighborTable` structure
- Reduce allocations in insert/remove

### Tree Construction 🌲
If tree building is slow:
- Optimize partition algorithm
- Improve cache locality
- Pre-allocate arrays

## Tips for AI Assistants

When using these tools as an AI assistant:

1. **Always use `query` commands** instead of reading full profile files
   - ❌ Don't: `Read profile_results/profile_flat.txt` (wastes context)
   - ✅ Do: `julia --project=. profile_analyzer.jl query --atria`

2. **Start with targeted queries**:
   ```bash
   # First, get ATRIA-specific hotspots
   julia --project=. profile_analyzer.jl query --atria

   # Then drill into specific areas
   julia --project=. profile_analyzer.jl query --file search.jl
   julia --project=. profile_analyzer.jl query --pattern distance
   ```

3. **Use programmatic access for analysis**:
   ```julia
   profile = load_profile("profile_results/profile_data.json")
   hotspots = query_atria_code(profile)

   # Analyze top 5 without printing everything
   for entry in hotspots[1:5]
       # Do analysis...
   end
   ```

4. **Generate summaries for users**:
   ```bash
   julia --project=. profile_analyzer.jl summary --atria-only
   ```

## File Structure

```
profiling/
├── profile_minimal.jl              # Simple profiling tool
├── profile_intensive.jl            # Intensive profiling workload
├── profile_analyzer.jl             # Advanced profiling with queries
├── test_profile_scalability.jl     # Scalability tests
├── demo_profiling_improvements.jl  # Profiling improvements demo
├── Project.toml                    # Workspace-based environment
├── README.md                       # Setup and usage instructions
└── profile_results/
    ├── profile_data.json          # Structured profile data
    ├── profile_flat.txt           # Flat profile
    ├── profile_tree.txt           # Tree profile
    └── profile_summary.txt        # Summary
```

## Common Workflows

### Workflow 1: Find Bottlenecks

```bash
# 1. Collect profile
julia --project=. profile_analyzer.jl collect

# 2. Get ATRIA hotspots
julia --project=. profile_analyzer.jl query --atria

# 3. Investigate specific areas
julia --project=. profile_analyzer.jl query --file search.jl
julia --project=. profile_analyzer.jl query --pattern distance

# 4. Get recommendations
julia --project=. profile_analyzer.jl summary --atria-only
```

### Workflow 2: Verify Optimization

```bash
# 1. Baseline profile
julia --project=. profile_analyzer.jl collect --output baseline.json

# 2. Make optimization changes
# ... edit code ...

# 3. New profile
julia --project=. profile_analyzer.jl collect --output optimized.json

# 4. Compare
julia --project=. profile_analyzer.jl compare baseline.json optimized.json

# 5. Check if hotspot improved
julia --project=. profile_analyzer.jl query --input optimized.json --pattern "your_optimized_function"
```

### Workflow 3: Focus on Specific Module

```bash
# Profile search operations only
julia --project=. profile_analyzer.jl query --file search.jl

# Profile distance calculations only
julia --project=. profile_analyzer.jl query --pattern distance

# Profile tree construction only
julia --project=. profile_analyzer.jl query --file tree.jl
```

## Troubleshooting

### No profile data collected

If you see "No profile data collected", the workload may be too fast:
- Increase number of queries in the workload
- Use larger datasets (more points/dimensions)
- Extend the profiling duration

### System code dominates profile

If system code appears at top:
- This is normal for small workloads (compilation overhead)
- Use `--atria` flag to focus on package code
- Try larger workloads to get better signal

### JSON parsing errors

If you get JSON errors:
- Ensure you're using the latest profile_analyzer.jl
- Re-collect the profile data
- Check that the file isn't corrupted

## References

- [Julia Profile module](https://docs.julialang.org/en/v1/stdlib/Profile/)
- [Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)
- [ProfileView.jl](https://github.com/timholy/ProfileView.jl) - For visual flame graphs

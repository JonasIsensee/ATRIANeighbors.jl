"""
ProfilingAnalysis.jl

A comprehensive profiling analysis tool for Julia code with support for
runtime profiling, allocation tracking, and type stability checking.

# Features
- Collect runtime profile data from any Julia workload
- Collect allocation profiles with Profile.Allocs
- Automatic categorization of hotspots by operation type
- Context-aware performance recommendations
- Save/load profiles in JSON format
- Compare profiles to track performance changes
- Type stability checking helpers

# Basic Usage

## Programmatic API

```julia
using ProfilingAnalysis

# Collect runtime profile
profile = collect_profile_data() do
    my_expensive_function()
end

# Collect allocation profile
allocs = collect_allocation_profile(sample_rate=0.1) do
    my_expensive_function()
end

# Automatic categorization
categorized = categorize_entries(profile.entries)

# Smart recommendations
recs = generate_smart_recommendations(categorized, profile.total_samples)

# Save/load
save_profile(profile, "myprofile.json")
profile2 = load_profile("myprofile2.json")

# Compare
compare_profiles(profile, profile2)
```

## CLI Usage

```bash
# Query profile
julia -m ProfilingAnalysis query --input profile.json --top 10

# Generate summary
julia -m ProfilingAnalysis summary --input profile.json

# Compare profiles
julia -m ProfilingAnalysis compare old.json new.json
```
"""
module ProfilingAnalysis

# Core structures
include("structures.jl")
export ProfileEntry, ProfileData

# Collection and I/O
include("collection.jl")
export collect_profile_data, save_profile, load_profile

# Query functions
include("query.jl")
export query_top_n, query_by_file, query_by_function, query_by_pattern,
       query_by_filter, is_system_code

# Summary and reporting
include("summary.jl")
export print_entry_table, summarize_profile, generate_recommendations

# Comparison
include("comparison.jl")
export compare_profiles

# Allocation profiling
include("allocation.jl")
export AllocationSite, AllocationProfile,
       collect_allocation_profile, format_bytes,
       print_allocation_table, summarize_allocations

# Categorization and smart recommendations
include("categorization.jl")
export categorize_entries, default_categories,
       print_categorized_summary, generate_smart_recommendations,
       analyze_allocation_patterns

# Type stability helpers
include("type_stability.jl")
export check_type_stability_simple, print_type_stability_guide

# CLI interface
include("cli.jl")
export run_cli

# Entry point for -m flag (Julia 1.11+)
# Conditionally define if @main is available
if isdefined(Base, Symbol("@main"))
    """
        main(args)

    Main entry point for CLI usage.

    This function is automatically called when the package is run with:
        julia -m ProfilingAnalysis [args...]

    Requires Julia 1.11 or later.
    """
    function main(args)
        run_cli(args)
    end
else
    # For Julia < 1.11, define main but it won't be auto-called
    """
        main(args)

    Main entry point for CLI usage.

    Note: Automatic execution via -m flag requires Julia 1.11+.
    For Julia 1.10, call this function manually or use the run_cli function.
    """
    function main(args)
        run_cli(args)
    end
end

end # module

"""
ProfilingAnalysis.jl

A generic, reusable profiling analysis tool for Julia code.

# Features
- Collect profile data from any Julia workload
- Save/load profiles in JSON format
- Query profiles by function, file, or pattern
- Generate summaries and recommendations
- Compare profiles to track performance changes

# Basic Usage

## Programmatic API

```julia
using ProfilingAnalysis

# Collect profile data
profile = collect_profile_data() do
    # Your workload here
    my_expensive_function()
end

# Save profile
save_profile(profile, "myprofile.json")

# Query top hotspots (excluding system code)
top_10 = query_top_n(profile, 10, filter_fn=e -> !is_system_code(e))

# Summarize
summarize_profile(profile)

# Compare two profiles
profile2 = load_profile("myprofile2.json")
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

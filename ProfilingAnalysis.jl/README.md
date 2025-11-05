# ProfilingAnalysis.jl

A generic, reusable profiling analysis tool for Julia code.

## Features

- 📊 Collect profile data from any Julia workload
- 💾 Save/load profiles in JSON format for later analysis
- 🔍 Query profiles by function, file, or custom patterns
- 📈 Generate summaries and performance recommendations
- 🔄 Compare profiles to track performance changes over time
- 🎯 Filter system code to focus on your application
- 🚀 Command-line interface for quick analysis

## Installation

Since this is a local package, add it to your Julia environment:

```julia
using Pkg
Pkg.develop(path="path/to/ProfilingAnalysis.jl")
```

## Usage

### Programmatic API

```julia
using ProfilingAnalysis

# Collect profile data from your workload
profile = collect_profile_data() do
    # Your workload here
    my_expensive_function()
    for i in 1:1000
        process_data(i)
    end
end

# Save profile for later analysis
save_profile(profile, "myprofile.json")

# Load previously saved profile
profile = load_profile("myprofile.json")

# Query top 10 hotspots (excluding system code)
top_10 = query_top_n(profile, 10, filter_fn=e -> !is_system_code(e))

# Find all entries related to a specific function
distance_funcs = query_by_function(profile, "distance")

# Find all entries in a specific file
file_entries = query_by_file(profile, "mymodule.jl")

# Use custom filter
high_sample_entries = query_by_filter(profile, e -> e.samples > 100)

# Generate summary report
summarize_profile(profile, top_n=20)

# Generate summary with custom filter (e.g., only your package code)
summarize_profile(profile,
    filter_fn=e -> contains(e.file, "MyPackage"),
    title="MyPackage Performance Profile"
)

# Compare two profiles to see what changed
profile_before = load_profile("before.json")
profile_after = load_profile("after.json")
compare_profiles(profile_before, profile_after, top_n=15)
```

### Custom Recommendations

You can generate custom performance recommendations based on patterns in your code:

```julia
using ProfilingAnalysis

profile = load_profile("myprofile.json")

# Define patterns and recommendations for your domain
patterns = Dict(
    "Distance Calculations" => (
        patterns = ["distance", "metric", "norm"],
        recommendations = [
            "Add @inbounds for array access",
            "Use @simd for vectorization",
            "Consider early termination for bounded searches"
        ]
    ),
    "Memory Allocations" => (
        patterns = ["alloc", "malloc", "gc"],
        recommendations = [
            "Pre-allocate arrays when possible",
            "Use in-place operations (functions ending with !)",
            "Consider using StaticArrays for small fixed-size arrays"
        ]
    )
)

# Get filtered entries
my_code = query_by_filter(profile, e -> contains(e.file, "MyPackage"))

# Generate recommendations
generate_recommendations(my_code, patterns)
```

### Command-Line Interface

The package can be used directly from the command line:

```bash
# Query top 10 hotspots from a profile
julia -m ProfilingAnalysis query --input profile.json --top 10

# Find all distance-related functions
julia -m ProfilingAnalysis query --input profile.json --pattern distance

# Filter by file
julia -m ProfilingAnalysis query --input profile.json --file mymodule.jl

# Generate summary report
julia -m ProfilingAnalysis summary --input profile.json --top 20

# Compare two profiles
julia -m ProfilingAnalysis compare before.json after.json --top 15

# Get help
julia -m ProfilingAnalysis help
```

## API Reference

### Data Structures

- **`ProfileEntry`**: Represents a single function/location with samples and percentage
- **`ProfileData`**: Complete profile dataset with timestamp and metadata

### Collection & I/O

- **`collect_profile_data(workload_fn; metadata=...)`**: Collect profile by running workload
- **`save_profile(profile, filename)`**: Save profile to JSON
- **`load_profile(filename)`**: Load profile from JSON

### Query Functions

- **`query_top_n(profile, n; filter_fn=nothing)`**: Get top N hotspots
- **`query_by_file(profile, pattern)`**: Filter by file pattern
- **`query_by_function(profile, pattern)`**: Filter by function pattern
- **`query_by_pattern(profile, pattern)`**: Filter by any pattern (file or function)
- **`query_by_filter(profile, filter_fn)`**: Apply custom filter function
- **`is_system_code(entry; system_patterns=...)`**: Check if entry is system code

### Summary & Reporting

- **`print_entry_table(entries; max_width=120)`**: Print formatted table
- **`summarize_profile(profile; filter_fn=..., top_n=20, title=...)`**: Generate summary
- **`generate_recommendations(entries, patterns)`**: Generate custom recommendations

### Comparison

- **`compare_profiles(profile1, profile2; top_n=20)`**: Compare two profiles

## Example: Profiling a Package

```julia
using ProfilingAnalysis
using MyPackage

# Define your workload
function benchmark_workload()
    # Run representative operations
    for i in 1:100
        result = MyPackage.expensive_operation(i)
    end
end

# Collect profile
profile = collect_profile_data(
    benchmark_workload,
    metadata=Dict(
        "description" => "MyPackage performance test",
        "version" => "1.0.0"
    )
)

# Save it
save_profile(profile, "profile_results/mypackage_profile.json")

# Analyze only MyPackage code (exclude dependencies and system code)
my_code = query_by_filter(profile, e -> contains(e.file, "MyPackage"))

println("MyPackage uses $(sum(e.samples for e in my_code)) / $(profile.total_samples) samples")
println("($(round(100 * sum(e.samples for e in my_code) / profile.total_samples, digits=1))%)")

# Show top hotspots in MyPackage
print_entry_table(my_code[1:min(20, length(my_code))])
```

## Requirements

- Julia 1.10 or later (for @main support, use Julia 1.11+)
- JSON3.jl

## License

MIT License

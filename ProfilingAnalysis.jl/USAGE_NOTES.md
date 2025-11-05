# ProfilingAnalysis.jl Usage Notes

## Package Structure

The ProfilingAnalysis.jl package has been successfully refactored into a self-contained, generic profiling tool with the following structure:

```
ProfilingAnalysis.jl/
├── Project.toml                    # Package metadata and dependencies
├── README.md                       # User documentation
├── USAGE_NOTES.md                  # This file
└── src/
    ├── ProfilingAnalysis.jl        # Main module with @main entry point
    ├── structures.jl               # Core data structures (ProfileEntry, ProfileData)
    ├── collection.jl               # Profile collection and I/O (collect, save, load)
    ├── query.jl                    # Query functions (top_n, by_file, by_function, etc.)
    ├── summary.jl                  # Summary and reporting functions
    ├── comparison.jl               # Profile comparison functions
    └── cli.jl                      # CLI argument parsing and commands
```

## Key Features

### 1. Generic and Reusable
- No ATRIANeighbors-specific code in the package
- Works with any Julia codebase
- Configurable workload functions
- Customizable filter functions and patterns

### 2. Modern Julia Features
- Uses `@main` macro for entry point (Julia 1.11+)
- Can be invoked with `julia -m ProfilingAnalysis`
- Also works as a regular Julia package

### 3. Programmatic and CLI Interface
- Full programmatic API for integration into other tools
- Command-line interface for quick ad-hoc analysis
- JSON-based profile storage for portability

## Integration with ATRIANeighbors

The `profile_analyzer.jl` script in the ATRIANeighbors repository has been updated to:

1. **Import ProfilingAnalysis**: Adds the package to the load path and imports it
2. **Define ATRIA-specific workload**: `run_atria_workload()` function
3. **Define ATRIA-specific queries**: `query_atria_code()` helper
4. **Define ATRIA-specific recommendations**: Pattern-based recommendations for ATRIA code
5. **Provide ATRIA-specific CLI**: Wraps ProfilingAnalysis with ATRIA context

## Testing the Package

### Quick Validation

To verify the package works correctly, you can do a simple test:

```julia
# Start Julia with the package
julia --project=ProfilingAnalysis.jl

# In the REPL:
using ProfilingAnalysis

# Test basic functionality
profile = collect_profile_data() do
    # Simple workload
    sum(rand(1000, 1000))
end

println("Collected $(profile.total_samples) samples")
println("Found $(length(profile.entries)) unique locations")

# Test queries
top_5 = query_top_n(profile, 5)
println("Top 5 hotspots:")
for (i, entry) in enumerate(top_5)
    println("  $i. $(entry.func) ($(entry.samples) samples)")
end
```

### Test with ATRIANeighbors

```bash
# From the ATRIANeighbors.jl directory

# Collect profile data
julia --project=. profile_analyzer.jl collect

# Query the profile
julia --project=. profile_analyzer.jl query --top 10
julia --project=. profile_analyzer.jl query --atria

# Generate summary
julia --project=. profile_analyzer.jl summary --atria-only
```

## Usage Examples

### Programmatic Usage

#### Basic Profiling

```julia
using ProfilingAnalysis

# Profile your workload
profile = collect_profile_data() do
    # Your expensive computation here
    result = my_function(data)
end

# Save for later
save_profile(profile, "my_profile.json")
```

#### Querying Profiles

```julia
# Load a saved profile
profile = load_profile("my_profile.json")

# Get top 20 hotspots (excluding system code)
top_20 = query_top_n(profile, 20,
    filter_fn = e -> !is_system_code(e))

# Find all entries in your package
my_code = query_by_filter(profile,
    e -> contains(e.file, "MyPackage"))

# Find specific functions
search_funcs = query_by_function(profile, "search")

# Find by file pattern
main_code = query_by_file(profile, "main.jl")
```

#### Custom Analysis

```julia
# Calculate percentage of time in your code
my_code = query_by_filter(profile,
    e -> contains(e.file, "MyPackage"))

my_samples = sum(e.samples for e in my_code)
my_percentage = 100.0 * my_samples / profile.total_samples

println("MyPackage: $my_samples / $(profile.total_samples) samples")
println("($my_percentage%)")

# Show top hotspots
print_entry_table(my_code[1:min(10, length(my_code))])
```

#### Custom Recommendations

```julia
# Define domain-specific patterns
patterns = Dict(
    "I/O Operations" => (
        patterns = ["read", "write", "io", "file"],
        recommendations = [
            "Use buffered I/O for small operations",
            "Consider memory-mapped files for large data",
            "Batch I/O operations when possible"
        ]
    ),
    "String Processing" => (
        patterns = ["string", "parse", "format"],
        recommendations = [
            "Use string interpolation over concatenation",
            "Pre-allocate IOBuffer for building strings",
            "Consider using views to avoid allocations"
        ]
    )
)

my_code = query_by_filter(profile, e -> contains(e.file, "MyPackage"))
generate_recommendations(my_code, patterns)
```

### CLI Usage

```bash
# Query top hotspots
julia -m ProfilingAnalysis query --input profile.json --top 10

# Filter by pattern
julia -m ProfilingAnalysis query --input profile.json --pattern "search"

# Generate summary
julia -m ProfilingAnalysis summary --input profile.json --top 20

# Compare two profiles
julia -m ProfilingAnalysis compare before.json after.json
```

## Extending the Package

### Adding Custom Query Functions

```julia
using ProfilingAnalysis

# Define custom query function
function query_high_impact(profile::ProfileData, threshold_pct::Float64)
    return query_by_filter(profile,
        e -> e.percentage >= threshold_pct)
end

# Use it
high_impact = query_high_impact(profile, 5.0)  # Functions using ≥5% time
```

### Custom System Code Patterns

```julia
# Define custom patterns for what you consider "system" code
my_system_patterns = [
    "libc", "Base.jl", "julia-release",
    "ThirdPartyLib"  # Add third-party libraries you want to filter out
]

# Use with queries
user_code = query_top_n(profile, 20,
    filter_fn = e -> !is_system_code(e, system_patterns=my_system_patterns))
```

## Migration Notes

### From Old profile_analyzer.jl

The old `profile_analyzer.jl` (747 lines) has been refactored into:

1. **ProfilingAnalysis.jl** (generic package, ~350 lines total)
   - Reusable for any Julia project
   - No domain-specific code
   - Clean separation of concerns

2. **profile_analyzer.jl** (ATRIA-specific wrapper, ~396 lines)
   - ATRIA workload definition
   - ATRIA-specific queries and recommendations
   - Uses ProfilingAnalysis as a library

### Benefits of Refactoring

1. **Reusability**: ProfilingAnalysis can be used for other Julia projects
2. **Maintainability**: Clear separation between generic and specific code
3. **Testability**: Each module can be tested independently
4. **Extensibility**: Easy to add new features to either component
5. **Modern**: Uses Julia 1.11+ features like `@main`

## Dependencies

The package requires:
- Julia 1.10+ (1.11+ recommended for `@main` support)
- Profile (standard library)
- Statistics (standard library)
- Dates (standard library)
- Printf (standard library)
- JSON.jl (external dependency)

## Future Enhancements

Possible future additions:
- Flamegraph generation
- HTML report generation
- Support for remote profiling
- Integration with BenchmarkTools.jl
- Automatic regression detection
- Performance trend tracking

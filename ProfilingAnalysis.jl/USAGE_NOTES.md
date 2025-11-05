# ProfilingAnalysis.jl Usage Notes

## Quick Start

### From ATRIANeighbors
```bash
# Collect profile
julia --project=. profile_analyzer.jl collect

# Query results
julia --project=. profile_analyzer.jl query --top 10
julia --project=. profile_analyzer.jl query --atria

# Generate summary
julia --project=. profile_analyzer.jl summary --atria-only
```

## Integration with ATRIANeighbors

The `profile_analyzer.jl` script wraps ProfilingAnalysis with ATRIA-specific:
1. Workload definition (`run_atria_workload()`)
2. Query helpers (`query_atria_code()`)
3. Pattern-based recommendations for ATRIA code

## Dependencies

- Julia 1.10+ (1.11+ recommended for `@main` support)
- JSON.jl

See README.md for detailed API documentation and examples.

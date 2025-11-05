"""
summary.jl

Summary and reporting functions for profile analysis.
"""

using Printf

"""
    print_entry_table(entries::Vector{ProfileEntry}; max_width=120)

Print entries in a formatted table.
"""
function print_entry_table(entries::Vector{ProfileEntry}; max_width=120)
    if isempty(entries)
        println("No entries found.")
        return
    end

    println(@sprintf("%-5s %-10s %-8s %-s", "Rank", "Samples", "% Total", "Function @ File:Line"))
    println("-" ^ max_width)

    for (idx, entry) in enumerate(entries)
        # Format location
        location = "$(entry.func) @ $(entry.file):$(entry.line)"
        if length(location) > max_width - 30
            location = location[1:max_width-33] * "..."
        end

        println(@sprintf("%-5d %-10d %-8.2f %s",
            idx, entry.samples, entry.percentage, location))
    end
end

"""
    summarize_profile(profile::ProfileData;
                      filter_fn=nothing,
                      top_n=20,
                      title="Profile Summary")

Generate a summary of profile data.

# Arguments
- `profile`: Profile data to summarize
- `filter_fn`: Optional filter function to apply (e.g., to show only specific code)
- `top_n`: Number of top entries to show
- `title`: Title for the summary section
"""
function summarize_profile(profile::ProfileData;
                           filter_fn=nothing,
                           top_n=20,
                           title="Profile Summary")
    println("=" ^ 80)
    println(title)
    println("=" ^ 80)
    println("Timestamp: ", profile.timestamp)
    println("Total samples: ", profile.total_samples)
    println("Unique locations: ", length(profile.entries))
    println()

    # Apply filter if provided
    entries = profile.entries
    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
        total_filtered = sum(e.samples for e in entries)
        pct_filtered = 100.0 * total_filtered / profile.total_samples
        println("Filtered samples: $total_filtered / $(profile.total_samples) ($(round(pct_filtered, digits=2))%)")
        println()
    end

    # Show top entries
    println("=" ^ 80)
    println("Top $top_n Hotspots")
    println("=" ^ 80)
    println()

    display_count = min(top_n, length(entries))
    print_entry_table(entries[1:display_count])
    println()
end

"""
    generate_recommendations(entries::Vector{ProfileEntry}, patterns::Dict{String, Vector{String}})

Generate performance recommendations based on hotspots and user-defined patterns.

# Arguments
- `entries`: Profile entries to analyze
- `patterns`: Dict mapping category names to lists of pattern strings and recommendations

# Example
```julia
patterns = Dict(
    "Distance Calculations" => (
        patterns = ["distance", "metric"],
        recommendations = [
            "Add @inbounds for array access",
            "Use @simd for vectorization",
            "Consider early termination"
        ]
    ),
    "Search Operations" => (
        patterns = ["search", "knn"],
        recommendations = [
            "Optimize priority queue operations",
            "Reduce allocations in search loop"
        ]
    )
)
generate_recommendations(entries, patterns)
```
"""
function generate_recommendations(entries::Vector{ProfileEntry},
                                  patterns::Dict{String, T} where T)
    println("=" ^ 80)
    println("Performance Recommendations")
    println("=" ^ 80)
    println()

    for (category, config) in patterns
        # Check if any entries match the patterns
        pattern_list = config[:patterns]
        has_match = any(entry ->
            any(p -> contains(lowercase(entry.func), lowercase(p)) ||
                    contains(lowercase(entry.file), lowercase(p)),
                pattern_list),
            entries
        )

        if has_match
            println("🔥 $(uppercase(category)) IN HOT PATH:")
            for rec in config[:recommendations]
                println("   • $rec")
            end
            println()
        end
    end
end

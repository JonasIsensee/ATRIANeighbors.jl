"""
comparison.jl

Functions for comparing profile datasets.
"""

using Printf

"""
    compare_profiles(profile1::ProfileData, profile2::ProfileData; top_n=20)

Compare two profile datasets to identify performance changes.

# Arguments
- `profile1`: First profile (baseline)
- `profile2`: Second profile (comparison)
- `top_n`: Number of top changes to display

# Returns
- Prints comparison summary
"""
function compare_profiles(profile1::ProfileData, profile2::ProfileData; top_n=20)
    println("=" ^ 80)
    println("Profile Comparison")
    println("=" ^ 80)
    println()
    println("Profile 1: $(profile1.timestamp) ($(profile1.total_samples) samples)")
    println("Profile 2: $(profile2.timestamp) ($(profile2.total_samples) samples)")
    println()

    # Create lookup maps
    map1 = Dict((e.func, e.file, e.line) => e for e in profile1.entries)
    map2 = Dict((e.func, e.file, e.line) => e for e in profile2.entries)

    # Find all unique keys
    all_keys = union(keys(map1), keys(map2))

    # Calculate differences
    differences = []
    for key in all_keys
        e1 = get(map1, key, nothing)
        e2 = get(map2, key, nothing)

        samples1 = e1 === nothing ? 0 : e1.samples
        samples2 = e2 === nothing ? 0 : e2.samples

        pct1 = e1 === nothing ? 0.0 : e1.percentage
        pct2 = e2 === nothing ? 0.0 : e2.percentage

        diff = samples2 - samples1
        pct_diff = pct2 - pct1

        if abs(diff) > 0
            entry = e1 !== nothing ? e1 : e2
            push!(differences, (entry, diff, pct_diff))
        end
    end

    # Sort by absolute difference
    sort!(differences, by=x -> abs(x[2]), rev=true)

    println("=" ^ 80)
    println("Top $top_n Changes (by absolute sample difference)")
    println("=" ^ 80)
    println()
    println(@sprintf("%-5s %-10s %-10s %-s", "Rank", "Δ Samples", "Δ %", "Function @ File:Line"))
    println("-" ^ 80)

    for (idx, (entry, diff, pct_diff)) in enumerate(differences[1:min(top_n, length(differences))])
        location = "$(entry.func) @ $(entry.file):$(entry.line)"
        if length(location) > 60
            location = location[1:57] * "..."
        end

        sign = diff > 0 ? "+" : ""
        println(@sprintf("%-5d %s%-9d %s%-9.2f %s",
            idx, sign, diff, sign, pct_diff, location))
    end
    println()

    # Summary statistics
    total_increase = sum(d[2] for d in differences if d[2] > 0; init=0)
    total_decrease = sum(d[2] for d in differences if d[2] < 0; init=0)

    println("Summary:")
    println("  Total sample changes: $total_increase (increases), $total_decrease (decreases)")
    println()
end

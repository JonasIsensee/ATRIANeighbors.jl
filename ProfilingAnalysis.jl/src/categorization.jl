"""
categorization.jl

Automatic categorization of hotspots by operation type and
context-aware recommendation generation.
"""

using Printf

"""
    categorize_entries(entries::Vector{ProfileEntry};
                      categories=default_categories()) -> Dict{String, Vector{ProfileEntry}}

Automatically categorize profile entries by operation type.

# Arguments
- `entries`: Profile entries to categorize
- `categories`: Dict mapping category names to keyword patterns

# Returns
- Dict mapping category names to matching entries

# Example
```julia
categorized = categorize_entries(profile.entries)
for (cat, entries) in categorized
    println("\$(cat): \$(length(entries)) entries")
end
```
"""
function categorize_entries(entries::Vector{ProfileEntry};
                           categories=default_categories())
    result = Dict{String, Vector{ProfileEntry}}()

    # Initialize empty vectors for each category
    for cat in keys(categories)
        result[cat] = ProfileEntry[]
    end
    result["other"] = ProfileEntry[]

    for entry in entries
        func_lower = lowercase(entry.func)
        file_lower = lowercase(entry.file)

        # Try to match against each category
        matched = false
        for (cat_name, patterns) in categories
            if any(p -> contains(func_lower, lowercase(p)) ||  contains(file_lower, lowercase(p)), patterns)
                push!(result[cat_name], entry)
                matched = true
                break  # Only assign to first matching category
            end
        end

        # If no match, put in "other"
        if !matched
            push!(result["other"], entry)
        end
    end

    return result
end

"""
    default_categories() -> Dict{String, Vector{String}}

Default categorization patterns for common operations.
"""
function default_categories()
    return Dict(
        "distance_calculation" => ["distance", "metric", "norm", "euclidean"],
        "heap_operations" => ["heap", "sortedneighbor", "insert", "priority", "heapify"],
        "tree_construction" => ["assign_points", "partition", "build_tree", "cluster"],
        "search_operations" => ["knn", "search", "range", "count_range", "_search"],
        "point_access" => ["getpoint", "point_set"],
    )
end

"""
    print_categorized_summary(categorized::Dict{String, Vector{ProfileEntry}},
                             total_samples::Int;
                             min_percentage=5.0)

Print summary of categorized hotspots.

# Arguments
- `categorized`: Result from categorize_entries
- `total_samples`: Total number of profile samples
- `min_percentage`: Minimum percentage to display category (default 5%)
"""
function print_categorized_summary(categorized::Dict{String, Vector{ProfileEntry}},
                                  total_samples::Int;
                                  min_percentage=5.0)
    println("=" ^ 80)
    println("Categorized Hotspots")
    println("=" ^ 80)
    println()

    # Calculate percentages and sort by importance
    cat_summary = []
    for (cat, entries) in categorized
        if !isempty(entries)
            cat_samples = sum(e.samples for e in entries)
            cat_pct = 100.0 * cat_samples / total_samples
            if cat_pct >= min_percentage
                push!(cat_summary, (cat, entries, cat_samples, cat_pct))
            end
        end
    end

    # Sort by percentage (descending)
    sort!(cat_summary, by=x->x[4], rev=true)

    for (cat, entries, samples, pct) in cat_summary
        cat_display = replace(cat, "_" => " ") |> titlecase
        println("$cat_display: $samples samples ($(round(pct, digits=1))%)")

        # Show top 3 entries in this category
        for entry in entries[1:min(3, length(entries))]
            file_short = basename(entry.file)
            println("  • $(entry.func) @ $file_short:$(entry.line) - $(entry.samples) samples")
        end
        println()
    end
end

"""
    titlecase(s::String) -> String

Convert string to title case.
"""
function titlecase(s::String)
    return join([uppercasefirst(word) for word in split(s)], " ")
end

"""
    generate_smart_recommendations(categorized::Dict{String, Vector{ProfileEntry}},
                                  total_samples::Int;
                                  threshold_percentages=default_thresholds())

Generate context-aware recommendations based on categorized hotspots.

# Arguments
- `categorized`: Result from categorize_entries
- `total_samples`: Total profile samples
- `threshold_percentages`: Dict mapping categories to percentage thresholds

# Returns
- Vector of recommendation strings
"""
function generate_smart_recommendations(categorized::Dict{String, Vector{ProfileEntry}},
                                       total_samples::Int;
                                       threshold_percentages=default_thresholds())
    recommendations = String[]

    for (cat, entries) in categorized
        if isempty(entries)
            continue
        end

        cat_samples = sum(e.samples for e in entries)
        cat_pct = 100.0 * cat_samples / total_samples
        threshold = get(threshold_percentages, cat, 10.0)

        if cat_pct >= threshold
            append!(recommendations, get_recommendations_for_category(cat, cat_pct))
        end
    end

    if isempty(recommendations)
        push!(recommendations, "✅ No major bottlenecks detected. Code appears well-optimized.")
        push!(recommendations, "💡 Consider micro-optimizations: @inbounds, @simd, type annotations")
    end

    return recommendations
end

"""
    default_thresholds() -> Dict{String, Float64}

Default percentage thresholds for generating recommendations.
"""
function default_thresholds()
    return Dict(
        "distance_calculation" => 15.0,
        "heap_operations" => 10.0,
        "search_operations" => 20.0,
        "tree_construction" => 15.0,
        "point_access" => 5.0,
    )
end

"""
    get_recommendations_for_category(category::String, percentage::Float64) -> Vector{String}

Get specific recommendations for a category.
"""
function get_recommendations_for_category(category::String, percentage::Float64)
    recs = String[]
    pct_str = round(percentage, digits=1)

    if category == "distance_calculation"
        push!(recs, "🔥 Distance calculations are a hotspot ($pct_str% of runtime)")
        push!(recs, "   → Add @inbounds to array accesses (after verifying bounds)")
        push!(recs, "   → Use @simd for vectorization in inner loops")
        push!(recs, "   → Optimize early termination in partial distance calculation")
        push!(recs, "   → Ensure @inline on small distance functions")

    elseif category == "heap_operations"
        push!(recs, "📦 Heap operations are expensive ($pct_str% of runtime)")
        push!(recs, "   → Consider StaticArrays for small fixed k values")
        push!(recs, "   → Reduce allocations in SortedNeighborTable operations")
        push!(recs, "   → Profile insert!/remove! operations specifically")

    elseif category == "search_operations"
        push!(recs, "🔍 Search operations dominate ($pct_str% of runtime)")
        push!(recs, "   → Optimize priority queue operations")
        push!(recs, "   → Use @inbounds for permutation table access")
        push!(recs, "   → Minimize allocations in search loop")
        push!(recs, "   → Cache frequently accessed cluster data")

    elseif category == "tree_construction"
        push!(recs, "🏗️  Tree construction is slow ($pct_str% of runtime)")
        push!(recs, "   → Optimize assign_points_to_centers! partition algorithm")
        push!(recs, "   → Pre-allocate temporary arrays")
        push!(recs, "   → Improve memory access patterns for cache efficiency")

    elseif category == "point_access"
        push!(recs, "📍 Point access overhead ($pct_str% of runtime)")
        push!(recs, "   → Ensure getpoint() is type-stable and inlined")
        push!(recs, "   → Use @inbounds where bounds checking is proven safe")
        push!(recs, "   → Consider caching frequently accessed points")
    end

    return recs
end

"""
    analyze_allocation_patterns(sites::Vector{AllocationSite};
                                package_patterns=["ATRIANeighbors", "tree.jl", "search.jl",
                                                "structures.jl", "metrics.jl", "pointsets.jl"])

Analyze allocation sites and provide recommendations.

# Returns
- Vector of recommendation strings
"""
function analyze_allocation_patterns(sites::Vector{AllocationSite};
                                    package_patterns=["ATRIANeighbors", "tree.jl", "search.jl",
                                                     "structures.jl", "metrics.jl", "pointsets.jl"])
    recommendations = String[]

    if isempty(sites)
        push!(recommendations, "✅ No significant allocations detected")
        return recommendations
    end

    total_bytes = sum(s.total_bytes for s in sites)
    total_count = sum(s.count for s in sites)

    # Filter package-specific allocations
    package_sites = filter(s -> any(contains(s.file, p) for p in package_patterns), sites)

    if !isempty(package_sites)
        package_bytes = sum(s.total_bytes for s in package_sites)
        package_pct = 100.0 * package_bytes / total_bytes

        if package_pct > 50
            push!(recommendations, "⚠️  Package code allocates $(round(package_pct, digits=1))% of total memory")
            push!(recommendations, "   → Focus optimization on top package allocation sites")
        end
    end

    # Check for many small allocations
    avg_bytes = total_bytes / total_count
    if avg_bytes < 1000  # Less than 1KB average
        push!(recommendations, "📦 Many small allocations detected (avg $(format_bytes(Int(round(avg_bytes)))))")
        push!(recommendations, "   → Consider object pooling or pre-allocation strategies")
        push!(recommendations, "   → Look for allocations in hot inner loops")
    end

    # Check for large allocations
    large_sites = filter(s -> s.total_bytes > 1_000_000, sites)  # >1MB
    if !isempty(large_sites)
        push!(recommendations, "💾 Large allocation sites detected:")
        for site in large_sites[1:min(3, length(large_sites))]
            push!(recommendations, "   → $(site.func) @ $(basename(site.file)):$(site.line) - $(format_bytes(site.total_bytes))")
        end
    end

    if isempty(recommendations)
        push!(recommendations, "✅ Allocation profile looks reasonable")
    end

    return recommendations
end

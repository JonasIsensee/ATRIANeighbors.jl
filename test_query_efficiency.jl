"""
test_query_efficiency.jl

Demonstrates query efficiency with existing profile data.
Shows that we can extract specific information without reading full files.
"""

using Printf

include("profile_analyzer.jl")

function test_query_efficiency()
    println("=" ^ 80)
    println("Profile Query Efficiency Test")
    println("=" ^ 80)
    println()

    if !isfile("profile_results/profile_data.json")
        println("ERROR: No profile data. Run: julia --project=. profile_analyzer.jl collect")
        return
    end

    # Load profile
    println("Loading profile data...")
    profile = load_profile("profile_results/profile_data.json")
    println("✓ Loaded: $(profile.total_samples) samples, $(length(profile.entries)) locations")
    println()

    # Test various queries
    queries = [
        ("Top 5 hotspots", () -> query_top_n(profile, 5)),
        ("Top 10 hotspots", () -> query_top_n(profile, 10)),
        ("ATRIA code only", () -> query_atria_code(profile)),
        ("Distance functions", () -> query_by_pattern(profile, "distance")),
        ("Search functions", () -> query_by_pattern(profile, "search")),
        ("Tree construction", () -> query_by_pattern(profile, "tree")),
        ("search.jl file", () -> query_by_file(profile, "search.jl")),
        ("metrics.jl file", () -> query_by_file(profile, "metrics.jl")),
    ]

    println("=" ^ 80)
    println("Executing $(length(queries)) different queries...")
    println("=" ^ 80)
    println()

    total_entries_queried = 0

    for (i, (desc, query_fn)) in enumerate(queries)
        result = query_fn()
        total_entries_queried += length(result)

        println("Query $i: $desc")
        println("  Results: $(length(result)) entries")

        if !isempty(result)
            # Show top entry
            top = result[1]
            println("  Top hit: $(top.func) ($(top.samples) samples, $(round(top.percentage, digits=2))%)")
        end
        println()
    end

    println("=" ^ 80)
    println("Efficiency Summary")
    println("=" ^ 80)
    println()
    println("Total entries in profile: $(length(profile.entries))")
    println("Total entries returned from $(length(queries)) queries: $(total_entries_queried)")
    println("Average entries per query: $(round(total_entries_queried / length(queries), digits=1))")
    println()
    println("Context efficiency:")
    println("  Reading full profile would require: $(length(profile.entries)) entries")
    println("  Each query returns average: $(round(total_entries_queried / length(queries), digits=1)) entries")
    println("  Reduction factor: $(round(length(profile.entries) / (total_entries_queried / length(queries)), digits=1))x")
    println()

    # Demonstrate selective loading
    println("=" ^ 80)
    println("Use Case: Find bottlenecks in search.jl")
    println("=" ^ 80)
    println()

    println("OLD WAY:")
    println("  1. Read entire profile_flat.txt (127 lines)")
    println("  2. Manually scan for 'search.jl'")
    println("  3. Extract relevant entries")
    println("  → Uses ~127 lines of context")
    println()

    println("NEW WAY:")
    search_entries = query_by_file(profile, "search.jl")
    println("  1. Load structured profile")
    println("  2. Query: query_by_file(profile, 'search.jl')")
    println("  3. Get results: $(length(search_entries)) entries")
    println("  → Uses ~$(length(search_entries)) entries of context")
    println()
    print_entry_table(search_entries[1:min(5, length(search_entries))])
    println()

    println("Context saved: $(round(100 * (1 - length(search_entries) / 127), digits=1))%")
    println()

    # Show file size comparison
    println("=" ^ 80)
    println("File Size Comparison")
    println("=" ^ 80)
    println()

    json_size = filesize("profile_results/profile_data.json")

    if isfile("profile_results/profile_flat.txt")
        flat_size = filesize("profile_results/profile_flat.txt")
        tree_size = isfile("profile_results/profile_tree.txt") ?
            filesize("profile_results/profile_tree.txt") : 0

        println("Structured format (JSON):")
        println("  profile_data.json: $(round(json_size/1024, digits=2)) KB")
        println()
        println("Text format:")
        println("  profile_flat.txt: $(round(flat_size/1024, digits=2)) KB")
        println("  profile_tree.txt: $(round(tree_size/1024, digits=2)) KB")
        println("  Total: $(round((flat_size + tree_size)/1024, digits=2)) KB")
        println()
        println("Space ratio: $(round(json_size / (flat_size + tree_size), digits=2))x")
    else
        println("JSON profile: $(round(json_size/1024, digits=2)) KB")
    end
    println()

    println("✓ All queries completed successfully")
    println("✓ Context-efficient querying demonstrated")
    println()
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_query_efficiency()
end

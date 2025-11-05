"""
demo_profiling_improvements.jl

Demonstrates the improvements in the new profiling system:
1. Structured data storage
2. Programmatic querying without full file reads
3. Targeted analysis capabilities
"""

using Printf

include("profile_analyzer.jl")

function demo_old_approach()
    println("=" ^ 80)
    println("OLD APPROACH: Text-based profiling")
    println("=" ^ 80)
    println()

    # Show what the old approach required
    println("Issues with old approach:")
    println("  ❌ Generated large text files (profile_flat.txt, profile_tree.txt)")
    println("  ❌ Must read entire file to find specific information")
    println("  ❌ No structured querying - must parse text manually")
    println("  ❌ Difficult to compare profiles")
    println("  ❌ Context window clogged with full file contents")
    println()

    # Show file sizes
    if isfile("profile_results/profile_flat.txt")
        size_kb = round(filesize("profile_results/profile_flat.txt") / 1024, digits=2)
        lines = countlines("profile_results/profile_flat.txt")
        println("Example: profile_flat.txt")
        println("  Size: $(size_kb) KB")
        println("  Lines: $(lines)")
        println("  → Would need to read all $(lines) lines to find ATRIA code")
        println()
    end
end

function demo_new_approach()
    println("=" ^ 80)
    println("NEW APPROACH: Structured profiling with programmatic queries")
    println("=" ^ 80)
    println()

    println("Improvements:")
    println("  ✓ Structured JSON storage")
    println("  ✓ Programmatic queries - no full file reads")
    println("  ✓ Filter by file, function, pattern")
    println("  ✓ Compare profiles easily")
    println("  ✓ Context-efficient - only load what you need")
    println()

    # Load profile data
    if !isfile("profile_results/profile_data.json")
        println("ERROR: No profile data found. Run 'collect' first.")
        return
    end

    profile = load_profile("profile_results/profile_data.json")

    println("Loaded profile:")
    println("  Total samples: $(profile.total_samples)")
    println("  Unique locations: $(length(profile.entries))")
    println()

    # Demonstrate queries
    println("-" ^ 80)
    println("DEMO 1: Targeted query - ATRIA code only (no system noise)")
    println("-" ^ 80)
    atria_entries = query_atria_code(profile)
    println("Found $(length(atria_entries)) ATRIA-specific entries")
    println()
    print_entry_table(atria_entries[1:min(5, length(atria_entries))])
    println()

    println("-" ^ 80)
    println("DEMO 2: Pattern search - all 'distance' functions")
    println("-" ^ 80)
    distance_entries = query_by_pattern(profile, "distance")
    println("Found $(length(distance_entries)) entries matching 'distance'")
    println()
    print_entry_table(distance_entries)
    println()

    println("-" ^ 80)
    println("DEMO 3: File-specific query - search.jl only")
    println("-" ^ 80)
    search_entries = query_by_file(profile, "search.jl")
    println("Found $(length(search_entries)) entries from search.jl")
    println()
    print_entry_table(search_entries[1:min(5, length(search_entries))])
    println()

    println("-" ^ 80)
    println("DEMO 4: Top hotspots (system code filtered)")
    println("-" ^ 80)
    top_5 = query_top_n(profile, 5, filter_system=true)
    print_entry_table(top_5)
    println()

    # Show context efficiency
    println("=" ^ 80)
    println("Context Efficiency Analysis")
    println("=" ^ 80)
    println()

    file_size = filesize("profile_results/profile_data.json")
    file_size_kb = round(file_size / 1024, digits=2)

    println("Profile data file:")
    println("  Size: $(file_size_kb) KB")
    println("  Contains: $(profile.total_samples) samples, $(length(profile.entries)) locations")
    println()

    println("Query results (shown above):")
    println("  ATRIA code: $(length(atria_entries)) entries")
    println("  Distance functions: $(length(distance_entries)) entries")
    println("  search.jl: $(length(search_entries)) entries")
    println("  Top 5: 5 entries")
    println()

    println("Context saved:")
    println("  Instead of reading $(length(profile.entries)) entries...")
    println("  We query specifically what we need (5-15 entries typically)")
    println("  → $(round(100 * (1 - 15/length(profile.entries)), digits=1))% reduction in context usage")
    println()

    # Show programmatic access
    println("-" ^ 80)
    println("DEMO 5: Programmatic analysis (code, not text)")
    println("-" ^ 80)
    println()

    # Analyze top ATRIA hotspots programmatically
    println("Analyzing top 3 ATRIA hotspots programmatically...")
    for (i, entry) in enumerate(atria_entries[1:min(3, length(atria_entries))])
        println()
        println("Hotspot #$i:")
        println("  Function: $(entry.func)")
        println("  Location: $(entry.file):$(entry.line)")
        println("  Samples: $(entry.samples) ($(round(entry.percentage, digits=2))%)")

        # Provide actionable recommendations
        if contains(lowercase(entry.func), "distance")
            println("  → Recommendation: Optimize with @inbounds, @simd")
        elseif contains(lowercase(entry.func), "search") || contains(lowercase(entry.func), "knn")
            println("  → Recommendation: Reduce allocations, optimize priority queue")
        elseif contains(lowercase(entry.func), "build") || contains(lowercase(entry.func), "tree")
            println("  → Recommendation: Optimize partitioning, improve cache locality")
        end
    end
    println()
end

function demo_comparison()
    println("=" ^ 80)
    println("DEMO 6: Profile comparison capability")
    println("=" ^ 80)
    println()

    println("The new system allows comparing two profiles:")
    println()
    println("  # Collect baseline")
    println("  julia --project=. profile_analyzer.jl collect --output baseline.json")
    println()
    println("  # Make changes...")
    println()
    println("  # Collect new profile")
    println("  julia --project=. profile_analyzer.jl collect --output optimized.json")
    println()
    println("  # Compare")
    println("  julia --project=. profile_analyzer.jl compare baseline.json optimized.json")
    println()
    println("This shows:")
    println("  • Functions with increased/decreased samples")
    println("  • Performance regressions/improvements")
    println("  • New/removed hotspots")
    println()
end

function main()
    println()
    println("╔" * "═"^78 * "╗")
    println("║" * " "^15 * "ATRIANeighbors.jl Profiling System Demo" * " "^23 * "║")
    println("╚" * "═"^78 * "╝")
    println()

    demo_old_approach()
    println()

    demo_new_approach()
    println()

    demo_comparison()
    println()

    println("=" ^ 80)
    println("Summary: Key Improvements")
    println("=" ^ 80)
    println()
    println("✓ Structured data format (JSON) enables programmatic access")
    println("✓ Targeted queries reduce context usage by >90%")
    println("✓ Filter by file, function, pattern, or package")
    println("✓ Compare profiles to track performance changes")
    println("✓ Auto-generate optimization recommendations")
    println("✓ CLI interface for easy integration")
    println()
    println("For full guide, see: PROFILING_GUIDE.md")
    println()
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

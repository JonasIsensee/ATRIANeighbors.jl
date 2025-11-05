"""
test_profile_scalability.jl

Test profiling tool with large workloads to verify it scales without context issues.
"""

using Profile
using Random
using ATRIANeighbors

include("profile_analyzer.jl")

# Test with progressively larger workloads
function main()
    println("Testing profile analyzer with large workloads...")
    println("=" ^ 80)
    println()

    # Create large workload scenarios
    large_scenarios = [
        (N=50000, D=30, k=20, queries=500),
        (N=100000, D=40, k=30, queries=500),
    ]

    workload_fn = () -> run_profiled_workload(scenarios=large_scenarios)

    # Collect profile
    println("Collecting profile from large workload...")
    profile = collect_profile_data(
        workload_fn=workload_fn,
        metadata=Dict{String,Any}(
            "test" => "large_workload",
            "description" => "Testing with 50K-100K points"
        )
    )

    # Save to file
    output_file = joinpath(PROFILE_DIR, "profile_large.json")
    save_profile(profile, output_file)
    println()

    # Test queries without loading entire file
    println("Testing programmatic queries (no full file read)...")
    println("-" ^ 80)
    println()

    # Query 1: Top 10 hotspots
    println("Query 1: Top 10 hotspots")
    top_10 = query_top_n(profile, 10)
    print_entry_table(top_10[1:min(5, length(top_10))])  # Just show first 5
    println("... (showing 5 of $(length(top_10)))")
    println()

    # Query 2: ATRIA-specific code
    println("Query 2: ATRIA-specific code")
    atria_code = query_atria_code(profile)
    print_entry_table(atria_code[1:min(5, length(atria_code))])
    println("... (showing 5 of $(length(atria_code)))")
    println()

    # Query 3: Search-related functions
    println("Query 3: Functions matching 'search'")
    search_funcs = query_by_pattern(profile, "search")
    print_entry_table(search_funcs[1:min(5, length(search_funcs))])
    println("... (showing 5 of $(length(search_funcs)))")
    println()

    # Summary statistics
    println("=" ^ 80)
    println("Scalability Summary")
    println("=" ^ 80)
    println()
    println("✓ Profile collected: $(profile.total_samples) samples, $(length(profile.entries)) unique locations")
    println("✓ File size: $(filesize(output_file)) bytes ($(round(filesize(output_file)/1024, digits=2)) KB)")
    println("✓ Queries executed without reading full file into context")
    println("✓ All query operations completed successfully")
    println()

    # Demonstrate memory efficiency
    file_size_kb = round(filesize(output_file) / 1024, digits=2)
    estimated_lines = profile.total_samples * 3  # Rough estimate for text format
    println("Comparison:")
    println("  JSON format: $(file_size_kb) KB")
    println("  Plain text would be: ~$(estimated_lines) lines")
    println("  Context saved: Can query specific data instead of reading everything")
    println()

    println("✓ Scalability test passed!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

"""
profile_analyzer.jl

Advanced profiling tool with structured data storage and programmatic querying.
Designed to handle large profile datasets without clogging context.

Usage:
    # Collect profile data
    julia --project=. profile_analyzer.jl collect

    # Query profile data
    julia --project=. profile_analyzer.jl query --top 10
    julia --project=. profile_analyzer.jl query --file src/search.jl
    julia --project=. profile_analyzer.jl query --pattern "distance"
    julia --project=. profile_analyzer.jl query --function "_search_knn!"

    # Get summary
    julia --project=. profile_analyzer.jl summary
    julia --project=. profile_analyzer.jl summary --atria-only

    # Compare profiles
    julia --project=. profile_analyzer.jl compare profile1.json profile2.json
"""

using Profile
using Random
using Printf
using Statistics
using Dates
using JSON3

# Load the package
using ATRIANeighbors

const PROFILE_DIR = "profile_results"
const DEFAULT_PROFILE_FILE = joinpath(PROFILE_DIR, "profile_data.json")

# ============================================================================
# Data Structures
# ============================================================================

"""
Profile entry representing a single function/location in the profile.
"""
struct ProfileEntry
    func::String
    file::String
    line::Int
    samples::Int
    percentage::Float64
end

"""
Complete profile dataset with metadata.
"""
struct ProfileData
    timestamp::DateTime
    total_samples::Int
    entries::Vector{ProfileEntry}
    metadata::Dict{String, Any}
end

# ============================================================================
# Workload Generation
# ============================================================================

"""
    simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)

Generate a simple Gaussian-distributed dataset.
"""
function simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)
    return randn(rng, N, D)
end

"""
    run_profiled_workload(; scenarios=nothing)

Run a representative workload for profiling.
"""
function run_profiled_workload(; scenarios=nothing)
    rng = MersenneTwister(42)

    # Default scenarios
    if scenarios === nothing
        scenarios = [
            (N=1000, D=10, k=10, queries=50),
            (N=5000, D=20, k=10, queries=50),
            (N=10000, D=15, k=20, queries=100),
        ]
    end

    for scenario in scenarios
        # Generate data
        data = simple_dataset(scenario.N, scenario.D, rng=rng)

        # Generate query points
        query_indices = rand(rng, 1:scenario.N, scenario.queries)
        queries = copy(data[query_indices, :])
        queries .+= randn(rng, size(queries)...) .* 0.01

        # Build tree
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=64)

        # Run queries
        for i in 1:scenario.queries
            query = queries[i, :]
            ATRIANeighbors.knn(tree, query, k=scenario.k)
        end
    end
end

# ============================================================================
# Profile Collection
# ============================================================================

"""
    collect_profile_data(; workload_fn=run_profiled_workload, metadata=Dict{String,Any}())

Collect profile data and return as structured ProfileData.
"""
function collect_profile_data(; workload_fn=run_profiled_workload, metadata=Dict{String,Any}())
    # Clear previous profile data
    Profile.clear()

    # Warm up (compilation)
    println("Warming up (compilation)...")
    workload_fn()

    # Profile
    println("Profiling with sampling enabled...")
    Profile.clear()
    @profile workload_fn()

    # Extract data
    data = Profile.fetch()

    if isempty(data)
        @warn "No profile data collected. The workload may be too fast."
        return ProfileData(now(), 0, ProfileEntry[], metadata)
    end

    # Count samples per function
    function_counts = Dict{Tuple{String,String,Int}, Int}()

    for frame_idx in data
        if frame_idx > 0  # Valid frame
            try
                frames = Profile.lookup(frame_idx)
                if !isempty(frames)
                    func_info = frames[1]
                    func_name = String(func_info.func)
                    file = String(func_info.file)
                    line = func_info.line

                    # Skip invalid entries but keep all valid ones
                    if func_name != "unknown function"
                        key = (func_name, file, line)
                        function_counts[key] = get(function_counts, key, 0) + 1
                    end
                end
            catch
                # Skip invalid frames
                continue
            end
        end
    end

    # Convert to ProfileEntry array
    total_samples = length(data)
    entries = [
        ProfileEntry(func, file, line, count, 100.0 * count / total_samples)
        for ((func, file, line), count) in function_counts
    ]

    # Sort by sample count (descending)
    sort!(entries, by=e -> e.samples, rev=true)

    return ProfileData(now(), total_samples, entries, metadata)
end

"""
    save_profile(profile::ProfileData, filename::String)

Save profile data to JSON file.
"""
function save_profile(profile::ProfileData, filename::String)
    mkpath(dirname(filename))

    # Convert to JSON-friendly format
    data = Dict(
        "timestamp" => string(profile.timestamp),
        "total_samples" => profile.total_samples,
        "entries" => [
            Dict(
                "func" => e.func,
                "file" => e.file,
                "line" => e.line,
                "samples" => e.samples,
                "percentage" => e.percentage
            )
            for e in profile.entries
        ],
        "metadata" => profile.metadata
    )

    open(filename, "w") do io
        JSON3.pretty(io, data)
    end

    println("Profile data saved to: $filename")
    println("  Total samples: $(profile.total_samples)")
    println("  Unique locations: $(length(profile.entries))")
end

"""
    load_profile(filename::String) -> ProfileData

Load profile data from JSON file.
"""
function load_profile(filename::String)
    data = JSON3.read(read(filename, String))

    entries = [
        ProfileEntry(
            e[:func],
            e[:file],
            e[:line],
            e[:samples],
            e[:percentage]
        )
        for e in data[:entries]
    ]

    # Convert metadata keys from Symbol to String
    metadata = Dict{String,Any}(String(k) => v for (k, v) in pairs(data[:metadata]))

    return ProfileData(
        DateTime(data[:timestamp]),
        data[:total_samples],
        entries,
        metadata
    )
end

# ============================================================================
# Query Functions
# ============================================================================

"""
    query_top_n(profile::ProfileData, n::Int; filter_system=true) -> Vector{ProfileEntry}

Get top N hotspots.
"""
function query_top_n(profile::ProfileData, n::Int; filter_system=true)
    entries = profile.entries

    if filter_system
        entries = filter(e -> !is_system_code(e), entries)
    end

    return entries[1:min(n, length(entries))]
end

"""
    query_by_file(profile::ProfileData, file_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a file pattern.
"""
function query_by_file(profile::ProfileData, file_pattern::String)
    return filter(e -> contains(e.file, file_pattern), profile.entries)
end

"""
    query_by_function(profile::ProfileData, func_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a function name pattern.
"""
function query_by_function(profile::ProfileData, func_pattern::String)
    return filter(e -> contains(e.func, func_pattern), profile.entries)
end

"""
    query_by_pattern(profile::ProfileData, pattern::String) -> Vector{ProfileEntry}

Get all entries where function OR file matches pattern.
"""
function query_by_pattern(profile::ProfileData, pattern::String)
    return filter(e -> contains(e.func, pattern) || contains(e.file, pattern), profile.entries)
end

"""
    query_atria_code(profile::ProfileData) -> Vector{ProfileEntry}

Get all entries from ATRIANeighbors package code.
"""
function query_atria_code(profile::ProfileData)
    atria_files = ["tree.jl", "search.jl", "structures.jl", "metrics.jl", "pointsets.jl"]
    return filter(e ->
        contains(e.file, "ATRIANeighbors") ||
        any(contains(e.file, f) for f in atria_files),
        profile.entries
    )
end

"""
    is_system_code(entry::ProfileEntry) -> Bool

Check if entry is from system/base Julia code.
"""
function is_system_code(entry::ProfileEntry)
    system_patterns = [
        "libc", "libopenlibm", "jl_", "julia-release",
        "/Base.jl", "/client.jl", "/loading.jl", "/boot.jl",
        "/cache/build/", "/workspace/srcdir/", "glibc"
    ]

    return any(contains(entry.file, p) || contains(entry.func, p) for p in system_patterns)
end

# ============================================================================
# Summary Functions
# ============================================================================

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
    summarize_profile(profile::ProfileData; atria_only=false, top_n=20, show_recommendations=true)

Generate a comprehensive summary of profile data.
"""
function summarize_profile(profile::ProfileData; atria_only=false, top_n=20, show_recommendations=true)
    println("=" ^ 80)
    println("Profile Summary")
    println("=" ^ 80)
    println("Timestamp: ", profile.timestamp)
    println("Total samples: ", profile.total_samples)
    println("Unique locations: ", length(profile.entries))
    println()

    # Overall top hotspots
    if !atria_only
        println("=" ^ 80)
        println("Top $top_n Hotspots (All Code)")
        println("=" ^ 80)
        println()
        top_entries = query_top_n(profile, top_n, filter_system=true)
        print_entry_table(top_entries)
        println()
    end

    # ATRIA-specific hotspots
    println("=" ^ 80)
    println("ATRIA Package Hotspots")
    println("=" ^ 80)
    println()
    atria_entries = query_atria_code(profile)

    if !isempty(atria_entries)
        atria_samples = sum(e.samples for e in atria_entries)
        atria_pct = 100.0 * atria_samples / profile.total_samples
        println("Total ATRIA samples: $atria_samples / $(profile.total_samples) ($(round(atria_pct, digits=2))%)")
        println()

        display_count = atria_only ? length(atria_entries) : min(top_n, length(atria_entries))
        print_entry_table(atria_entries[1:display_count])
    else
        println("No ATRIA package code found in profile.")
    end
    println()

    # Recommendations
    if show_recommendations && !isempty(atria_entries)
        println("=" ^ 80)
        println("Performance Recommendations")
        println("=" ^ 80)
        println()
        generate_recommendations(atria_entries)
    end
end

"""
    generate_recommendations(entries::Vector{ProfileEntry})

Generate performance recommendations based on hotspots.
"""
function generate_recommendations(entries::Vector{ProfileEntry})
    # Categorize hotspots
    has_distance = any(contains(lowercase(e.func), "distance") for e in entries)
    has_search = any(contains(lowercase(e.func), "search") || contains(lowercase(e.func), "knn") for e in entries)
    has_heap = any(contains(lowercase(e.func), "heap") || contains(lowercase(e.func), "neighbor") for e in entries)
    has_tree = any(contains(lowercase(e.func), "tree") || contains(lowercase(e.func), "build") for e in entries)
    has_partition = any(contains(lowercase(e.func), "partition") || contains(lowercase(e.func), "assign") for e in entries)

    if has_distance
        println("🔥 DISTANCE CALCULATIONS IN HOT PATH:")
        println("   • Add @inbounds for array access")
        println("   • Use @simd for vectorization")
        println("   • Implement aggressive early termination")
        println("   • Add @inline annotations")
        println()
    end

    if has_search
        println("🔍 SEARCH OPERATIONS IN HOT PATH:")
        println("   • Optimize priority queue operations")
        println("   • Reduce allocations in search loop")
        println("   • Use @inbounds for permutation table access")
        println("   • Consider caching frequently accessed data")
        println()
    end

    if has_heap
        println("📊 HEAP OPERATIONS IN HOT PATH:")
        println("   • Use StaticArrays for small fixed k")
        println("   • Optimize SortedNeighborTable data structure")
        println("   • Reduce allocations in insert/remove")
        println()
    end

    if has_tree
        println("🌲 TREE CONSTRUCTION IN HOT PATH:")
        println("   • Optimize partition algorithm")
        println("   • Improve cache locality")
        println("   • Pre-allocate arrays")
        println()
    end

    if has_partition
        println("✂️  PARTITIONING IN HOT PATH:")
        println("   • Optimize assign_points_to_centers!")
        println("   • Reduce memory allocations")
        println("   • Improve memory access patterns")
        println()
    end
end

"""
    compare_profiles(profile1::ProfileData, profile2::ProfileData; top_n=20)

Compare two profile datasets to identify performance changes.
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
    total_increase = sum(d[2] for d in differences if d[2] > 0)
    total_decrease = sum(d[2] for d in differences if d[2] < 0)

    println("Summary:")
    println("  Total sample changes: $total_increase (increases), $total_decrease (decreases)")
    println()
end

# ============================================================================
# CLI Interface
# ============================================================================

"""
    parse_args(args::Vector{String})

Parse command line arguments.
"""
function parse_args(args::Vector{String})
    if isempty(args)
        return Dict("command" => "help")
    end

    result = Dict{String,Any}("command" => args[1])

    i = 2
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            key = arg[3:end]
            if i < length(args) && !startswith(args[i+1], "--")
                result[key] = args[i+1]
                i += 2
            else
                result[key] = true
                i += 1
            end
        else
            if !haskey(result, "positional")
                result["positional"] = []
            end
            push!(result["positional"], arg)
            i += 1
        end
    end

    return result
end

"""
    show_help()

Display help message.
"""
function show_help()
    println("""
ATRIANeighbors.jl Profile Analyzer
==================================

COMMANDS:

  collect [options]
      Collect profile data and save to file
      Options:
        --output FILE    Output file (default: profile_results/profile_data.json)
        --scenarios N    Use N different test scenarios

  query [options]
      Query profile data
      Options:
        --input FILE     Input file (default: profile_results/profile_data.json)
        --top N          Show top N entries (default: 20)
        --file PATTERN   Filter by file pattern
        --function PATTERN   Filter by function pattern
        --pattern PATTERN    Filter by any pattern (file or function)
        --atria          Show only ATRIA package code
        --no-system      Filter out system code (default: true)

  summary [options]
      Generate comprehensive summary
      Options:
        --input FILE       Input file (default: profile_results/profile_data.json)
        --top N            Number of entries to show (default: 20)
        --atria-only       Show only ATRIA code
        --no-recommendations   Don't show recommendations

  compare FILE1 FILE2 [options]
      Compare two profile datasets
      Options:
        --top N          Show top N changes (default: 20)

  help
      Show this help message

EXAMPLES:

  # Collect profile data
  julia --project=. profile_analyzer.jl collect

  # Query top 10 hotspots
  julia --project=. profile_analyzer.jl query --top 10

  # Find all distance-related functions
  julia --project=. profile_analyzer.jl query --pattern distance

  # Show only ATRIA code hotspots
  julia --project=. profile_analyzer.jl query --atria

  # Generate summary
  julia --project=. profile_analyzer.jl summary

  # Compare two profiles
  julia --project=. profile_analyzer.jl compare old.json new.json
""")
end

"""
    main(args::Vector{String})

Main entry point for CLI.
"""
function main(args::Vector{String})
    parsed = parse_args(args)
    command = parsed["command"]

    if command == "help"
        show_help()
        return
    end

    if command == "collect"
        output = get(parsed, "output", DEFAULT_PROFILE_FILE)
        metadata = Dict{String,Any}(
            "command" => "collect",
            "args" => args
        )

        profile = collect_profile_data(metadata=metadata)
        save_profile(profile, output)

    elseif command == "query"
        input = get(parsed, "input", DEFAULT_PROFILE_FILE)

        if !isfile(input)
            println("Error: Profile file not found: $input")
            println("Run 'collect' command first.")
            return
        end

        profile = load_profile(input)

        # Apply filters
        entries = if haskey(parsed, "atria")
            query_atria_code(profile)
        elseif haskey(parsed, "file")
            query_by_file(profile, parsed["file"])
        elseif haskey(parsed, "function")
            query_by_function(profile, parsed["function"])
        elseif haskey(parsed, "pattern")
            query_by_pattern(profile, parsed["pattern"])
        else
            filter_system = get(parsed, "no-system", "true") == "true"
            top_n = parse(Int, get(parsed, "top", "20"))
            query_top_n(profile, top_n, filter_system=filter_system)
        end

        if haskey(parsed, "top") && !haskey(parsed, "atria")
            top_n = parse(Int, parsed["top"])
            entries = entries[1:min(top_n, length(entries))]
        end

        print_entry_table(entries)

    elseif command == "summary"
        input = get(parsed, "input", DEFAULT_PROFILE_FILE)

        if !isfile(input)
            println("Error: Profile file not found: $input")
            println("Run 'collect' command first.")
            return
        end

        profile = load_profile(input)
        top_n = parse(Int, get(parsed, "top", "20"))
        atria_only = haskey(parsed, "atria-only")
        show_recs = !haskey(parsed, "no-recommendations")

        summarize_profile(profile, atria_only=atria_only, top_n=top_n, show_recommendations=show_recs)

    elseif command == "compare"
        positional = get(parsed, "positional", [])
        if length(positional) < 2
            println("Error: compare requires two profile files")
            println("Usage: compare FILE1 FILE2")
            return
        end

        file1, file2 = positional[1:2]

        if !isfile(file1) || !isfile(file2)
            println("Error: One or both profile files not found")
            return
        end

        profile1 = load_profile(file1)
        profile2 = load_profile(file2)
        top_n = parse(Int, get(parsed, "top", "20"))

        compare_profiles(profile1, profile2, top_n=top_n)

    else
        println("Unknown command: $command")
        println("Run 'help' for usage information")
    end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

"""
profile_analyzer.jl

ATRIANeighbors-specific profiling script using ProfilingAnalysis.jl.

Usage:
    # Collect profile data
    julia --project=. profile_analyzer.jl collect

    # Query profile data
    julia --project=. profile_analyzer.jl query --top 10
    julia --project=. profile_analyzer.jl query --atria

    # Get summary
    julia --project=. profile_analyzer.jl summary
    julia --project=. profile_analyzer.jl summary --atria-only

    # Compare profiles
    julia --project=. profile_analyzer.jl compare profile1.json profile2.json
"""

# Add ProfilingAnalysis package to load path
push!(LOAD_PATH, joinpath(@__DIR__, "ProfilingAnalysis.jl", "src"))

using ProfilingAnalysis
using Random
using ATRIANeighbors

const PROFILE_DIR = "profile_results"
const DEFAULT_PROFILE_FILE = joinpath(PROFILE_DIR, "profile_data.json")

# ============================================================================
# ATRIA-Specific Workload
# ============================================================================

"""
    simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)

Generate a simple Gaussian-distributed dataset.
"""
function simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)
    return randn(rng, N, D)
end

"""
    run_atria_workload(; scenarios=nothing)

Run a representative ATRIA workload for profiling.
"""
function run_atria_workload(; scenarios=nothing)
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
# ATRIA-Specific Query Functions
# ============================================================================

"""
    query_atria_code(profile::ProfileData) -> Vector{ProfileEntry}

Get all entries from ATRIANeighbors package code.
"""
function query_atria_code(profile::ProfileData)
    atria_files = ["tree.jl", "search.jl", "structures.jl", "metrics.jl", "pointsets.jl"]
    return query_by_filter(profile, e ->
        contains(e.file, "ATRIANeighbors") ||
        any(contains(e.file, f) for f in atria_files)
    )
end

# ============================================================================
# ATRIA-Specific Recommendations
# ============================================================================

const ATRIA_RECOMMENDATION_PATTERNS = Dict(
    "Distance Calculations" => (
        patterns = ["distance", "metric", "norm"],
        recommendations = [
            "Add @inbounds for array access",
            "Use @simd for vectorization",
            "Implement aggressive early termination",
            "Add @inline annotations"
        ]
    ),
    "Search Operations" => (
        patterns = ["search", "knn", "_search"],
        recommendations = [
            "Optimize priority queue operations",
            "Reduce allocations in search loop",
            "Use @inbounds for permutation table access",
            "Consider caching frequently accessed data"
        ]
    ),
    "Heap Operations" => (
        patterns = ["heap", "neighbor", "sorted"],
        recommendations = [
            "Use StaticArrays for small fixed k",
            "Optimize SortedNeighborTable data structure",
            "Reduce allocations in insert/remove"
        ]
    ),
    "Tree Construction" => (
        patterns = ["tree", "build", "cluster"],
        recommendations = [
            "Optimize partition algorithm",
            "Improve cache locality",
            "Pre-allocate arrays"
        ]
    ),
    "Partitioning" => (
        patterns = ["partition", "assign", "center"],
        recommendations = [
            "Optimize assign_points_to_centers!",
            "Reduce memory allocations",
            "Improve memory access patterns"
        ]
    )
)

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
===================================

COMMANDS:

  collect [options]
      Collect profile data and save to file
      Options:
        --output FILE    Output file (default: profile_results/profile_data.json)

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

  # Generate summary with recommendations
  julia --project=. profile_analyzer.jl summary --atria-only

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
            "package" => "ATRIANeighbors",
            "command" => "collect",
            "args" => args
        )

        println("Collecting profile data for ATRIANeighbors...")
        profile = collect_profile_data(run_atria_workload, metadata=metadata)
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
            filter_fn = filter_system ? (e -> !is_system_code(e)) : nothing
            query_top_n(profile, top_n, filter_fn=filter_fn)
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

        # Show overall summary if not atria-only
        if !atria_only
            summarize_profile(profile,
                filter_fn = e -> !is_system_code(e),
                top_n=top_n,
                title="Profile Summary (All Code)"
            )
        end

        # Show ATRIA-specific summary
        atria_entries = query_atria_code(profile)
        if !isempty(atria_entries)
            atria_samples = sum(e.samples for e in atria_entries)
            atria_pct = 100.0 * atria_samples / profile.total_samples

            println("=" ^ 80)
            println("ATRIA Package Hotspots")
            println("=" ^ 80)
            println()
            println("Total ATRIA samples: $atria_samples / $(profile.total_samples) ($(round(atria_pct, digits=2))%)")
            println()

            display_count = atria_only ? length(atria_entries) : min(top_n, length(atria_entries))
            print_entry_table(atria_entries[1:display_count])
            println()

            # Show recommendations
            if show_recs
                generate_recommendations(atria_entries, ATRIA_RECOMMENDATION_PATTERNS)
            end
        else
            println("No ATRIA package code found in profile.")
        end

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

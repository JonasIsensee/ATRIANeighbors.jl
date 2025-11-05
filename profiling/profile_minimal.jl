"""
profile_minimal.jl

Minimal profiling script for ATRIANeighbors.jl using only built-in Julia Profile module.
No external dependencies required beyond the ATRIANeighbors package itself.

Usage:
    ~/.juliaup/bin/julia --project=. profile_minimal.jl

Output:
    - profile_results/profile_flat.txt - Flat view of profile data
    - profile_results/profile_tree.txt - Tree view showing call hierarchy
    - profile_results/profile_summary.txt - Summary and bottleneck analysis
"""

using Profile
using Random
using Printf
using Statistics
using Dates

# Load the package
using ATRIANeighbors

# Create output directory
const PROFILE_DIR = "profile_results"
mkpath(PROFILE_DIR)

"""
    simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)

Generate a simple Gaussian-distributed dataset (no external dependencies).
"""
function simple_dataset(N::Int, D::Int; rng=Random.GLOBAL_RNG)
    return randn(rng, N, D)
end

"""
    run_profiled_workload()

Run a representative workload for profiling.
"""
function run_profiled_workload()
    rng = MersenneTwister(42)

    # Test scenarios with varying sizes
    scenarios = [
        (N=1000, D=10, k=10, queries=50),
        (N=5000, D=20, k=10, queries=50),
        (N=10000, D=15, k=20, queries=100),
    ]

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

"""
    profile_to_file(filename::String, format::Symbol)

Run profiling and save results to file with specified format.
"""
function profile_to_file(filename::String, format::Symbol)
    filepath = joinpath(PROFILE_DIR, filename)

    # Clear previous profile data
    Profile.clear()

    # Warm up (compilation)
    println("Warming up (compilation)...")
    run_profiled_workload()

    # Now profile
    println("Profiling with sampling enabled...")
    Profile.clear()
    @profile run_profiled_workload()

    # Write to file
    open(filepath, "w") do io
        if format == :flat
            Profile.print(io, format=:flat, sortedby=:count, noisefloor=2.0)
        elseif format == :tree
            Profile.print(io, format=:tree, maxdepth=20, noisefloor=2.0)
        end
    end

    println("  Written to: $filepath")
end

"""
    analyze_profile_data()

Analyze profile data and generate a summary report with bottleneck identification.
"""
function analyze_profile_data()
    # Get raw profile data
    data = Profile.fetch()

    if isempty(data)
        return "No profile data collected. The workload may be too fast."
    end

    # Count samples per function
    function_counts = Dict{String, Int}()

    for frame_idx in data
        if frame_idx > 0  # Valid frame
            try
                frames = Profile.lookup(frame_idx)
                if !isempty(frames)
                    func_info = frames[1]
                    func_name = String(func_info.func)
                    file = String(func_info.file)
                    line = func_info.line

                    # Skip C functions and base library for clarity
                    if !startswith(file, "libc") &&
                       !startswith(file, "libopenlibm") &&
                       !startswith(func_name, "jl_") &&
                       func_name != "unknown function"

                        key = "$func_name ($file:$line)"
                        function_counts[key] = get(function_counts, key, 0) + 1
                    end
                end
            catch
                # Skip invalid frames
                continue
            end
        end
    end

    # Sort by count
    sorted_funcs = sort(collect(function_counts), by=x->x[2], rev=true)

    # Generate report
    report = IOBuffer()
    println(report, "="^80)
    println(report, "ATRIANeighbors.jl Profile Analysis Summary")
    println(report, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println(report, "="^80)
    println(report)
    println(report, "Total samples: $(length(data))")
    println(report, "Unique function/line combinations: $(length(function_counts))")
    println(report)
    println(report, "="^80)
    println(report, "Top 30 Hotspots (by sample count)")
    println(report, "="^80)
    println(report)
    println(report, @sprintf("%-6s %-10s %-10s %-60s", "Rank", "Samples", "% Total", "Function (File:Line)"))
    println(report, "-"^80)

    for (idx, (func, count)) in enumerate(sorted_funcs[1:min(30, length(sorted_funcs))])
        percentage = 100.0 * count / length(data)
        # Truncate long function names
        func_display = length(func) > 60 ? func[1:57] * "..." : func
        println(report, @sprintf("%-6d %-10d %-10.2f %s", idx, count, percentage, func_display))
    end

    println(report)
    println(report, "="^80)
    println(report, "Bottleneck Identification")
    println(report, "="^80)
    println(report)

    # Identify ATRIANeighbors functions specifically
    atria_funcs = filter(x -> contains(x[1], "ATRIANeighbors") ||
                              contains(x[1], "tree.jl") ||
                              contains(x[1], "search.jl") ||
                              contains(x[1], "structures.jl") ||
                              contains(x[1], "metrics.jl") ||
                              contains(x[1], "pointsets.jl"),
                        sorted_funcs)

    if !isempty(atria_funcs)
        println(report, "ATRIANeighbors-specific hotspots (Top 15):")
        println(report)
        for (idx, (func, count)) in enumerate(atria_funcs[1:min(15, length(atria_funcs))])
            percentage = 100.0 * count / length(data)
            println(report, @sprintf("%-3d. [%-5d samples, %5.2f%%] %s",
                idx, count, percentage, func))
        end
        println(report)
        println(report, "Total ATRIANeighbors samples: $(sum(x[2] for x in atria_funcs)) / $(length(data)) ($(round(100.0 * sum(x[2] for x in atria_funcs) / length(data), digits=2))%)")
    else
        println(report, "No ATRIANeighbors-specific functions found in top samples.")
        println(report, "This may indicate the workload is dominated by I/O or compilation.")
    end

    println(report)
    println(report, "="^80)
    println(report, "Performance Recommendations")
    println(report, "="^80)
    println(report)

    # Generate recommendations based on top functions
    has_distance = any(contains(lowercase(f[1]), "distance") for f in atria_funcs)
    has_heap = any(contains(lowercase(f[1]), "heap") || contains(lowercase(f[1]), "sortedneighbortable") for f in atria_funcs)
    has_partition = any(contains(lowercase(f[1]), "assign_points") || contains(lowercase(f[1]), "partition") for f in atria_funcs)
    has_getpoint = any(contains(lowercase(f[1]), "getpoint") for f in atria_funcs)
    has_search = any(contains(lowercase(f[1]), "knn") || contains(lowercase(f[1]), "search") for f in atria_funcs)

    recommendations = String[]

    if has_distance
        push!(recommendations, "DISTANCE CALCULATIONS IN HOT PATH:")
        push!(recommendations, "  - Add @inbounds macro for array access in distance functions")
        push!(recommendations, "  - Use @simd for vectorization in loops")
        push!(recommendations, "  - Implement early termination more aggressively (partial distance calculation)")
        push!(recommendations, "  - Consider @inline annotation for small distance functions")
        push!(recommendations, "")
    end

    if has_heap
        push!(recommendations, "HEAP OPERATIONS IN HOT PATH:")
        push!(recommendations, "  - Consider using fixed-size StaticArrays for k-nearest storage when k is small")
        push!(recommendations, "  - Optimize SortedNeighborTable operations with better data structures")
        push!(recommendations, "  - Reduce allocations in heap insert/remove operations")
        push!(recommendations, "")
    end

    if has_partition
        push!(recommendations, "TREE CONSTRUCTION IS EXPENSIVE:")
        push!(recommendations, "  - Optimize partition algorithm in assign_points_to_centers!")
        push!(recommendations, "  - Improve cache locality in permutation table access")
        push!(recommendations, "  - Consider pre-allocating arrays for partition operations")
        push!(recommendations, "")
    end

    if has_getpoint
        push!(recommendations, "POINT ACCESS IN HOT PATH:")
        push!(recommendations, "  - Ensure getpoint() is type-stable and inlined")
        push!(recommendations, "  - Consider caching frequently accessed points")
        push!(recommendations, "  - Check for unnecessary bounds checking (@inbounds where safe)")
        push!(recommendations, "")
    end

    if has_search
        push!(recommendations, "SEARCH OPERATIONS IN HOT PATH:")
        push!(recommendations, "  - Optimize priority queue operations in best-first search")
        push!(recommendations, "  - Reduce allocations in search loop")
        push!(recommendations, "  - Consider using @inbounds for permutation table access")
        push!(recommendations, "")
    end

    if isempty(recommendations)
        push!(recommendations, "No specific bottlenecks identified.")
        push!(recommendations, "General recommendations:")
        push!(recommendations, "  - Check for type instabilities with @code_warntype")
        push!(recommendations, "  - Look for unnecessary allocations with @allocated")
        push!(recommendations, "  - Consider using BenchmarkTools for micro-benchmarks")
    end

    for rec in recommendations
        println(report, rec)
    end

    println(report, "="^80)

    return String(take!(report))
end

"""
    main()

Main entry point for profiling script.
"""
function main()
    println("="^80)
    println("ATRIANeighbors.jl Minimal Profiling Suite")
    println("="^80)
    println()

    # 1. Generate flat profile
    println("1. Generating flat profile (sorted by count)...")
    profile_to_file("profile_flat.txt", :flat)
    println()

    # 2. Generate tree profile
    println("2. Generating tree profile (showing call hierarchy)...")
    profile_to_file("profile_tree.txt", :tree)
    println()

    # 3. Generate summary analysis
    println("3. Analyzing profile data and identifying bottlenecks...")
    summary = analyze_profile_data()
    summary_path = joinpath(PROFILE_DIR, "profile_summary.txt")
    open(summary_path, "w") do io
        write(io, summary)
    end
    println("  Written to: $summary_path")
    println()

    # Print summary to console
    println(summary)

    println("="^80)
    println("Profiling complete!")
    println("="^80)
    println()
    println("Output files in: $PROFILE_DIR")
    println()
    println("Next steps:")
    println("  1. Review profile_summary.txt for bottleneck analysis")
    println("  2. Check profile_tree.txt to see call hierarchy")
    println("  3. Check profile_flat.txt for function-level statistics")
    println()
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

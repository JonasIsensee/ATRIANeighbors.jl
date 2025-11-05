"""
profile_atria.jl

Comprehensive profiling script for ATRIANeighbors.jl using multiple profiling methods.

This script generates AI-friendly profiling output in multiple formats:
1. Text-based output using Profile.print() (flat and tree views)
2. PProf format for detailed analysis
3. Summary statistics and bottleneck identification

Usage:
    julia --project=benchmark benchmark/profile_atria.jl

Output:
    - benchmark/profile_results/profile_flat.txt - Flat view of profile data
    - benchmark/profile_results/profile_tree.txt - Tree view showing call hierarchy
    - benchmark/profile_results/profile_summary.txt - Summary and bottleneck analysis
    - benchmark/profile_results/profile.pb.gz - PProf format (if PProf.jl available)
"""

using Pkg
Pkg.activate(@__DIR__)

using ATRIANeighbors
using Profile
using Random
using Printf
using Statistics
using Dates

# Load data generators
include("data_generators.jl")

# Create output directory
const PROFILE_DIR = joinpath(@__DIR__, "profile_results")
mkpath(PROFILE_DIR)

"""
    run_profiled_workload()

Run a representative workload for profiling.
This includes tree building and k-NN queries.
"""
function run_profiled_workload()
    rng = MersenneTwister(42)

    # Test multiple scenarios
    scenarios = [
        (name="Small Gaussian", type=:gaussian_mixture, N=1000, D=10, k=10, queries=50),
        (name="Medium Uniform", type=:uniform_hypercube, N=5000, D=20, k=10, queries=50),
        (name="Large Mixed", type=:gaussian_mixture, N=10000, D=15, k=20, queries=100),
    ]

    for scenario in scenarios
        println("Running scenario: $(scenario.name)")

        # Generate data
        data = generate_dataset(scenario.type, scenario.N, scenario.D, rng=rng)

        # Generate query points
        query_indices = rand(rng, 1:scenario.N, scenario.queries)
        queries = copy(data[query_indices, :])
        queries .+= randn(rng, size(queries)...) .* 0.01

        # Build tree (this should be profiled)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=64)

        # Run queries (this should be profiled)
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

    # Run with profiling - need to compile first
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
                frame = Profile.lookup(frame_idx)
                if !isempty(frame)
                    func_info = frame[1]
                    func_name = String(func_info.func)
                    file = String(func_info.file)

                    # Skip C functions and base library for clarity
                    if !startswith(file, "libc") &&
                       !startswith(file, "libopenlibm") &&
                       !startswith(func_name, "jl_")

                        key = "$func_name ($file)"
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
    println(report, "Profile Analysis Summary")
    println(report, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println(report, "="^80)
    println(report)
    println(report, "Total samples: $(length(data))")
    println(report, "Unique functions: $(length(function_counts))")
    println(report)
    println(report, "="^80)
    println(report, "Top 20 Hotspots (by sample count)")
    println(report, "="^80)
    println(report)
    println(report, @sprintf("%-6s %-8s %-60s", "Rank", "Samples", "Function (File)"))
    println(report, "-"^80)

    for (idx, (func, count)) in enumerate(sorted_funcs[1:min(20, length(sorted_funcs))])
        percentage = 100.0 * count / length(data)
        # Truncate long function names
        func_display = length(func) > 60 ? func[1:57] * "..." : func
        println(report, @sprintf("%-6d %-8d (%.1f%%) %s", idx, count, percentage, func_display))
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
        println(report, "ATRIANeighbors-specific hotspots:")
        println(report)
        for (idx, (func, count)) in enumerate(atria_funcs[1:min(10, length(atria_funcs))])
            percentage = 100.0 * count / length(data)
            println(report, "$(idx). [$(count) samples, $(round(percentage, digits=1))%] $func")
        end
    else
        println(report, "No ATRIANeighbors-specific functions found in top samples.")
        println(report, "This may indicate the workload is dominated by I/O or compilation.")
    end

    println(report)
    println(report, "="^80)
    println(report, "Recommendations")
    println(report, "="^80)
    println(report)

    # Generate recommendations based on top functions
    if any(contains(f[1], "distance") for f in atria_funcs)
        println(report, "- Distance calculations appear in hot path. Consider:")
        println(report, "  * Adding @inbounds for array access")
        println(report, "  * Using @simd for vectorization")
        println(report, "  * Implementing early termination more aggressively")
    end

    if any(contains(f[1], "heap") || contains(f[1], "SortedNeighborTable") for f in atria_funcs)
        println(report, "- Heap operations in hot path. Consider:")
        println(report, "  * Using fixed-size arrays instead of dynamic structures")
        println(report, "  * Optimizing heap operations with better data structures")
    end

    if any(contains(f[1], "assign_points") || contains(f[1], "partition") for f in atria_funcs)
        println(report, "- Tree construction is expensive. Consider:")
        println(report, "  * Optimizing partition algorithm")
        println(report, "  * Better cache locality in permutation table access")
    end

    println(report)
    println(report, "="^80)

    return String(take!(report))
end

"""
    profile_pprof()

Generate PProf format profiling data (if PProf is available).
"""
function profile_pprof()
    try
        @eval using PProf

        println("Running profiling for PProf...")
        Profile.clear()

        # Warm up
        run_profiled_workload()

        # Profile
        Profile.clear()
        @profile run_profiled_workload()

        # Export
        pprof_path = joinpath(PROFILE_DIR, "profile.pb.gz")
        PProf.pprof(out=pprof_path, web=false)

        println("  PProf data written to: $pprof_path")
        println("  To view: pprof -http=:8080 $pprof_path")

        return true
    catch e
        if e isa ArgumentError || e isa LoadError
            println("  PProf.jl not available (install with: Pkg.add(\"PProf\"))")
            return false
        else
            rethrow(e)
        end
    end
end

"""
    main()

Main entry point for profiling script.
"""
function main()
    println("="^80)
    println("ATRIANeighbors.jl Profiling Suite")
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

    # 4. Try to generate PProf data
    println("4. Generating PProf format (optional)...")
    profile_pprof()
    println()

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
    println("  4. Use PProf for interactive exploration: pprof -http=:8080 profile_results/profile.pb.gz")
    println()
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

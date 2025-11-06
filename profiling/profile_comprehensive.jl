"""
profile_comprehensive.jl

Comprehensive profiling script for ATRIANeighbors.jl using representative workloads
from the benchmark suite. Profiles all major operations: tree building, k-NN search,
range search, and count_range on various data types.

Usage:
    julia --project=profiling profiling/profile_comprehensive.jl

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

# ============================================================================
# Data Generators (from benchmark suite)
# ============================================================================

"""
    generate_lorenz_attractor(N::Int, dt::Float64=0.01) -> Matrix{Float64}

Generate N points from the Lorenz attractor (chaotic dynamical system).
This is ATRIA's primary use case - time-delay embedded data.
"""
function generate_lorenz_attractor(N::Int, dt::Float64=0.01;
                                  σ::Float64=10.0, ρ::Float64=28.0, β::Float64=8.0/3.0,
                                  transient::Int=1000)
    x, y, z = 1.0, 1.0, 1.0

    # Discard transient
    for _ in 1:transient
        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    # Generate data
    points = zeros(N, 3)
    for i in 1:N
        points[i, 1] = x
        points[i, 2] = y
        points[i, 3] = z

        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    return points
end

"""
    generate_rossler_attractor(N::Int, dt::Float64=0.05) -> Matrix{Float64}

Generate N points from the Rössler attractor.
"""
function generate_rossler_attractor(N::Int, dt::Float64=0.05;
                                   a::Float64=0.2, b::Float64=0.2, c::Float64=5.7,
                                   transient::Int=1000)
    x, y, z = 1.0, 1.0, 1.0

    # Discard transient
    for _ in 1:transient
        dx = -y - z
        dy = x + a * y
        dz = b + z * (x - c)
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    # Generate data
    points = zeros(N, 3)
    for i in 1:N
        points[i, 1] = x
        points[i, 2] = y
        points[i, 3] = z

        dx = -y - z
        dy = x + a * y
        dz = b + z * (x - c)
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    return points
end

"""
    generate_gaussian_mixture(N::Int, D::Int, n_clusters::Int) -> Matrix{Float64}

Generate N points from a Gaussian mixture model with n_clusters clusters.
Tests ATRIA on clustered data.
"""
function generate_gaussian_mixture(N::Int, D::Int, n_clusters::Int;
                                  cluster_std::Float64=1.0, separation::Float64=10.0,
                                  rng::AbstractRNG=Random.GLOBAL_RNG)
    centers = randn(rng, n_clusters, D) .* separation
    points = zeros(N, D)

    for i in 1:N
        cluster_idx = rand(rng, 1:n_clusters)
        center = centers[cluster_idx, :]
        points[i, :] = center .+ randn(rng, D) .* cluster_std
    end

    return points
end

"""
    generate_high_dim_gaussian(N::Int, D::Int) -> Matrix{Float64}

Generate high-dimensional Gaussian data.
Tests ATRIA's performance in high dimensions.
"""
function generate_high_dim_gaussian(N::Int, D::Int; rng::AbstractRNG=Random.GLOBAL_RNG)
    return randn(rng, N, D)
end

# ============================================================================
# Profiling Workloads
# ============================================================================

"""
    workload_tree_building(data::Matrix, min_points::Int)

Profile tree building on given data.
"""
function workload_tree_building(data::Matrix, min_points::Int)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=min_points)
    return tree
end

"""
    workload_knn_search(tree::ATRIATree, ps::PointSet, n_queries::Int, k::Int)

Profile k-NN search with multiple queries.
"""
function workload_knn_search(tree::ATRIATree, ps::AbstractPointSet, n_queries::Int, k::Int, rng::AbstractRNG)
    N = size(ps)[1]
    for _ in 1:n_queries
        query_idx = rand(rng, 1:N)
        query = getpoint(ps, query_idx)
        knn(tree, query, k=k)
    end
end

"""
    workload_range_search(tree::ATRIATree, ps::PointSet, n_queries::Int, radius::Float64)

Profile range search with multiple queries.
"""
function workload_range_search(tree::ATRIATree, ps::AbstractPointSet, n_queries::Int, radius::Float64, rng::AbstractRNG)
    N = size(ps)[1]
    for _ in 1:n_queries
        query_idx = rand(rng, 1:N)
        query = getpoint(ps, query_idx)
        range_search(tree, query, radius)
    end
end

"""
    workload_count_range(tree::ATRIATree, ps::PointSet, n_queries::Int, radius::Float64)

Profile count_range with multiple queries.
"""
function workload_count_range(tree::ATRIATree, ps::AbstractPointSet, n_queries::Int, radius::Float64, rng::AbstractRNG)
    N = size(ps)[1]
    for _ in 1:n_queries
        query_idx = rand(rng, 1:N)
        query = getpoint(ps, query_idx)
        count_range(tree, query, radius)
    end
end

"""
    run_comprehensive_workload()

Run comprehensive profiling workload with various data types and operations.
"""
function run_comprehensive_workload()
    rng = MersenneTwister(42)

    println("  Running workloads...")

    # ========================================================================
    # Workload 1: Lorenz Attractor (ATRIA's primary use case)
    # ========================================================================
    println("    [1/6] Lorenz attractor k-NN search...")
    data_lorenz = generate_lorenz_attractor(5000)
    ps_lorenz = PointSet(data_lorenz, EuclideanMetric())
    tree_lorenz = ATRIA(ps_lorenz, min_points=64)
    workload_knn_search(tree_lorenz, ps_lorenz, 200, 10, rng)

    # ========================================================================
    # Workload 2: Rössler Attractor
    # ========================================================================
    println("    [2/6] Rössler attractor k-NN search...")
    data_rossler = generate_rossler_attractor(5000)
    ps_rossler = PointSet(data_rossler, EuclideanMetric())
    tree_rossler = ATRIA(ps_rossler, min_points=64)
    workload_knn_search(tree_rossler, ps_rossler, 200, 10, rng)

    # ========================================================================
    # Workload 3: High-dimensional Gaussian mixture (clustered data)
    # ========================================================================
    println("    [3/6] High-dimensional clustered data k-NN search...")
    data_clusters = generate_gaussian_mixture(3000, 20, 10, rng=rng)
    ps_clusters = PointSet(data_clusters, EuclideanMetric())
    tree_clusters = ATRIA(ps_clusters, min_points=64)
    workload_knn_search(tree_clusters, ps_clusters, 150, 15, rng)

    # ========================================================================
    # Workload 4: Very high-dimensional data
    # ========================================================================
    println("    [4/6] Very high-dimensional data k-NN search...")
    data_highdim = generate_high_dim_gaussian(2000, 50, rng=rng)
    ps_highdim = PointSet(data_highdim, EuclideanMetric())
    tree_highdim = ATRIA(ps_highdim, min_points=64)
    workload_knn_search(tree_highdim, ps_highdim, 100, 10, rng)

    # ========================================================================
    # Workload 5: Range search (different operation)
    # ========================================================================
    println("    [5/6] Range search on Lorenz attractor...")
    workload_range_search(tree_lorenz, ps_lorenz, 100, 5.0, rng)

    # ========================================================================
    # Workload 6: Count range (correlation sum computation)
    # ========================================================================
    println("    [6/6] Count range on clustered data...")
    workload_count_range(tree_clusters, ps_clusters, 100, 8.0, rng)

    println("  Workloads completed")
end

# ============================================================================
# Profile Analysis
# ============================================================================

"""
    profile_to_file(filename::String, format::Symbol, workload_fn::Function)

Run profiling and save results to file with specified format.
"""
function profile_to_file(filename::String, format::Symbol, workload_fn::Function)
    filepath = joinpath(PROFILE_DIR, filename)

    # Clear previous profile data
    Profile.clear()

    # Warm up (compilation)
    println("  Warming up (compilation)...")
    workload_fn()

    # Now profile
    println("  Profiling with sampling enabled...")
    Profile.clear()
    @profile workload_fn()

    # Write to file
    open(filepath, "w") do io
        if format == :flat
            Profile.print(io, format=:flat, sortedby=:count, noisefloor=2.0)
        elseif format == :tree
            Profile.print(io, format=:tree, maxdepth=25, noisefloor=2.0)
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
                continue
            end
        end
    end

    # Sort by count
    sorted_funcs = sort(collect(function_counts), by=x->x[2], rev=true)

    # Generate report
    report = IOBuffer()
    println(report, "="^80)
    println(report, "ATRIANeighbors.jl Comprehensive Profile Analysis")
    println(report, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println(report, "="^80)
    println(report)
    println(report, "Workloads profiled:")
    println(report, "  1. Lorenz attractor k-NN search (5000 points, 200 queries)")
    println(report, "  2. Rössler attractor k-NN search (5000 points, 200 queries)")
    println(report, "  3. High-dimensional clustered data (3000 points, D=20, 150 queries)")
    println(report, "  4. Very high-dimensional data (2000 points, D=50, 100 queries)")
    println(report, "  5. Range search on Lorenz attractor (100 queries)")
    println(report, "  6. Count range on clustered data (100 queries)")
    println(report)
    println(report, "Total samples: $(length(data))")
    println(report, "Unique function/line combinations: $(length(function_counts))")
    println(report)
    println(report, "="^80)
    println(report, "Top 40 Hotspots (by sample count)")
    println(report, "="^80)
    println(report)
    println(report, @sprintf("%-6s %-10s %-10s %-60s", "Rank", "Samples", "% Total", "Function (File:Line)"))
    println(report, "-"^80)

    for (idx, (func, count)) in enumerate(sorted_funcs[1:min(40, length(sorted_funcs))])
        percentage = 100.0 * count / length(data)
        func_display = length(func) > 60 ? func[1:57] * "..." : func
        println(report, @sprintf("%-6d %-10d %-10.2f %s", idx, count, percentage, func_display))
    end

    println(report)
    println(report, "="^80)
    println(report, "ATRIANeighbors-Specific Hotspots")
    println(report, "="^80)
    println(report)

    # Identify ATRIANeighbors functions
    atria_funcs = filter(x -> contains(x[1], "ATRIANeighbors") ||
                              contains(x[1], "tree.jl") ||
                              contains(x[1], "search.jl") ||
                              contains(x[1], "structures.jl") ||
                              contains(x[1], "metrics.jl") ||
                              contains(x[1], "pointsets.jl"),
                        sorted_funcs)

    if !isempty(atria_funcs)
        println(report, "Top 20 ATRIANeighbors functions:")
        println(report)
        for (idx, (func, count)) in enumerate(atria_funcs[1:min(20, length(atria_funcs))])
            percentage = 100.0 * count / length(data)
            println(report, @sprintf("%-3d. [%-6d samples, %6.2f%%] %s",
                idx, count, percentage, func))
        end
        println(report)
        total_atria_samples = sum(x[2] for x in atria_funcs)
        atria_percentage = 100.0 * total_atria_samples / length(data)
        println(report, "Total ATRIANeighbors samples: $total_atria_samples / $(length(data)) ($(round(atria_percentage, digits=2))%)")
    else
        println(report, "No ATRIANeighbors-specific functions found in top samples.")
    end

    println(report)
    println(report, "="^80)
    println(report, "Performance Bottleneck Analysis")
    println(report, "="^80)
    println(report)

    # Categorize hotspots
    categories = Dict(
        "Distance calculations" => Any[],
        "Heap/priority queue operations" => Any[],
        "Tree construction" => Any[],
        "Point access" => Any[],
        "Search operations" => Any[],
        "Other" => Any[]
    )

    for (func, count) in atria_funcs[1:min(20, length(atria_funcs))]
        func_lower = lowercase(func)
        if contains(func_lower, "distance") || contains(func_lower, "metric")
            push!(categories["Distance calculations"], (func, count))
        elseif contains(func_lower, "heap") || contains(func_lower, "sortedneighbor") ||
               contains(func_lower, "insert") || contains(func_lower, "priority")
            push!(categories["Heap/priority queue operations"], (func, count))
        elseif contains(func_lower, "assign_points") || contains(func_lower, "partition") ||
               contains(func_lower, "build")
            push!(categories["Tree construction"], (func, count))
        elseif contains(func_lower, "getpoint")
            push!(categories["Point access"], (func, count))
        elseif contains(func_lower, "knn") || contains(func_lower, "search") ||
               contains(func_lower, "range") || contains(func_lower, "count")
            push!(categories["Search operations"], (func, count))
        else
            push!(categories["Other"], (func, count))
        end
    end

    for (category, funcs) in sort(collect(categories), by=x->isempty(x[2]) ? 0 : sum(f[2] for f in x[2]), rev=true)
        if !isempty(funcs)
            total_samples = sum(f[2] for f in funcs)
            percentage = 100.0 * total_samples / length(data)
            println(report, "$category: $total_samples samples ($(round(percentage, digits=2))%)")
            for (func, count) in funcs[1:min(5, length(funcs))]
                func_short = length(func) > 70 ? func[1:67] * "..." : func
                println(report, "  - $func_short")
            end
            println(report)
        end
    end

    println(report, "="^80)
    println(report, "Optimization Recommendations")
    println(report, "="^80)
    println(report)

    recommendations = generate_recommendations(categories, length(data))
    for rec in recommendations
        println(report, rec)
    end

    println(report, "="^80)

    return String(take!(report))
end

"""
    generate_recommendations(categories::Dict, total_samples::Int)

Generate optimization recommendations based on profiling results.
"""
function generate_recommendations(categories::Dict, total_samples::Int)
    recommendations = String[]

    distance_samples = isempty(categories["Distance calculations"]) ? 0 : sum(f[2] for f in categories["Distance calculations"])
    heap_samples = isempty(categories["Heap/priority queue operations"]) ? 0 : sum(f[2] for f in categories["Heap/priority queue operations"])
    tree_samples = isempty(categories["Tree construction"]) ? 0 : sum(f[2] for f in categories["Tree construction"])
    point_samples = isempty(categories["Point access"]) ? 0 : sum(f[2] for f in categories["Point access"])
    search_samples = isempty(categories["Search operations"]) ? 0 : sum(f[2] for f in categories["Search operations"])

    # Distance calculations
    if distance_samples > 0.1 * total_samples
        push!(recommendations, "⚠️  DISTANCE CALCULATIONS ($(round(100*distance_samples/total_samples, digits=1))% of time):")
        push!(recommendations, "   - Use @inbounds for array access in distance functions")
        push!(recommendations, "   - Implement @simd for vectorization")
        push!(recommendations, "   - Optimize partial distance calculation (early termination)")
        push!(recommendations, "   - Consider @inline for small distance functions")
        push!(recommendations, "")
    end

    # Heap operations
    if heap_samples > 0.05 * total_samples
        push!(recommendations, "⚠️  HEAP/PRIORITY QUEUE ($(round(100*heap_samples/total_samples, digits=1))% of time):")
        push!(recommendations, "   - Use StaticArrays for k-nearest storage when k is small")
        push!(recommendations, "   - Optimize SortedNeighborTable with better data structures")
        push!(recommendations, "   - Reduce allocations in heap operations")
        push!(recommendations, "")
    end

    # Tree construction
    if tree_samples > 0.15 * total_samples
        push!(recommendations, "⚠️  TREE CONSTRUCTION ($(round(100*tree_samples/total_samples, digits=1))% of time):")
        push!(recommendations, "   - Optimize partition algorithm in assign_points_to_centers!")
        push!(recommendations, "   - Improve cache locality in permutation table access")
        push!(recommendations, "   - Pre-allocate arrays for partition operations")
        push!(recommendations, "")
    end

    # Point access
    if point_samples > 0.05 * total_samples
        push!(recommendations, "⚠️  POINT ACCESS ($(round(100*point_samples/total_samples, digits=1))% of time):")
        push!(recommendations, "   - Ensure getpoint() is type-stable and inlined")
        push!(recommendations, "   - Consider caching frequently accessed points")
        push!(recommendations, "   - Use @inbounds where bounds checking is proven safe")
        push!(recommendations, "")
    end

    # Search operations
    if search_samples > 0.2 * total_samples
        push!(recommendations, "⚠️  SEARCH OPERATIONS ($(round(100*search_samples/total_samples, digits=1))% of time):")
        push!(recommendations, "   - Optimize priority queue operations in best-first search")
        push!(recommendations, "   - Reduce allocations in search loops")
        push!(recommendations, "   - Use @inbounds for permutation table access")
        push!(recommendations, "")
    end

    if isempty(recommendations)
        push!(recommendations, "✓ No major bottlenecks identified.")
        push!(recommendations, "")
        push!(recommendations, "General recommendations:")
        push!(recommendations, "  - Use @code_warntype to check for type instabilities")
        push!(recommendations, "  - Use @allocated to find unnecessary allocations")
        push!(recommendations, "  - Consider micro-benchmarks with BenchmarkTools")
    end

    return recommendations
end

# ============================================================================
# Main Entry Point
# ============================================================================

"""
    main()

Main entry point for comprehensive profiling.
"""
function main()
    println("="^80)
    println("ATRIANeighbors.jl Comprehensive Profiling Suite")
    println("="^80)
    println()

    # 1. Generate flat profile
    println("1. Generating flat profile (sorted by sample count)...")
    profile_to_file("profile_flat.txt", :flat, run_comprehensive_workload)
    println()

    # 2. Generate tree profile
    println("2. Generating tree profile (showing call hierarchy)...")
    profile_to_file("profile_tree.txt", :tree, run_comprehensive_workload)
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
    println("Comprehensive profiling complete!")
    println("="^80)
    println()
    println("Output files in: $PROFILE_DIR/")
    println("  - profile_flat.txt: Function-level statistics")
    println("  - profile_tree.txt: Call hierarchy")
    println("  - profile_summary.txt: Bottleneck analysis and recommendations")
    println()
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

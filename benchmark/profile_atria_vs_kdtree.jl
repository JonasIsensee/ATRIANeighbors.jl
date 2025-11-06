# Profile ATRIA vs KDTree to identify performance bottlenecks

using Printf
using Statistics
using Profile
using BenchmarkTools

# Load implementations
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors
using NearestNeighbors

"""
    profile_search_loop(tree_atria, tree_kd, data, n_queries, k)

Profile the search loop for both ATRIA and KDTree.
"""
function profile_search_loop(tree_atria, tree_kd, data::Matrix{Float64}, n_queries::Int, k::Int)
    N, D = size(data)
    query_indices = rand(1:N, n_queries)

    println("\n" * "="^80)
    println("PROFILING SEARCH LOOPS")
    println("="^80)

    # ATRIA profiling
    println("\n1. ATRIA Search Loop:")
    println("   Running $n_queries queries...")

    Profile.clear()
    @profile begin
        for query_idx in query_indices
            query_point = data[query_idx, :]
            neighbors = ATRIANeighbors.knn(tree_atria, query_point, k=k+1)
        end
    end

    println("\n   Top 20 hotspots in ATRIA:")
    Profile.print(format=:flat, sortedby=:count, maxdepth=20, noisefloor=2.0)

    # KDTree profiling
    println("\n\n2. KDTree Search Loop:")
    println("   Running $n_queries queries...")

    Profile.clear()
    @profile begin
        for query_idx in query_indices
            query_point = data[query_idx, :]
            idxs, dists = NearestNeighbors.knn(tree_kd, query_point, k+1, true)
        end
    end

    println("\n   Top 20 hotspots in KDTree:")
    Profile.print(format=:flat, sortedby=:count, maxdepth=20, noisefloor=2.0)
end

"""
    benchmark_detailed(data, k, n_queries)

Run detailed benchmarks comparing ATRIA vs KDTree.
"""
function benchmark_detailed(data::Matrix{Float64}, k::Int=10, n_queries::Int=100)
    N, D = size(data)

    println("\n" * "="^80)
    println("DETAILED PERFORMANCE COMPARISON: ATRIA vs KDTree")
    println("="^80)
    println("\nDataset: N=$N, D=$D")
    println("Queries: k=$k neighbors, $n_queries query points")

    # Build trees
    println("\n" * "-"^80)
    println("TREE CONSTRUCTION")
    println("-"^80)

    println("\n1. Building ATRIA tree...")
    ps_atria = PointSet(data, EuclideanMetric())
    atria_build_time = @elapsed tree_atria = ATRIA(ps_atria, min_points=10)
    println("   Build time: $(round(atria_build_time * 1000, digits=2)) ms")
    println("   Clusters: $(tree_atria.total_clusters)")
    println("   Terminal nodes: $(tree_atria.terminal_nodes)")

    println("\n2. Building KDTree...")
    kdtree_build_time = @elapsed tree_kd = KDTree(data')
    println("   Build time: $(round(kdtree_build_time * 1000, digits=2)) ms")

    println("\n   Build time ratio (ATRIA/KDTree): $(round(atria_build_time / kdtree_build_time, digits=2))x")

    # Query benchmarks
    println("\n" * "-"^80)
    println("QUERY PERFORMANCE")
    println("-"^80)

    query_indices = rand(1:N, n_queries)

    # Warm-up
    println("\nWarming up...")
    for i in 1:5
        query_point = data[query_indices[i], :]
        ATRIANeighbors.knn(tree_atria, query_point, k=k+1)
        NearestNeighbors.knn(tree_kd, query_point, k+1, true)
    end

    # ATRIA benchmark
    println("\n1. Benchmarking ATRIA queries...")
    atria_times = Float64[]
    atria_f_k_values = Float64[]

    for query_idx in query_indices
        query_point = data[query_idx, :]

        time = @elapsed neighbors, stats = ATRIANeighbors.knn(tree_atria, query_point, k=k+1, track_stats=true)
        push!(atria_times, time * 1000)  # Convert to ms
        push!(atria_f_k_values, stats.f_k)
    end

    atria_mean = mean(atria_times)
    atria_median = median(atria_times)
    atria_std = std(atria_times)
    atria_min = minimum(atria_times)
    atria_max = maximum(atria_times)
    mean_f_k = mean(atria_f_k_values)

    println("   Mean:   $(round(atria_mean, digits=4)) ms")
    println("   Median: $(round(atria_median, digits=4)) ms")
    println("   Min:    $(round(atria_min, digits=4)) ms")
    println("   Max:    $(round(atria_max, digits=4)) ms")
    println("   Std:    $(round(atria_std, digits=4)) ms")
    println("   Mean f_k: $(round(mean_f_k, digits=5)) ($(round(1/mean_f_k, digits=1))x vs brute force)")

    # KDTree benchmark
    println("\n2. Benchmarking KDTree queries...")
    kd_times = Float64[]

    for query_idx in query_indices
        query_point = data[query_idx, :]

        time = @elapsed idxs, dists = NearestNeighbors.knn(tree_kd, query_point, k+1, true)
        push!(kd_times, time * 1000)  # Convert to ms
    end

    kd_mean = mean(kd_times)
    kd_median = median(kd_times)
    kd_std = std(kd_times)
    kd_min = minimum(kd_times)
    kd_max = maximum(kd_times)

    println("   Mean:   $(round(kd_mean, digits=4)) ms")
    println("   Median: $(round(kd_median, digits=4)) ms")
    println("   Min:    $(round(kd_min, digits=4)) ms")
    println("   Max:    $(round(kd_max, digits=4)) ms")
    println("   Std:    $(round(kd_std, digits=4)) ms")

    # Comparison
    println("\n" * "-"^80)
    println("COMPARISON")
    println("-"^80)

    speedup = kd_mean / atria_mean

    println("\nQuery time ratio (ATRIA/KDTree): $(round(atria_mean / kd_mean, digits=2))x")
    if speedup < 1.0
        println("   ❌ ATRIA is $(round(1/speedup, digits=2))x SLOWER than KDTree")
    else
        println("   ✅ ATRIA is $(round(speedup, digits=2))x FASTER than KDTree")
    end

    println("\nVariance comparison:")
    println("   ATRIA CV (std/mean): $(round(atria_std / atria_mean, digits=3))")
    println("   KDTree CV (std/mean): $(round(kd_std / kd_mean, digits=3))")

    # Use @benchmark for more accurate measurements
    println("\n" * "-"^80)
    println("DETAILED BENCHMARK (BenchmarkTools)")
    println("-"^80)

    println("\n1. ATRIA single query:")
    query_point = data[query_indices[1], :]
    @btime ATRIANeighbors.knn($tree_atria, $query_point, k=$(k+1))

    println("\n2. KDTree single query:")
    @btime NearestNeighbors.knn($tree_kd, $query_point, $(k+1), true)

    # Profile if requested
    println("\n\nRun profiling? (will take longer)")
    println("Skipping profiling for now - uncomment to enable")
    # profile_search_loop(tree_atria, tree_kd, data, min(n_queries, 1000), k)

    return Dict(
        "atria_mean" => atria_mean,
        "kd_mean" => kd_mean,
        "speedup" => speedup,
        "mean_f_k" => mean_f_k
    )
end

"""
    run_profiling_tests()

Run profiling tests on different datasets.
"""
function run_profiling_tests()
    println("="^80)
    println("ATRIA vs KDTree PROFILING")
    println("="^80)

    # Test 1: Random clustered data (should favor both methods)
    println("\n\nTEST 1: Random Clustered Data (N=2000, D=20)")
    println("+"^80)

    n_clusters = 10
    points_per_cluster = 200
    D = 20
    data1 = zeros(n_clusters * points_per_cluster, D)

    for i in 1:n_clusters
        center = randn(D) * 5.0
        start_idx = (i-1) * points_per_cluster + 1
        end_idx = i * points_per_cluster
        data1[start_idx:end_idx, :] = center' .+ randn(points_per_cluster, D) * 0.5
    end

    benchmark_detailed(data1, 10, 100)

    # Test 2: Chaotic attractor (should favor ATRIA)
    println("\n\nTEST 2: Lorenz Attractor (N=10000, D=25)")
    println("+"^80)

    include("chaotic_attractors_v2.jl")
    lorenz_data, _ = generate_lorenz_attractor(N=10000, Ds=25, Δt=0.01, delay=2)

    benchmark_detailed(lorenz_data, 10, 100)

    println("\n\n" * "="^80)
    println("PROFILING COMPLETE")
    println("="^80)
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_profiling_tests()
end

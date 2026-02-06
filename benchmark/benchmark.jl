#!/usr/bin/env julia
"""
ATRIANeighbors.jl Unified Benchmark Suite

Single entry point for all benchmarking and profiling operations.

Usage:
    julia --project=benchmark benchmark/benchmark.jl <command> [options]

Commands:
    quick           Fast sanity check (data distribution demo)
    readme          Generate performance table for README
    compare         Library comparison (quick|standard|comprehensive)
    profile-alloc   Profile memory allocations
    profile-perf    Profile performance bottlenecks

Examples:
    julia --project=benchmark benchmark/benchmark.jl quick
    julia --project=benchmark benchmark/benchmark.jl compare quick
    julia --project=benchmark benchmark/benchmark.jl readme
"""

using Pkg
Pkg.activate(@__DIR__)

using ATRIANeighbors
using ATRIANeighbors: EuclideanMetric, brute_knn
using BenchmarkTools
using Random
using Printf
using Profile

# Import NearestNeighbors as NN to avoid name conflicts with ATRIANeighbors.knn
import NearestNeighbors as NN

# Load supporting libraries
include(joinpath(@__DIR__, "utils", "data_generators.jl"))

# Load library comparison (defines run_full_benchmark function)
include(joinpath(@__DIR__, "run_full_comparison.jl"))

# =============================================================================
# Command Implementations
# =============================================================================

"""Quick benchmark: Data distribution demonstration"""
function cmd_quick()
    println("ATRIA vs NEARESTNEIGHBORS: WHEN TO USE WHICH")
    println("="^80)
    println("\nNearestNeighbors.jl excels in LOW-dimensional space (e.g. 2D–5D).")
    println("ATRIA excels for HIGH embedding dimension (e.g. 20–40D) with LOW")
    println("fractal dimension (e.g. delay embeddings of chaotic attractors).")
    println("\nThis quick demo shows ATRIA's pruning vs data structure:\n")

    Random.seed!(42)
    N, D, k = 1000, 20, 10

    # Test 1: Random uniform data (worst case for trees)
    println("\n1. RANDOM UNIFORM DATA (worst case)")
    println("-"^80)
    data_uniform = randn(D, N)  # D×N layout
    ps_uniform = PointSet(data_uniform, EuclideanMetric())
    tree_uniform = ATRIATree(ps_uniform, min_points=10)
    query_uniform = randn(D)

    _, stats_uniform = ATRIANeighbors.knn(tree_uniform, query_uniform, k=k, track_stats=true)
    println("Distance calculations: $(stats_uniform.distance_calcs) / $N")
    println("f_k: $(round(stats_uniform.f_k, digits=3))")
    println("Pruning: $(round(100 * (1 - stats_uniform.f_k), digits=1))%")

    atria_time_uniform = @belapsed ATRIANeighbors.knn($tree_uniform, $query_uniform, k=$k)
    brute_time_uniform = @belapsed brute_knn($ps_uniform, $query_uniform, $k)
    println("ATRIA: $(round(atria_time_uniform*1e6, digits=1))μs")
    println("Brute: $(round(brute_time_uniform*1e6, digits=1))μs")
    println("Speedup: $(round(brute_time_uniform / atria_time_uniform, digits=2))x")

    # Test 2: Clustered data (favorable for trees)
    println("\n2. CLUSTERED DATA (10 tight clusters)")
    println("-"^80)
    n_clusters = 10
    points_per_cluster = N ÷ n_clusters
    data_clustered = zeros(D, N)  # D×N layout

    for i in 1:n_clusters
        center = randn(D) * 10.0
        start_idx = (i-1) * points_per_cluster + 1
        end_idx = min(i * points_per_cluster, N)
        n_points = end_idx - start_idx + 1
        data_clustered[:, start_idx:end_idx] = center .+ randn(D, n_points) * 0.3
    end

    ps_clustered = PointSet(data_clustered, EuclideanMetric())
    tree_clustered = ATRIATree(ps_clustered, min_points=10)
    query_clustered = data_clustered[:, 1] + randn(D) * 0.1

    _, stats_clustered = ATRIANeighbors.knn(tree_clustered, query_clustered, k=k, track_stats=true)
    println("Distance calculations: $(stats_clustered.distance_calcs) / $N")
    println("f_k: $(round(stats_clustered.f_k, digits=3))")
    println("Pruning: $(round(100 * (1 - stats_clustered.f_k), digits=1))%")

    atria_time_clustered = @belapsed ATRIANeighbors.knn($tree_clustered, $query_clustered, k=$k)
    brute_time_clustered = @belapsed brute_knn($ps_clustered, $query_clustered, $k)
    println("ATRIA: $(round(atria_time_clustered*1e6, digits=1))μs")
    println("Brute: $(round(brute_time_clustered*1e6, digits=1))μs")
    println("Speedup: $(round(brute_time_clustered / atria_time_clustered, digits=2))x")

    # Test 3: Very clustered data
    println("\n3. VERY CLUSTERED DATA (100 tiny clusters)")
    println("-"^80)
    n_clusters_many = 100
    points_per_cluster_small = N ÷ n_clusters_many
    data_very_clustered = zeros(D, N)  # D×N layout

    for i in 1:n_clusters_many
        center = randn(D) * 20.0
        start_idx = (i-1) * points_per_cluster_small + 1
        end_idx = min(i * points_per_cluster_small, N)
        n_points = end_idx - start_idx + 1
        data_very_clustered[:, start_idx:end_idx] = center .+ randn(D, n_points) * 0.1
    end

    ps_very_clustered = PointSet(data_very_clustered, EuclideanMetric())
    tree_very_clustered = ATRIATree(ps_very_clustered, min_points=10)
    query_very_clustered = data_very_clustered[:, 1] + randn(D) * 0.05

    _, stats_very_clustered = ATRIANeighbors.knn(tree_very_clustered, query_very_clustered, k=k, track_stats=true)
    println("Distance calculations: $(stats_very_clustered.distance_calcs) / $N")
    println("f_k: $(round(stats_very_clustered.f_k, digits=3))")
    println("Pruning: $(round(100 * (1 - stats_very_clustered.f_k), digits=1))%")

    atria_time_very = @belapsed ATRIANeighbors.knn($tree_very_clustered, $query_very_clustered, k=$k)
    brute_time_very = @belapsed brute_knn($ps_very_clustered, $query_very_clustered, $k)
    println("ATRIA: $(round(atria_time_very*1e6, digits=1))μs")
    println("Brute: $(round(brute_time_very*1e6, digits=1))μs")
    println("Speedup: $(round(brute_time_very / atria_time_very, digits=2))x")

    println("\n" * "="^80)
    println("SUMMARY")
    println("="^80)
    println("Random data:        f_k=$(round(stats_uniform.f_k, digits=2)), speedup=$(round(brute_time_uniform/atria_time_uniform, digits=2))x")
    println("Clustered data:     f_k=$(round(stats_clustered.f_k, digits=2)), speedup=$(round(brute_time_clustered/atria_time_clustered, digits=2))x")
    println("Very clustered:     f_k=$(round(stats_very_clustered.f_k, digits=2)), speedup=$(round(brute_time_very/atria_time_very, digits=2))x")

    println("\nConclusion: ATRIA's performance depends HEAVILY on data structure!")
    if stats_very_clustered.f_k < 0.1
        println("✅ ATRIA CAN achieve good pruning on appropriate data!")
    end
end

"""Run a single benchmark scenario and return (atria_build, atria_query, kdtree_build, kdtree_query, balltree_build, balltree_query, brute_query) in ms."""
function _run_readme_scenario(data::Matrix{Float64}, queries::Matrix{Float64}, k::Int, n_queries::Int)
    ps = PointSet(data, EuclideanMetric())
    # ATRIA
    atria_build = @benchmark ATRIATree($ps, min_points=64) samples=5
    tree_atria = ATRIATree(ps, min_points=64)
    atria_query = @benchmark ATRIANeighbors.knn($tree_atria, $queries, k=$k) samples=20
    atria_build_time = median(atria_build).time / 1e6
    atria_query_time = (median(atria_query).time / 1e6) / n_queries
    # KDTree
    kdtree_build = @benchmark NN.KDTree($data, leafsize=10) samples=5
    tree_kd = NN.KDTree(data, leafsize=10)
    kdtree_query = @benchmark NN.knn($tree_kd, $queries, $k) samples=20
    kdtree_build_time = median(kdtree_build).time / 1e6
    kdtree_query_time = (median(kdtree_query).time / 1e6) / n_queries
    # BallTree
    balltree_build = @benchmark NN.BallTree($data, leafsize=10) samples=5
    tree_ball = NN.BallTree(data, leafsize=10)
    balltree_query = @benchmark NN.knn($tree_ball, $queries, $k) samples=20
    balltree_build_time = median(balltree_build).time / 1e6
    balltree_query_time = (median(balltree_query).time / 1e6) / n_queries
    # Brute
    brute_query = @benchmark brute_knn($ps, $queries, $k) samples=10
    brute_query_time = (median(brute_query).time / 1e6) / n_queries
    return (; atria_build_time, atria_query_time, kdtree_build_time, kdtree_query_time,
            balltree_build_time, balltree_query_time, brute_query_time)
end

"""Generate README performance table: low-D (NearestNeighbors wins) vs high-D low-fractal (ATRIA wins)."""
function cmd_readme()
    println("="^80)
    println("ATRIANeighbors.jl Performance Benchmark (README tables)")
    println("="^80)
    k = 10
    n_queries = 100
    rng = MersenneTwister(42)

    # -------------------------------------------------------------------------
    # Scenario A: Low-dimensional (3D Lorenz) — NearestNeighbors excels here
    # -------------------------------------------------------------------------
    N_low = 50_000
    D_low = 3
    println()
    println("Scenario A: LOW-DIMENSIONAL (D=$D_low) — NearestNeighbors.jl excels")
    println("  Lorenz attractor, N=$N_low, D=$D_low, k=$k, $n_queries queries")
    println("  Generating data...")
    data_low = generate_dataset(:lorenz, N_low, D_low, rng=rng)
    query_indices_low = rand(rng, 1:N_low, n_queries)
    queries_low = copy(data_low[:, query_indices_low])
    queries_low .+= randn(rng, size(queries_low)...) .* 0.01
    println("  Running benchmarks...")
    res_low = _run_readme_scenario(data_low, queries_low, k, n_queries)

    println()
    println("| Algorithm | Build Time | Query Time | Speedup vs Brute |")
    println("|-----------|------------|------------|------------------|")
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "ATRIA", res_low.atria_build_time, res_low.atria_query_time, res_low.brute_query_time / res_low.atria_query_time)
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "KDTree", res_low.kdtree_build_time, res_low.kdtree_query_time, res_low.brute_query_time / res_low.kdtree_query_time)
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "BallTree", res_low.balltree_build_time, res_low.balltree_query_time, res_low.brute_query_time / res_low.balltree_query_time)
    @printf("| %-9s | %10s | %8.3f ms | %16s |\n",
            "Brute", "-", res_low.brute_query_time, "1x")
    best_low = min(res_low.atria_query_time, res_low.kdtree_query_time, res_low.balltree_query_time)
    winner_low = res_low.kdtree_query_time <= res_low.atria_query_time ? "KDTree" : "ATRIA"
    println("  → Best query time: $(winner_low) ($(round(best_low, digits=3)) ms/query)")

    # -------------------------------------------------------------------------
    # Scenario B: High-D, low fractal (delay-embedded Lorenz) — ATRIA excels
    # -------------------------------------------------------------------------
    N_high = 50_000
    D_high = 24   # 20–40D with low fractal dimension is ATRIA's sweet spot
    println()
    println("Scenario B: HIGH-DIMENSIONAL, LOW FRACTAL DIMENSION (D=$D_high) — ATRIA excels")
    println("  Delay-embedded Lorenz attractor, N=$N_high, D=$D_high, k=$k, $n_queries queries")
    println("  (Embedding dimension $D_high, fractal dimension ≈ 2.06)")
    println("  Generating data...")
    data_high = generate_dataset(:lorenz_delay, N_high, D_high, rng=rng)
    query_indices_high = rand(rng, 1:N_high, n_queries)
    queries_high = copy(data_high[:, query_indices_high])
    queries_high .+= randn(rng, size(queries_high)...) .* 0.01
    println("  Running benchmarks...")
    res_high = _run_readme_scenario(data_high, queries_high, k, n_queries)

    println()
    println("| Algorithm | Build Time | Query Time | Speedup vs Brute |")
    println("|-----------|------------|------------|------------------|")
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "ATRIA", res_high.atria_build_time, res_high.atria_query_time, res_high.brute_query_time / res_high.atria_query_time)
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "KDTree", res_high.kdtree_build_time, res_high.kdtree_query_time, res_high.brute_query_time / res_high.kdtree_query_time)
    @printf("| %-9s | %7.0f ms | %8.3f ms | %16.0fx |\n",
            "BallTree", res_high.balltree_build_time, res_high.balltree_query_time, res_high.brute_query_time / res_high.balltree_query_time)
    @printf("| %-9s | %10s | %8.3f ms | %16s |\n",
            "Brute", "-", res_high.brute_query_time, "1x")
    best_high = min(res_high.atria_query_time, res_high.kdtree_query_time, res_high.balltree_query_time)
    winner_high = res_high.atria_query_time <= res_high.kdtree_query_time ? "ATRIA" : "KDTree"
    println("  → Best query time: $(winner_high) ($(round(best_high, digits=3)) ms/query)")

    println()
    println("="^80)
    println("SUMMARY (copy tables above into README)")
    println("="^80)
    println("Low-D (3D):     NearestNeighbors (KDTree/BallTree) typically wins.")
    println("High-D low-Df: ATRIA typically wins (delay embeddings of chaotic attractors).")
    println()
end

"""Library comparison"""
function cmd_compare(mode_str::String="quick")
    mode = Symbol(mode_str)
    if !(mode in [:quick, :standard, :comprehensive])
        error("Unknown mode: $mode_str. Choose from: quick, standard, comprehensive")
    end

    run_full_benchmark(mode=mode)
end

"""Profile memory allocations"""
function cmd_profile_alloc()
    println("="^80)
    println("ALLOCATION PROFILING (with SearchContext reuse)")
    println("="^80)

    # Create test dataset (D×N layout)
    N, D = 1000, 20
    data = randn(D, N)

    println("\nDataset: N=$N, D=$D")
    println("Building ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIATree(ps, min_points=10)

    query_point = randn(D)
    k = 10

    println("\n" * "-"^80)
    println("TEST 1: WITHOUT SearchContext reuse")
    println("-"^80)

    # Warmup
    for _ in 1:5
        ATRIANeighbors.knn(tree, query_point, k=k)
    end

    println("@btime analysis:")
    @btime ATRIANeighbors.knn($tree, $query_point, k=$k)
    bytes_without = @allocated ATRIANeighbors.knn(tree, query_point, k=k)
    println("@allocated: $bytes_without bytes")

    println("\n" * "-"^80)
    println("TEST 2: WITH SearchContext reuse (recommended for batch queries)")
    println("-"^80)

    # Create reusable context
    ctx = SearchContext(tree, k)

    # Warmup
    for _ in 1:5
        ATRIANeighbors.knn(tree, query_point, k=k, ctx=ctx)
    end

    println("@btime analysis:")
    @btime ATRIANeighbors.knn($tree, $query_point, k=$k, ctx=$ctx)
    bytes_with = @allocated ATRIANeighbors.knn(tree, query_point, k=k, ctx=ctx)
    println("@allocated: $bytes_with bytes")

    println("\n" * "="^80)
    println("SUMMARY")
    println("="^80)
    println("WITHOUT context reuse: $bytes_without bytes")
    println("WITH context reuse:    $bytes_with bytes")
    println("Reduction: $(bytes_without - bytes_with) bytes ($(round(100 * (1 - bytes_with/bytes_without), digits=1))%)")
    println("\n✅ Use SearchContext reuse for batch queries to minimize allocations!")
end

"""Profile performance bottlenecks"""
function cmd_profile_perf()
    include(joinpath(@__DIR__, "analyze_bottlenecks.jl"))
end

# =============================================================================
# Command Line Interface
# =============================================================================

function print_help()
    println("""
    ATRIANeighbors.jl Unified Benchmark Suite

    Usage:
        julia --project=benchmark benchmark/benchmark.jl <command> [options]

    Commands:
        quick              Fast sanity check (data distribution demo)
        readme             Generate performance table for README
        compare [mode]     Library comparison
                          Modes: quick, standard, comprehensive
        profile-alloc      Profile memory allocations
        profile-perf       Profile performance bottlenecks
        help               Show this help message

    Examples:
        julia --project=benchmark benchmark/benchmark.jl quick
        julia --project=benchmark benchmark/benchmark.jl compare quick
        julia --project=benchmark benchmark/benchmark.jl readme
        julia --project=benchmark benchmark/benchmark.jl profile-alloc
    """)
end

function main()
    if length(ARGS) == 0
        println("Error: No command specified\n")
        print_help()
        exit(1)
    end

    cmd = ARGS[1]

    if cmd == "quick"
        cmd_quick()
    elseif cmd == "readme"
        cmd_readme()
    elseif cmd == "compare"
        mode = length(ARGS) >= 2 ? ARGS[2] : "quick"
        cmd_compare(mode)
    elseif cmd == "profile-alloc"
        cmd_profile_alloc()
    elseif cmd == "profile-perf"
        cmd_profile_perf()
    elseif cmd == "help" || cmd == "--help" || cmd == "-h"
        print_help()
    else
        println("Error: Unknown command '$cmd'\n")
        print_help()
        exit(1)
    end
end

# Run if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

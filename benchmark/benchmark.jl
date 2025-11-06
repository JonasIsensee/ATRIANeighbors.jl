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
    println("ATRIA PERFORMANCE VS DATA DISTRIBUTION")
    println("="^80)
    println("\nThis benchmark demonstrates that ATRIA excels at data with")
    println("low intrinsic dimensionality (manifold structure) but performs")
    println("poorly on random high-dimensional data.\n")

    Random.seed!(42)
    N, D, k = 1000, 20, 10

    # Test 1: Random uniform data (worst case for trees)
    println("\n1. RANDOM UNIFORM DATA (worst case)")
    println("-"^80)
    data_uniform = randn(N, D)
    ps_uniform = PointSet(data_uniform, EuclideanMetric())
    tree_uniform = ATRIA(ps_uniform, min_points=10)
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
    data_clustered = zeros(N, D)

    for i in 1:n_clusters
        center = randn(D) * 10.0
        start_idx = (i-1) * points_per_cluster + 1
        end_idx = min(i * points_per_cluster, N)
        n_points = end_idx - start_idx + 1
        data_clustered[start_idx:end_idx, :] = center' .+ randn(n_points, D) * 0.3
    end

    ps_clustered = PointSet(data_clustered, EuclideanMetric())
    tree_clustered = ATRIA(ps_clustered, min_points=10)
    query_clustered = data_clustered[1, :] + randn(D) * 0.1

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
    data_very_clustered = zeros(N, D)

    for i in 1:n_clusters_many
        center = randn(D) * 20.0
        start_idx = (i-1) * points_per_cluster_small + 1
        end_idx = min(i * points_per_cluster_small, N)
        n_points = end_idx - start_idx + 1
        data_very_clustered[start_idx:end_idx, :] = center' .+ randn(n_points, D) * 0.1
    end

    ps_very_clustered = PointSet(data_very_clustered, EuclideanMetric())
    tree_very_clustered = ATRIA(ps_very_clustered, min_points=10)
    query_very_clustered = data_very_clustered[1, :] + randn(D) * 0.05

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

"""Generate README performance table"""
function cmd_readme()
    println("="^80)
    println("ATRIANeighbors.jl Performance Benchmark")
    println("="^80)
    println()

    # Configuration
    N = 50_000
    D = 3
    k = 10
    n_queries = 100

    println("Configuration:")
    println("  Dataset size:    N = $N points")
    println("  Dimensions:      D = $D")
    println("  Neighbors:       k = $k")
    println("  Queries:         $n_queries")
    println("  Data type:       Lorenz attractor (fractal dimension ≈ 2.06)")
    println()

    # Generate Lorenz data
    println("Generating Lorenz attractor data...")
    rng = MersenneTwister(42)
    data = generate_dataset(:lorenz, N, D, rng=rng)

    # Generate queries
    query_indices = rand(rng, 1:N, n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    println("Building trees...")
    println()

    # ATRIA
    println("ATRIA:")
    ps = PointSet(data, EuclideanMetric())
    atria_build = @benchmark ATRIA($ps, min_points=64) samples=5
    tree_atria = ATRIA(ps, min_points=64)

    function atria_queries()
        for i in 1:n_queries
            ATRIANeighbors.knn(tree_atria, queries[i, :], k=k)
        end
    end
    atria_query = @benchmark $atria_queries() samples=20
    atria_build_time = median(atria_build).time / 1e6
    atria_query_time = (median(atria_query).time / 1e6) / n_queries
    println("  Build time:  $(round(atria_build_time, digits=2)) ms")
    println("  Query time:  $(round(atria_query_time, digits=4)) ms")
    println()

    # KDTree
    println("KDTree:")
    data_transposed = Matrix(data')
    kdtree_build = @benchmark NN.KDTree($data_transposed, leafsize=10) samples=5
    tree_kd = NN.KDTree(data_transposed, leafsize=10)

    function kdtree_queries()
        for i in 1:n_queries
            NN.knn(tree_kd, queries[i, :], k)
        end
    end
    kdtree_query = @benchmark $kdtree_queries() samples=20
    kdtree_build_time = median(kdtree_build).time / 1e6
    kdtree_query_time = (median(kdtree_query).time / 1e6) / n_queries
    println("  Build time:  $(round(kdtree_build_time, digits=2)) ms")
    println("  Query time:  $(round(kdtree_query_time, digits=4)) ms")
    println()

    # BallTree
    println("BallTree:")
    balltree_build = @benchmark NN.BallTree($data_transposed, leafsize=10) samples=5
    tree_ball = NN.BallTree(data_transposed, leafsize=10)

    function balltree_queries()
        for i in 1:n_queries
            NN.knn(tree_ball, queries[i, :], k)
        end
    end
    balltree_query = @benchmark $balltree_queries() samples=20
    balltree_build_time = median(balltree_build).time / 1e6
    balltree_query_time = (median(balltree_query).time / 1e6) / n_queries
    println("  Build time:  $(round(balltree_build_time, digits=2)) ms")
    println("  Query time:  $(round(balltree_query_time, digits=4)) ms")
    println()

    # Brute force
    println("Brute force:")
    function brute_queries()
        for i in 1:n_queries
            brute_knn(ps, queries[i, :], k)
        end
    end
    brute_query = @benchmark $brute_queries() samples=10
    brute_query_time = (median(brute_query).time / 1e6) / n_queries
    println("  Build time:  - (no preprocessing)")
    println("  Query time:  $(round(brute_query_time, digits=4)) ms")
    println()

    # Summary table
    println("="^80)
    println("SUMMARY TABLE (for README)")
    println("="^80)
    println()
    println("| Algorithm | Build Time | Query Time | Speedup vs Brute |")
    println("|-----------|-----------|------------|------------------|")

    @printf("| %-9s | %6.0f ms | %7.2f ms | %15.0fx |\n",
            "ATRIA", atria_build_time, atria_query_time, brute_query_time/atria_query_time)
    @printf("| %-9s | %6.0f ms | %7.2f ms | %15.0fx |\n",
            "KDTree", kdtree_build_time, kdtree_query_time, brute_query_time/kdtree_query_time)
    @printf("| %-9s | %6.0f ms | %7.2f ms | %15.0fx |\n",
            "BallTree", balltree_build_time, balltree_query_time, brute_query_time/balltree_query_time)
    @printf("| %-9s | %9s | %7.2f ms | %15s |\n",
            "Brute", "-", brute_query_time, "1x")
    println()

    atria_speedup = kdtree_query_time / atria_query_time
    println("Performance relative to KDTree:")
    println("  ATRIA is $(round(atria_speedup, digits=2))x vs KDTree")
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

    # Create test dataset
    N, D = 1000, 20
    data = randn(N, D)

    println("\nDataset: N=$N, D=$D")
    println("Building ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

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

"""
    readme_benchmark.jl

Reproduces the performance comparison table shown in the README.

Usage:
    julia --project=. benchmark/readme_benchmark.jl

This benchmark compares ATRIA against KDTree, BallTree, and brute force search
on Lorenz attractor data (N=50,000 points, D=3, k=10 neighbors).
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using ATRIANeighbors
using NearestNeighbors
using BenchmarkTools
using Random
using Printf

function generate_lorenz(N; σ=10.0, ρ=28.0, β=8/3, dt=0.01, transient=1000)
    # Initial condition
    x, y, z = 1.0, 1.0, 1.0

    # Skip transient
    for _ in 1:transient
        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    # Generate points
    points = zeros(N, 3)
    for i in 1:N
        points[i, :] = [x, y, z]
        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z
        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    return points
end

function run_readme_benchmark()
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

    # Generate data
    println("Generating Lorenz attractor data...")
    rng = MersenneTwister(42)
    data = generate_lorenz(N)

    # Generate query points (from dataset with small noise)
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
            knn(tree_atria, queries[i, :], k=k)
        end
    end
    atria_query = @benchmark $atria_queries() samples=20
    atria_build_time = median(atria_build).time / 1e6  # ms
    atria_query_time = (median(atria_query).time / 1e6) / n_queries  # ms per query
    println("  Build time:  $(round(atria_build_time, digits=2)) ms")
    println("  Query time:  $(round(atria_query_time, digits=4)) ms")
    println()

    # KDTree
    println("KDTree:")
    data_transposed = Matrix(data')
    kdtree_build = @benchmark KDTree($data_transposed, leafsize=10) samples=5
    tree_kd = KDTree(data_transposed, leafsize=10)

    function kdtree_queries()
        for i in 1:n_queries
            NearestNeighbors.knn(tree_kd, queries[i, :], k)
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
    balltree_build = @benchmark BallTree($data_transposed, leafsize=10) samples=5
    tree_ball = BallTree(data_transposed, leafsize=10)

    function balltree_queries()
        for i in 1:n_queries
            NearestNeighbors.knn(tree_ball, queries[i, :], k)
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

    # Speedup comparison
    println("Performance relative to KDTree:")
    atria_speedup = kdtree_query_time / atria_query_time
    println("  ATRIA is $(round(atria_speedup, digits=2))x vs KDTree")
    println()

    println("="^80)
    println("Benchmark complete!")
    println("="^80)
end

# Run when executed as a script
if abspath(PROGRAM_FILE) == @__FILE__
    run_readme_benchmark()
end

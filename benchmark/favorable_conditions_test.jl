"""
Test ATRIA on favorable conditions where it should excel:
- High-dimensional data (D=20, 50)
- Clustered/non-uniform distributions
- Large k values
"""

using Pkg
Pkg.activate(@__DIR__)

using ATRIANeighbors
using BenchmarkTools
using NearestNeighbors
using Random
using Printf

# Load data generators
include("data_generators.jl")

println("=" ^ 80)
println("ATRIA Favorable Conditions Benchmark")
println("=" ^ 80)
println()
println("Testing conditions where ATRIA should perform well:")
println("  - High-dimensional data (D=20, 50)")
println("  - Clustered distributions (Gaussian mixtures)")
println("  - Various k values")
println()

rng = MersenneTwister(42)

# Test parameters - favorable for ATRIA
test_configs = [
    # (name, N, D, k, dataset_type)
    ("High-D clustered (small)", 1000, 20, 10, :gaussian_mixture),
    ("High-D clustered (medium)", 2000, 20, 10, :gaussian_mixture),
    ("Very high-D clustered", 1000, 50, 10, :gaussian_mixture),
    ("High-D large k", 1000, 20, 50, :gaussian_mixture),
    ("High-D hierarchical", 1000, 20, 10, :hierarchical),
]

n_queries = 20
results = []

for (name, N, D, k, dataset_type) in test_configs
    println("Testing: $name (N=$N, D=$D, k=$k)")
    println("-" ^ 80)

    # Generate data
    data = generate_dataset(dataset_type, N, D, rng=rng)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    # === ATRIA ===
    println("  Building ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    atria_build = @benchmark ATRIA($ps, min_points=32) samples=3
    atria_tree = ATRIA(ps, min_points=32)

    build_time = median(atria_build).time / 1e6
    println("    Build time: $(round(build_time, digits=2)) ms")
    println("    Clusters: $(atria_tree.total_clusters) ($(atria_tree.terminal_nodes) terminal)")

    # Benchmark queries
    function run_atria_queries()
        for i in 1:n_queries
            ATRIANeighbors.knn(atria_tree, queries[i, :], k=k)
        end
    end
    atria_query = @benchmark $run_atria_queries() samples=3
    atria_time_per_query = (median(atria_query).time / 1e6) / n_queries
    println("    Query time: $(round(atria_time_per_query, digits=3)) ms per query")

    # === KDTree ===
    println("  Building KDTree...")
    data_transposed = Matrix(data')
    kdtree_build = @benchmark KDTree($data_transposed, leafsize=32) samples=3
    kdtree = KDTree(data_transposed, leafsize=32)

    kdtree_build_time = median(kdtree_build).time / 1e6
    println("    Build time: $(round(kdtree_build_time, digits=2)) ms")

    # Benchmark queries
    function run_kdtree_queries()
        for i in 1:n_queries
            NearestNeighbors.knn(kdtree, queries[i, :], k)
        end
    end
    kdtree_query = @benchmark $run_kdtree_queries() samples=3
    kdtree_time_per_query = (median(kdtree_query).time / 1e6) / n_queries
    println("    Query time: $(round(kdtree_time_per_query, digits=3)) ms per query")

    # === BruteTree (for small datasets only) ===
    if N <= 2000
        println("  Building BruteTree...")
        brutetree_build = @benchmark BruteTree($data_transposed) samples=3
        brutetree = BruteTree(data_transposed)

        brute_build_time = median(brutetree_build).time / 1e6
        println("    Build time: $(round(brute_build_time, digits=2)) ms")

        # Benchmark queries
        function run_brutetree_queries()
            for i in 1:n_queries
                NearestNeighbors.knn(brutetree, queries[i, :], k)
            end
        end
        brutetree_query = @benchmark $run_brutetree_queries() samples=3
        brutetree_time_per_query = (median(brutetree_query).time / 1e6) / n_queries
        println("    Query time: $(round(brutetree_time_per_query, digits=3)) ms per query")
    else
        brutetree_time_per_query = NaN
        brute_build_time = NaN
    end

    # Calculate speedups
    speedup_vs_kdtree = kdtree_time_per_query / atria_time_per_query
    if !isnan(brutetree_time_per_query)
        speedup_vs_brute = brutetree_time_per_query / atria_time_per_query
        println("  Speedup vs BruteTree: $(round(speedup_vs_brute, digits=2))x")
    end
    println("  Speedup vs KDTree: $(round(speedup_vs_kdtree, digits=2))x")

    # Build time comparison
    build_ratio = build_time / kdtree_build_time
    println("  Build time ratio (ATRIA/KDTree): $(round(build_ratio, digits=2))x")
    println()

    push!(results, (
        name=name,
        N=N,
        D=D,
        k=k,
        atria_build=build_time,
        atria_query=atria_time_per_query,
        kdtree_build=kdtree_build_time,
        kdtree_query=kdtree_time_per_query,
        brutetree_query=brutetree_time_per_query,
        speedup_vs_kdtree=speedup_vs_kdtree,
    ))
end

println("=" ^ 80)
println("Summary Table")
println("=" ^ 80)
println(@sprintf("%-30s %6s %4s %4s %10s %10s %10s",
    "Test Case", "N", "D", "k", "ATRIA (ms)", "KDTree (ms)", "Speedup"))
println("-" ^ 80)

for r in results
    println(@sprintf("%-30s %6d %4d %4d %10.3f %10.3f %9.2fx",
        r.name, r.N, r.D, r.k, r.atria_query, r.kdtree_query, r.speedup_vs_kdtree))
end

println("=" ^ 80)
println()

# Analyze results
println("Analysis:")
println("-" ^ 80)

best = maximum(r -> r.speedup_vs_kdtree, results)
worst = minimum(r -> r.speedup_vs_kdtree, results)
avg = sum(r -> r.speedup_vs_kdtree, results) / length(results)

println("Best speedup vs KDTree: $(round(best, digits=2))x")
println("Worst speedup vs KDTree: $(round(worst, digits=2))x")
println("Average speedup vs KDTree: $(round(avg, digits=2))x")
println()

if avg >= 1.0
    println("✓ ATRIA performs well on these favorable conditions!")
    println("  Average speedup of $(round(avg, digits=2))x over KDTree")
elseif avg >= 0.5
    println("⚠ ATRIA performance is competitive but not superior")
    println("  Further optimization may be needed")
else
    println("✗ ATRIA still underperforming on favorable conditions")
    println("  Additional investigation required")
end

println()
println("✓ Favorable conditions benchmark completed!")

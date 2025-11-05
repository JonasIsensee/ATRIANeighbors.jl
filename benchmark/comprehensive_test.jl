"""
Comprehensive benchmark test - tests scenarios where ATRIA should excel:
- High-dimensional data (D > 10)
- Larger datasets (N > 1000)
- Time-delay embedded attractors
- Non-uniform distributions
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
println("Comprehensive Benchmark - ATRIA Sweet Spot Tests")
println("=" ^ 80)

# Test configurations
configs = [
    # (description, dataset_type, N, D, k)
    ("Small D=10", :gaussian_mixture, 1000, 10, 10),
    ("Medium D=20", :gaussian_mixture, 2000, 20, 10),
    ("High D=50", :gaussian_mixture, 5000, 50, 10),
    ("Lorenz Attractor (3D)", :lorenz, 5000, 3, 10),
    ("Clustered D=30", :gaussian_mixture, 3000, 30, 10),
    ("Hierarchical D=20", :hierarchical, 2000, 20, 10),
]

n_queries = 50
rng = MersenneTwister(42)

results = []

for (desc, dataset_type, N, D, k) in configs
    println("\n" * "=" ^ 80)
    println("Test: $desc")
    println("  Dataset: $dataset_type, N=$N, D=$D, k=$k")
    println("=" ^ 80)

    # Generate data
    println("  Generating dataset...")
    data = generate_dataset(dataset_type, N, D, rng=rng)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    # === ATRIA ===
    println("  [ATRIA]")
    print("    Building tree... ")
    ps = PointSet(data, EuclideanMetric())
    atria_build = @benchmark ATRIA($ps, min_points=64) samples=5
    atria_tree = ATRIA(ps, min_points=64)
    println("✓ $(round(median(atria_build).time / 1e6, digits=2)) ms")
    println("      Clusters: $(atria_tree.total_clusters) ($(atria_tree.terminal_nodes) terminal)")

    print("    Querying... ")
    function run_atria_queries()
        for i in 1:n_queries
            ATRIANeighbors.knn(atria_tree, queries[i, :], k=k)
        end
    end
    atria_query = @benchmark $run_atria_queries() samples=5
    atria_time_per_query = (median(atria_query).time / 1e6) / n_queries
    println("✓ $(round(atria_time_per_query, digits=3)) ms per query")

    # === KDTree ===
    println("  [KDTree]")
    print("    Building tree... ")
    data_transposed = Matrix(data')
    kdtree_build = @benchmark KDTree($data_transposed) samples=5
    kdtree = KDTree(data_transposed)
    println("✓ $(round(median(kdtree_build).time / 1e6, digits=2)) ms")

    print("    Querying... ")
    function run_kdtree_queries()
        for i in 1:n_queries
            NearestNeighbors.knn(kdtree, queries[i, :], k)
        end
    end
    kdtree_query = @benchmark $run_kdtree_queries() samples=5
    kdtree_time_per_query = (median(kdtree_query).time / 1e6) / n_queries
    println("✓ $(round(kdtree_time_per_query, digits=3)) ms per query")

    # === BruteTree (skip for large datasets) ===
    brutetree_time_per_query = 0.0
    if N <= 3000
        println("  [BruteTree]")
        print("    Building tree... ")
        brutetree_build = @benchmark BruteTree($data_transposed) samples=5
        brutetree = BruteTree(data_transposed)
        println("✓ $(round(median(brutetree_build).time / 1e6, digits=2)) ms")

        print("    Querying... ")
        function run_brutetree_queries()
            for i in 1:n_queries
                NearestNeighbors.knn(brutetree, queries[i, :], k)
            end
        end
        brutetree_query = @benchmark $run_brutetree_queries() samples=5
        brutetree_time_per_query = (median(brutetree_query).time / 1e6) / n_queries
        println("✓ $(round(brutetree_time_per_query, digits=3)) ms per query")
    else
        println("  [BruteTree] Skipped (dataset too large)")
    end

    # Calculate speedups
    speedup_vs_kdtree = kdtree_time_per_query / atria_time_per_query
    speedup_vs_brute = brutetree_time_per_query > 0 ? brutetree_time_per_query / atria_time_per_query : 0.0

    println("\n  Results:")
    println("    Speedup vs KDTree: $(round(speedup_vs_kdtree, digits=2))x")
    if speedup_vs_brute > 0
        println("    Speedup vs BruteTree: $(round(speedup_vs_brute, digits=2))x")
    end

    push!(results, (
        desc=desc,
        dataset=dataset_type,
        N=N,
        D=D,
        atria_query=atria_time_per_query,
        kdtree_query=kdtree_time_per_query,
        brutetree_query=brutetree_time_per_query,
        speedup_vs_kdtree=speedup_vs_kdtree,
        speedup_vs_brute=speedup_vs_brute
    ))
end

println("\n" * "=" ^ 80)
println("Summary Table")
println("=" ^ 80)
println(@sprintf("%-25s %6s %6s %12s %12s %10s %10s",
    "Test", "N", "D", "ATRIA (ms)", "KDTree (ms)", "vs KDTree", "vs Brute"))
println("-" ^ 80)

for r in results
    brute_str = r.speedup_vs_brute > 0 ? @sprintf("%.2fx", r.speedup_vs_brute) : "N/A"
    println(@sprintf("%-25s %6d %6d %12.3f %12.3f %9.2fx %10s",
        r.desc, r.N, r.D, r.atria_query, r.kdtree_query,
        r.speedup_vs_kdtree, brute_str))
end

println("=" ^ 80)

# Analysis
println("\nAnalysis:")
atria_wins = count(r -> r.speedup_vs_kdtree > 1.0, results)
println("  ATRIA faster than KDTree: $atria_wins/$(length(results)) cases")

if atria_wins > 0
    best = maximum(r -> r.speedup_vs_kdtree, results)
    best_case = findfirst(r -> r.speedup_vs_kdtree == best, results)
    println("  Best speedup: $(round(best, digits=2))x on $(results[best_case].desc)")
end

println("\n✓ Comprehensive benchmark completed!")

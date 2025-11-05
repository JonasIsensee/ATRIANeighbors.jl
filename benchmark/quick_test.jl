"""
Quick benchmark test script (no plotting dependencies)
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
println("Quick Benchmark Test")
println("=" ^ 80)

# Test parameters
N_values = [100, 500, 1000]
D = 10
k = 10
n_queries = 20
rng = MersenneTwister(42)

# Test on a few dataset types
dataset_types = [:gaussian_mixture, :uniform_hypercube]

println("\nGenerating datasets and building trees...")
println()

results = []

for dataset_type in dataset_types
    for N in N_values
        println("Testing $dataset_type with N=$N")

        # Generate data
        data = generate_dataset(dataset_type, N, D, rng=rng)

        # Generate query points
        query_indices = rand(rng, 1:N, n_queries)
        queries = copy(data[query_indices, :])
        queries .+= randn(rng, size(queries)...) .* 0.01

        # === ATRIA ===
        println("  Building ATRIA tree...")
        ps = PointSet(data, EuclideanMetric())
        atria_build = @benchmark ATRIA($ps, min_points=10) samples=3
        atria_tree = ATRIA(ps, min_points=10)

        println("    Build time: $(round(median(atria_build).time / 1e6, digits=2)) ms")
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
        kdtree_build = @benchmark KDTree($data_transposed) samples=3
        kdtree = KDTree(data_transposed)

        println("    Build time: $(round(median(kdtree_build).time / 1e6, digits=2)) ms")

        # Benchmark queries
        function run_kdtree_queries()
            for i in 1:n_queries
                NearestNeighbors.knn(kdtree, queries[i, :], k)
            end
        end
        kdtree_query = @benchmark $run_kdtree_queries() samples=3
        kdtree_time_per_query = (median(kdtree_query).time / 1e6) / n_queries
        println("    Query time: $(round(kdtree_time_per_query, digits=3)) ms per query")

        # === BruteTree ===
        println("  Building BruteTree...")
        brutetree_build = @benchmark BruteTree($data_transposed) samples=3
        brutetree = BruteTree(data_transposed)

        println("    Build time: $(round(median(brutetree_build).time / 1e6, digits=2)) ms")

        # Benchmark queries
        function run_brutetree_queries()
            for i in 1:n_queries
                NearestNeighbors.knn(brutetree, queries[i, :], k)
            end
        end
        brutetree_query = @benchmark $run_brutetree_queries() samples=3
        brutetree_time_per_query = (median(brutetree_query).time / 1e6) / n_queries
        println("    Query time: $(round(brutetree_time_per_query, digits=3)) ms per query")

        # Calculate speedups
        speedup_vs_brute = brutetree_time_per_query / atria_time_per_query
        speedup_vs_kdtree = kdtree_time_per_query / atria_time_per_query

        println("  Speedup vs BruteTree: $(round(speedup_vs_brute, digits=2))x")
        println("  Speedup vs KDTree: $(round(speedup_vs_kdtree, digits=2))x")
        println()

        push!(results, (
            dataset=dataset_type,
            N=N,
            atria_build=median(atria_build).time / 1e6,
            atria_query=atria_time_per_query,
            kdtree_build=median(kdtree_build).time / 1e6,
            kdtree_query=kdtree_time_per_query,
            brutetree_build=median(brutetree_build).time / 1e6,
            brutetree_query=brutetree_time_per_query,
            speedup_vs_brute=speedup_vs_brute,
            speedup_vs_kdtree=speedup_vs_kdtree
        ))
    end
end

println("=" ^ 80)
println("Summary Table")
println("=" ^ 80)
println(@sprintf("%-20s %8s %12s %12s %12s %10s %10s",
    "Dataset", "N", "ATRIA (ms)", "KDTree (ms)", "Brute (ms)", "vs Brute", "vs KDTree"))
println("-" ^ 80)

for r in results
    println(@sprintf("%-20s %8d %12.3f %12.3f %12.3f %9.2fx %9.2fx",
        r.dataset, r.N, r.atria_query, r.kdtree_query, r.brutetree_query,
        r.speedup_vs_brute, r.speedup_vs_kdtree))
end

println("=" ^ 80)
println("\n✓ Quick benchmark test completed successfully!")

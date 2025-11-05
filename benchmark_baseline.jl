using ATRIANeighbors
using BenchmarkTools
using Random
using Printf

println("=" ^ 80)
println("BASELINE Benchmark - BEFORE Optimization")
println("=" ^ 80)

# Test parameters
N_values = [100, 500, 1000]
D = 10
k = 10
rng = MersenneTwister(42)

results = []

for N in N_values
    println("\nTesting with N=$N points, D=$D dimensions, k=$k neighbors")

    # Generate random uniform data
    data = randn(rng, N, D)

    # Create point set and tree
    ps = PointSet(data, EuclideanMetric())

    # Benchmark tree construction
    build_result = @benchmark ATRIA($ps, min_points=32) samples=5
    build_time = median(build_result).time / 1e6  # Convert to ms

    # Build tree for queries
    tree = ATRIA(ps, min_points=32)

    println("  Tree construction: $(round(build_time, digits=2)) ms")
    println("  Total clusters: $(tree.total_clusters) ($(tree.terminal_nodes) terminal)")
    println("  Tree depth: $(tree_depth(tree))")
    println("  Avg terminal size: $(round(average_terminal_size(tree), digits=2))")

    # Generate query points (points from dataset with small noise)
    n_queries = 20
    query_indices = rand(rng, 1:N, n_queries)
    queries = [data[i, :] for i in query_indices]

    # Add small noise to queries
    for query in queries
        query .+= randn(rng, D) .* 0.01
    end

    # Benchmark queries
    function run_queries()
        for query in queries
            ATRIANeighbors.knn(tree, query, k=k)
        end
    end

    query_result = @benchmark $run_queries() samples=5
    query_time_total = median(query_result).time / 1e6  # ms
    query_time_per = query_time_total / n_queries

    println("  Query time: $(round(query_time_per, digits=3)) ms per query")
    println("  Total for $n_queries queries: $(round(query_time_total, digits=2)) ms")

    # Verify correctness - test first query
    test_result = ATRIANeighbors.knn(tree, queries[1], k=k)
    println("  First query returned $(length(test_result)) neighbors")
    println("    Nearest distance: $(round(test_result[1].distance, digits=4))")
    println("    Farthest distance: $(round(test_result[end].distance, digits=4))")

    push!(results, (N=N, build=build_time, query=query_time_per))
end

println("\n" * "=" ^ 80)
println("BASELINE Summary")
println("=" ^ 80)
println(@sprintf("%-10s %15s %20s", "N", "Build (ms)", "Query (ms)"))
println("-" ^ 80)
for r in results
    println(@sprintf("%-10d %15.2f %20.3f", r.N, r.build, r.query))
end
println("=" ^ 80)
println("\n✓ Baseline benchmark completed successfully!")
println("\nNOTE: This version INCLUDES duplicate checking with BitSet")

# Benchmark optimized allocation-free version vs original

using BenchmarkTools
using Printf

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors

function benchmark_optimizations()
    println("="^80)
    println("ALLOCATION OPTIMIZATION BENCHMARK")
    println("="^80)

    # Test on different dataset sizes
    test_configs = [
        (N=1000, D=20, name="Small (1k pts, D=20)"),
        (N=2000, D=20, name="Medium (2k pts, D=20)"),
        (N=5000, D=25, name="Large (5k pts, D=25)"),
    ]

    for config in test_configs
        N, D = config.N, config.D
        name = config.name

        println("\n" * "="^80)
        println("TEST: $name")
        println("="^80)

        # Create clustered data (similar to favorable conditions)
        n_clusters = 10
        points_per_cluster = N ÷ n_clusters
        data = zeros(N, D)

        for i in 1:n_clusters
            center = randn(D) * 5.0
            start_idx = (i-1) * points_per_cluster + 1
            end_idx = min(i * points_per_cluster, N)
            data[start_idx:end_idx, :] = center' .+ randn(end_idx - start_idx + 1, D) * 0.5
        end

        # Build tree
        println("\nBuilding ATRIA tree...")
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=10)

        println("  Total clusters: $(tree.total_clusters)")
        println("  Terminal nodes: $(tree.terminal_nodes)")

        # Test parameters
        k = 10
        query_point = randn(D)

        # Warm up both versions
        println("\nWarming up...")
        for _ in 1:5
            ATRIANeighbors.knn(tree, query_point, k=k)
            ATRIANeighbors.knn_optimized(tree, query_point, k=k)
        end

        # Benchmark original version
        println("\n" * "-"^80)
        println("ORIGINAL VERSION")
        println("-"^80)
        println("@btime knn(tree, query_point, k=$k):")
        original_result = @btime ATRIANeighbors.knn($tree, $query_point, k=$k)

        # Benchmark optimized version (with context creation)
        println("\n" * "-"^80)
        println("OPTIMIZED VERSION (with context creation)")
        println("-"^80)
        println("@btime knn_optimized(tree, query_point, k=$k):")
        optimized_result = @btime ATRIANeighbors.knn_optimized($tree, $query_point, k=$k)

        # Benchmark optimized version (context reuse)
        println("\n" * "-"^80)
        println("OPTIMIZED VERSION (with context reuse)")
        println("-"^80)
        ctx = SearchContext(tree.total_clusters * 2, k)
        println("@btime knn_optimized(tree, query_point, k=$k, ctx=ctx):")
        reused_result = @btime ATRIANeighbors.knn_optimized($tree, $query_point, k=$k, ctx=$ctx)

        # Verify correctness
        println("\n" * "-"^80)
        println("CORRECTNESS CHECK")
        println("-"^80)

        # Sort both results for comparison
        original_sorted = sort(original_result, by=n->n.index)
        optimized_sorted = sort(optimized_result, by=n->n.index)
        reused_sorted = sort(reused_result, by=n->n.index)

        all_match = true
        if length(original_sorted) != length(optimized_sorted)
            println("  ❌ Different number of results!")
            all_match = false
        else
            for i in 1:length(original_sorted)
                if original_sorted[i].index != optimized_sorted[i].index ||
                   abs(original_sorted[i].distance - optimized_sorted[i].distance) > 1e-10
                    println("  ❌ Mismatch at position $i")
                    println("     Original: $(original_sorted[i])")
                    println("     Optimized: $(optimized_sorted[i])")
                    all_match = false
                    break
                end
            end
        end

        if all_match
            println("  ✅ Results match perfectly!")
        end

        # Test batch queries with context reuse
        println("\n" * "-"^80)
        println("BATCH QUERIES (100 queries, context reuse)")
        println("-"^80)

        query_indices = rand(1:N, 100)

        println("\nOriginal version (100 queries):")
        @btime begin
            for idx in $query_indices
                q = $data[idx, :]
                ATRIANeighbors.knn($tree, q, k=$k)
            end
        end

        println("\nOptimized version with reuse (100 queries):")
        ctx_reuse = SearchContext(tree.total_clusters * 2, k)
        @btime begin
            for idx in $query_indices
                q = $data[idx, :]
                ATRIANeighbors.knn_optimized($tree, q, k=$k, ctx=$ctx_reuse)
            end
        end
    end

    println("\n\n" * "="^80)
    println("BENCHMARK COMPLETE")
    println("="^80)
end

if abspath(PROGRAM_FILE) == @__FILE__
    benchmark_optimizations()
end

# Compare optimized ATRIA vs KDTree

using BenchmarkTools
using Printf

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors
using NearestNeighbors

function compare_with_kdtree()
    println("="^80)
    println("OPTIMIZED ATRIA VS KDTREE COMPARISON")
    println("="^80)

    # Test configurations
    test_configs = [
        (N=1000, D=20, name="Small clustered (1k, D=20)"),
        (N=2000, D=20, name="Medium clustered (2k, D=20)"),
        (N=5000, D=25, name="Large clustered (5k, D=25)"),
    ]

    println("\nAll tests use:")
    println("  - Clustered Gaussian mixture data (10 clusters)")
    println("  - k=10 nearest neighbors")
    println("  - Context reuse for ATRIA optimized version")

    for config in test_configs
        N, D = config.N, config.D
        name = config.name

        println("\n" * "="^80)
        println("TEST: $name")
        println("="^80)

        # Create clustered data
        n_clusters = 10
        points_per_cluster = N ÷ n_clusters
        data = zeros(N, D)

        for i in 1:n_clusters
            center = randn(D) * 5.0
            start_idx = (i-1) * points_per_cluster + 1
            end_idx = min(i * points_per_cluster, N)
            data[start_idx:end_idx, :] = center' .+ randn(end_idx - start_idx + 1, D) * 0.5
        end

        # Build trees
        println("\nBuilding trees...")

        println("  ATRIA...")
        ps = PointSet(data, EuclideanMetric())
        atria_build_time = @elapsed tree_atria = ATRIA(ps, min_points=10)
        println("    Build time: $(round(atria_build_time * 1000, digits=2)) ms")
        println("    Clusters: $(tree_atria.total_clusters)")

        println("  KDTree...")
        kdtree_build_time = @elapsed tree_kd = KDTree(data')
        println("    Build time: $(round(kdtree_build_time * 1000, digits=2)) ms")

        println("\n  Build time ratio (ATRIA/KDTree): $(round(atria_build_time / kdtree_build_time, digits=3))x")

        # Test parameters
        k = 10
        query_point = randn(D)

        # Create context for ATRIA
        ctx = SearchContext(tree_atria.total_clusters * 2, k)

        # Warm up
        for _ in 1:5
            ATRIANeighbors.knn(tree_atria, query_point, k=k)
            ATRIANeighbors.knn_optimized(tree_atria, query_point, k=k, ctx=ctx)
            NearestNeighbors.knn(tree_kd, query_point, k, true)
        end

        # Single query benchmark
        println("\n" * "-"^80)
        println("SINGLE QUERY BENCHMARK")
        println("-"^80)

        println("\n1. ATRIA Original:")
        atria_orig = @benchmark ATRIANeighbors.knn($tree_atria, $query_point, k=$k)
        display(atria_orig)

        println("\n\n2. ATRIA Optimized (context reuse):")
        atria_opt = @benchmark ATRIANeighbors.knn_optimized($tree_atria, $query_point, k=$k, ctx=$ctx)
        display(atria_opt)

        println("\n\n3. KDTree:")
        kdtree_bench = @benchmark NearestNeighbors.knn($tree_kd, $query_point, $k, true)
        display(kdtree_bench)

        # Calculate speedups
        atria_orig_time = median(atria_orig).time / 1000  # ns to μs
        atria_opt_time = median(atria_opt).time / 1000
        kdtree_time = median(kdtree_bench).time / 1000

        println("\n\n" * "-"^80)
        println("SINGLE QUERY SUMMARY")
        println("-"^80)
        @printf("%-25s | %8.2f μs | %4d allocs | %8.2f KiB |\n",
                "ATRIA Original", atria_orig_time/1000,
                atria_orig.allocs, atria_orig.memory/1024)
        @printf("%-25s | %8.2f μs | %4d allocs | %8.2f KiB |\n",
                "ATRIA Optimized", atria_opt_time/1000,
                atria_opt.allocs, atria_opt.memory/1024)
        @printf("%-25s | %8.2f μs | %4d allocs | %8.2f KiB |\n",
                "KDTree", kdtree_time/1000,
                kdtree_bench.allocs, kdtree_bench.memory/1024)

        println("\nSpeedups (vs KDTree):")
        @printf("  ATRIA Original:  %.2fx\n", kdtree_time / atria_orig_time)
        @printf("  ATRIA Optimized: %.2fx\n", kdtree_time / atria_opt_time)

        println("\nAllocation reduction (Original vs Optimized):")
        @printf("  Allocations: %.1fx fewer\n", atria_orig.allocs / atria_opt.allocs)
        @printf("  Memory: %.1fx less\n", atria_orig.memory / atria_opt.memory)

        # Batch queries
        println("\n" * "-"^80)
        println("BATCH QUERIES (100 queries)")
        println("-"^80)

        query_indices = rand(1:N, 100)

        println("\n1. ATRIA Original:")
        atria_orig_batch = @benchmark begin
            for idx in $query_indices
                q = $data[idx, :]
                ATRIANeighbors.knn($tree_atria, q, k=$k)
            end
        end
        display(atria_orig_batch)

        println("\n\n2. ATRIA Optimized (context reuse):")
        ctx_batch = SearchContext(tree_atria.total_clusters * 2, k)
        atria_opt_batch = @benchmark begin
            for idx in $query_indices
                q = $data[idx, :]
                ATRIANeighbors.knn_optimized($tree_atria, q, k=$k, ctx=$ctx_batch)
            end
        end
        display(atria_opt_batch)

        println("\n\n3. KDTree:")
        kdtree_batch = @benchmark begin
            for idx in $query_indices
                q = $data[idx, :]
                NearestNeighbors.knn($tree_kd, q, $k, true)
            end
        end
        display(kdtree_batch)

        # Batch summary
        atria_orig_batch_time = median(atria_orig_batch).time
        atria_opt_batch_time = median(atria_opt_batch).time
        kdtree_batch_time = median(kdtree_batch).time

        println("\n\n" * "-"^80)
        println("BATCH SUMMARY (100 queries)")
        println("-"^80)
        @printf("%-25s | %8.2f μs | %6d allocs | %8.2f KiB |\n",
                "ATRIA Original", atria_orig_batch_time/1000,
                atria_orig_batch.allocs, atria_orig_batch.memory/1024)
        @printf("%-25s | %8.2f μs | %6d allocs | %8.2f KiB |\n",
                "ATRIA Optimized", atria_opt_batch_time/1000,
                atria_opt_batch.allocs, atria_opt_batch.memory/1024)
        @printf("%-25s | %8.2f μs | %6d allocs | %8.2f KiB |\n",
                "KDTree", kdtree_batch_time/1000,
                kdtree_batch.allocs, kdtree_batch.memory/1024)

        println("\nSpeedups (vs KDTree):")
        @printf("  ATRIA Original:  %.2fx\n", kdtree_batch_time / atria_orig_batch_time)
        @printf("  ATRIA Optimized: %.2fx\n", kdtree_batch_time / atria_opt_batch_time)

        if atria_opt_batch_time < kdtree_batch_time
            println("\n  ✅ ATRIA Optimized is FASTER than KDTree!")
        else
            println("\n  ⚠️  ATRIA Optimized is still slower than KDTree")
        end
    end

    println("\n\n" * "="^80)
    println("COMPARISON COMPLETE")
    println("="^80)
end

if abspath(PROGRAM_FILE) == @__FILE__
    compare_with_kdtree()
end

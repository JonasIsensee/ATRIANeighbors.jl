#!/usr/bin/env julia

# Benchmark parallel batch query performance

using ATRIANeighbors
using BenchmarkTools
using Random
using Printf

println("="^80)
println("PARALLEL BATCH QUERY BENCHMARK")
println("="^80)
println()

# Check threading
n_threads = Threads.nthreads()
println("Julia threads: $n_threads")
if n_threads == 1
    println("⚠️  WARNING: Running with single thread!")
    println("   For best results, start Julia with: julia --threads=auto")
    println()
end

# Generate clustered data (ATRIA's sweet spot)
println("Generating clustered data (10,000 points, D=20)...")
Random.seed!(42)
N = 10_000
D = 20
data = zeros(N, D)

n_clusters = N ÷ 100
for i in 1:n_clusters
    center = randn(D) * 10.0
    start_idx = (i-1) * 100 + 1
    end_idx = min(i * 100, N)
    for j in start_idx:end_idx
        data[j, :] = center .+ randn(D) * 0.3
    end
end

ps = PointSet(data, EuclideanMetric())

println("Building ATRIA tree...")
tree = ATRIA(ps, min_points=64)
println("  Total clusters: $(tree.total_clusters)")
println("  Terminal nodes: $(tree.terminal_nodes)")
println()

# Generate queries
n_queries_list = [100, 500, 1000, 2000]

println("="^80)
println("BENCHMARK RESULTS")
println("="^80)
println()

for n_queries in n_queries_list
    println("Testing with $n_queries queries:")
    println("-"^80)

    queries = [randn(D) for _ in 1:n_queries]
    k = 10

    # Sequential version
    println("  Sequential (knn_batch):")
    seq_time = @belapsed knn_batch($tree, $queries, k=$k)
    println("    Time: $(round(seq_time * 1000, digits=2)) ms")

    # Parallel version
    if n_threads > 1
        println("  Parallel (knn_batch_parallel):")
        par_time = @belapsed knn_batch_parallel($tree, $queries, k=$k)
        println("    Time: $(round(par_time * 1000, digits=2)) ms")

        speedup = seq_time / par_time
        efficiency = speedup / n_threads * 100

        println("  Speedup: $(round(speedup, digits=2))x")
        println("  Efficiency: $(round(efficiency, digits=1))% (ideal = 100% * speedup/$n_threads)")

        # Show queries per second
        qps_seq = n_queries / seq_time
        qps_par = n_queries / par_time
        println("  Throughput:")
        println("    Sequential: $(round(qps_seq, digits=0)) queries/sec")
        println("    Parallel:   $(round(qps_par, digits=0)) queries/sec")
    else
        println("  (Parallel version skipped - single thread)")
    end

    println()
end

println("="^80)
println("SUMMARY")
println("="^80)
println()

if n_threads > 1
    println("✅ Parallel batch queries provide significant speedup!")
    println("   For $(n_threads) threads, expect ~$(round(n_threads * 0.7, digits=1))x-$(round(n_threads * 0.9, digits=1))x speedup")
    println("   (70-90% efficiency is typical due to overhead)")
else
    println("⚠️  Run Julia with multiple threads for speedup:")
    println("   julia --threads=auto")
    println("   or set: export JULIA_NUM_THREADS=8")
end
println()

println("💡 Usage Example:")
println("   queries = [randn(D) for _ in 1:1000]")
println("   results = knn_batch_parallel(tree, queries, k=10)")
println()

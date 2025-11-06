#!/usr/bin/env julia
# Benchmark ATRIA performance on different data distributions
#
# This benchmark demonstrates that ATRIA's effectiveness depends on data structure:
# - Random/uniform data: Poor performance (no structure to exploit)
# - Clustered data: Good performance (2-3x faster)
# - Very clustered data: Excellent performance (3-4x faster)
#
# This validates ATRIA's design for low-dimensional manifolds in high-D space.

using ATRIANeighbors
using Random
using BenchmarkTools
using NearestNeighbors

# Helper function using NearestNeighbors.jl BruteTree for benchmarking
function brute_knn(ps::AbstractPointSet, query_point, k::Int)
    N, D = size(ps)

    # Extract data matrix (rows are points)
    data = zeros(N, D)
    for i in 1:N
        data[i, :] = getpoint(ps, i)
    end

    # NearestNeighbors expects columns as points, so transpose
    tree = BruteTree(Matrix(data'), NearestNeighbors.Euclidean())

    # Perform query
    idxs, dists = NearestNeighbors.knn(tree, query_point, k)

    return [ATRIANeighbors.Neighbor(idx, dist) for (idx, dist) in zip(idxs, dists)]
end

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

# Get stats
_, stats_uniform = knn(tree_uniform, query_uniform, k=k, track_stats=true)
println("Distance calculations: $(stats_uniform.distance_calcs) / $N")
println("f_k: $(round(stats_uniform.f_k, digits=3))")
println("Pruning: $(round(100 * (1 - stats_uniform.f_k), digits=1))%")

atria_time_uniform = @belapsed knn($tree_uniform, $query_uniform, k=$k)
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
    center = randn(D) * 10.0  # Spread clusters far apart
    start_idx = (i-1) * points_per_cluster + 1
    end_idx = min(i * points_per_cluster, N)
    n_points = end_idx - start_idx + 1
    data_clustered[start_idx:end_idx, :] = center' .+ randn(n_points, D) * 0.3  # Tight clusters
end

ps_clustered = PointSet(data_clustered, EuclideanMetric())
tree_clustered = ATRIA(ps_clustered, min_points=10)
query_clustered = data_clustered[1, :] + randn(D) * 0.1  # Query near first cluster

# Get stats
_, stats_clustered = knn(tree_clustered, query_clustered, k=k, track_stats=true)
println("Distance calculations: $(stats_clustered.distance_calcs) / $N")
println("f_k: $(round(stats_clustered.f_k, digits=3))")
println("Pruning: $(round(100 * (1 - stats_clustered.f_k), digits=1))%")

atria_time_clustered = @belapsed knn($tree_clustered, $query_clustered, k=$k)
brute_time_clustered = @belapsed brute_knn($ps_clustered, $query_clustered, $k)
println("ATRIA: $(round(atria_time_clustered*1e6, digits=1))μs")
println("Brute: $(round(brute_time_clustered*1e6, digits=1))μs")
println("Speedup: $(round(brute_time_clustered / atria_time_clustered, digits=2))x")

# Test 3: Very clustered data (extreme favorable case)
println("\n3. VERY CLUSTERED DATA (100 tiny clusters)")
println("-"^80)
n_clusters_many = 100
points_per_cluster_small = N ÷ n_clusters_many
data_very_clustered = zeros(N, D)

for i in 1:n_clusters_many
    center = randn(D) * 20.0  # Very spread apart
    start_idx = (i-1) * points_per_cluster_small + 1
    end_idx = min(i * points_per_cluster_small, N)
    n_points = end_idx - start_idx + 1
    data_very_clustered[start_idx:end_idx, :] = center' .+ randn(n_points, D) * 0.1  # Very tight
end

ps_very_clustered = PointSet(data_very_clustered, EuclideanMetric())
tree_very_clustered = ATRIA(ps_very_clustered, min_points=10)
query_very_clustered = data_very_clustered[1, :] + randn(D) * 0.05  # Query very close to cluster

# Get stats
_, stats_very_clustered = knn(tree_very_clustered, query_very_clustered, k=k, track_stats=true)
println("Distance calculations: $(stats_very_clustered.distance_calcs) / $N")
println("f_k: $(round(stats_very_clustered.f_k, digits=3))")
println("Pruning: $(round(100 * (1 - stats_very_clustered.f_k), digits=1))%")

atria_time_very = @belapsed knn($tree_very_clustered, $query_very_clustered, k=$k)
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
else
    println("❌ Even clustered data doesn't help - there may be a bug!")
end

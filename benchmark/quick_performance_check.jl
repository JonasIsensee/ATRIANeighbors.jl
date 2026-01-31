#!/usr/bin/env julia
"""
Quick Performance Check for ATRIA vs NearestNeighbors
"""

using Pkg
Pkg.activate(".")

using ATRIANeighbors
import NearestNeighbors as NN
using BenchmarkTools
using Printf

# Disambiguate knn
const knn_atria = ATRIANeighbors.knn
const knn_nn = NN.knn

println("="^80)
println("QUICK PERFORMANCE CHECK: ATRIA vs KDTree")
println("="^80)
println()

# Test configurations
N = 10_000
D = 20
k = 10
n_queries = 100

println("Configuration:")
println("  N = $N points")
println("  D = $D dimensions")
println("  k = $k neighbors")
println("  n_queries = $n_queries")
println()

# =============================================================================
# Test 1: Gaussian Mixture (Good for ATRIA)
# =============================================================================
println("="^80)
println("TEST 1: GAUSSIAN MIXTURE DATA (50 clusters)")
println("="^80)
println()

# Generate clustered data
function make_clustered_data(N, D, n_clusters)
    data = zeros(N, D)
    points_per_cluster = div(N, n_clusters)
    for i in 1:n_clusters
        center = randn(D) * 10
        start_idx = (i-1) * points_per_cluster + 1
        end_idx = min(i * points_per_cluster, N)
        for j in start_idx:end_idx
            data[j, :] = center + randn(D) * 0.5
        end
    end
    return data
end

data_clustered = make_clustered_data(N, D, 50)
query = randn(D)

println("Building ATRIA tree...")
@time tree_atria = ATRIATree(data_clustered)

println("\nBuilding KDTree...")
@time tree_kd = NN.KDTree(data_clustered')

println("\n" * "-"^80)
println("Single Query Performance:")
println("-"^80)

println("\nATRIA:")
@btime knn_atria($tree_atria, $query, k=$k) samples=5 evals=3

alloc_atria = @allocated knn_atria(tree_atria, query, k=k)
@printf("Allocations: %.2f KB\n", alloc_atria / 1024)

println("\nKDTree:")
@btime knn_nn($tree_kd, $query, $k) samples=5 evals=3

alloc_kd = @allocated knn_nn(tree_kd, query, k)
@printf("Allocations: %.2f KB\n", alloc_kd / 1024)

println()

# =============================================================================
# Test 2: Uniform Random Data (Bad for ATRIA)
# =============================================================================
println("="^80)
println("TEST 2: UNIFORM RANDOM DATA")
println("="^80)
println()

data_random = randn(N, D)

println("Building ATRIA tree...")
@time tree_atria_rand = ATRIATree(data_random)

println("\nBuilding KDTree...")
@time tree_kd_rand = NN.KDTree(data_random')

println("\n" * "-"^80)
println("Single Query Performance:")
println("-"^80)

println("\nATRIA:")
@btime knn_atria($tree_atria_rand, $query, k=$k) samples=5 evals=3

println("\nKDTree:")
@btime knn_nn($tree_kd_rand, $query, $k) samples=5 evals=3

println()

# =============================================================================
# Test 3: Allocation Profiling with SearchContext
# =============================================================================
println("="^80)
println("TEST 3: ALLOCATION OPTIMIZATION (SearchContext reuse)")
println("="^80)
println()

println("ATRIA without SearchContext reuse:")
@btime knn_atria($tree_atria, $query, k=$k) samples=5

println("\nATRIA with SearchContext reuse:")
ctx = SearchContext(tree_atria, k)
@btime knn_atria($tree_atria, $query, k=$k, ctx=$ctx) samples=5

println()

# =============================================================================
# Test 4: Type Stability Check
# =============================================================================
println("="^80)
println("TEST 4: TYPE STABILITY CHECK")
println("="^80)
println()

println("Checking knn() type stability...")
println("(Look for red 'Union' or 'Any' types - those are bad)")
println()

using InteractiveUtils
@code_warntype knn_atria(tree_atria, query, k=k)

println()

# =============================================================================
# Summary
# =============================================================================
println("="^80)
println("SUMMARY")
println("="^80)
println()

t_atria_clust = @belapsed knn_atria($tree_atria, $query, k=$k)
t_kd_clust = @belapsed knn_nn($tree_kd, $query, $k)

t_atria_rand = @belapsed knn_atria($tree_atria_rand, $query, k=$k)
t_kd_rand = @belapsed knn_nn($tree_kd_rand, $query, $k)

println("Clustered data:")
@printf("  ATRIA: %.3f ms\n", t_atria_clust * 1000)
@printf("  KDTree: %.3f ms\n", t_kd_clust * 1000)
@printf("  Speedup: %.2fx %s\n", t_kd_clust / t_atria_clust,
        t_atria_clust < t_kd_clust ? "(ATRIA wins)" : "(KDTree wins)")
println()

println("Random data:")
@printf("  ATRIA: %.3f ms\n", t_atria_rand * 1000)
@printf("  KDTree: %.3f ms\n", t_kd_rand * 1000)
@printf("  Speedup: %.2fx %s\n", t_kd_rand / t_atria_rand,
        t_atria_rand < t_kd_rand ? "(ATRIA wins)" : "(KDTree wins)")
println()

println("="^80)

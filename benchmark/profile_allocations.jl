#!/usr/bin/env julia
"""
Detailed allocation profiling for ATRIA
"""

using Pkg
Pkg.activate(".")

using ATRIANeighbors
using Profile

println("="^80)
println("ATRIA ALLOCATION PROFILING")
println("="^80)
println()

# Test data
N, D = 5000, 20
data = randn(N, D)
query = randn(D)
k = 10

# Make clustered data for testing
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

println("Building tree...")
tree = ATRIATree(data_clustered)

println("Warming up...")
for i in 1:10
    knn(tree, query, k=k)
end

println("\nRunning allocation profiling...")
println()

# Profile allocations
Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate=1.0 begin
    for i in 1:100
        q = randn(D)
        knn(tree, q, k=k)
    end
end

println("Top allocation sites (by count):")
Profile.Allocs.print(maxdepth=20, sortedby=:count)

println("\n" * "="^80)
println("Allocation profile complete")
println("="^80)

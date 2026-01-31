#!/usr/bin/env julia
"""
Performance Analysis for ATRIA

Tools used:
- JET.jl: Static analysis for type instabilities and potential runtime errors
- AllocCheck.jl: Detect unexpected heap allocations
- @time and @allocated: Track memory allocations
- @code_warntype: Check type stability
"""

using Pkg
Pkg.activate(".")

# Install performance analysis tools if needed
try
    using JET
catch
    Pkg.add("JET")
    using JET
end

try
    using AllocCheck
catch
    Pkg.add("AllocCheck")
    using AllocCheck
end

using ATRIANeighbors
using BenchmarkTools
using Printf

println("="^80)
println("ATRIA PERFORMANCE ANALYSIS")
println("="^80)
println()

# =============================================================================
# 1. Type Stability Analysis
# =============================================================================
println("1. TYPE STABILITY ANALYSIS")
println("-"^80)

# Test data
N, D = 1000, 20
data = randn(N, D)
query = randn(D)
k = 10

# Build tree
tree = ATRIATree(data)

println("Testing knn() type stability:")
println()
@code_warntype knn(tree, query, k=k)

println("\n\n")

# =============================================================================
# 2. Allocation Analysis
# =============================================================================
println("2. ALLOCATION ANALYSIS")
println("-"^80)

# Tree construction
println("Tree construction allocations:")
alloc_build = @allocated ATRIATree(data)
@printf("  Total: %.2f KB\n", alloc_build / 1024)
println()

# Single query without context (cold)
println("Single query (without SearchContext):")
alloc_query_cold = @allocated knn(tree, query, k=k)
@printf("  Allocations: %.2f KB\n", alloc_query_cold / 1024)

# Detailed benchmark
println("\n  Detailed benchmark:")
@btime knn($tree, $query, k=$k) samples=3 evals=10

println()

# Single query with context (warm)
println("Single query (with SearchContext - reused):")
ctx = SearchContext(tree.total_clusters * 2, k)
alloc_query_warm = @allocated knn(tree, query, k=k, ctx=ctx)
@printf("  Allocations: %.2f KB\n", alloc_query_warm / 1024)

println("\n  Detailed benchmark:")
@btime knn($tree, $query, k=$k, ctx=$ctx) samples=3 evals=10

println()

# =============================================================================
# 3. JET Analysis (Type Inference Quality)
# =============================================================================
println("\n3. JET STATIC ANALYSIS")
println("-"^80)

println("Analyzing knn() for potential type instabilities:")
println()
@report_opt knn(tree, query, k=k)

println("\n\nAnalyzing tree construction:")
println()
@report_opt ATRIATree(data)

# =============================================================================
# 4. Hotspot Profiling
# =============================================================================
println("\n\n4. ALLOCATION HOTSPOTS")
println("-"^80)

println("Running allocation profiling (this may take a minute)...")
println()

# Profile allocations during query execution
function run_queries(tree, n_queries=100)
    results = Vector{Vector{Neighbor}}(undef, n_queries)
    for i in 1:n_queries
        query = randn(size(tree.pointset, 2))
        results[i] = knn(tree, query, k=10)
    end
    return results
end

# Warm-up
run_queries(tree, 10)

# Profile
using Profile
Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate=1.0 run_queries(tree, 50)

println("Top allocation sites:")
Profile.Allocs.print(maxdepth=15, sortedby=:count)

println("\n\n")

# =============================================================================
# 5. Distance Calculation Performance
# =============================================================================
println("5. DISTANCE CALCULATION PERFORMANCE")
println("-"^80)

using ATRIANeighbors: EuclideanMetric, distance

metric = EuclideanMetric()
p1 = randn(D)
p2 = randn(D)

println("Distance calculation (D=$D):")
println("  @btime distance(metric, p1, p2):")
@btime distance($metric, $p1, $p2)

println("\n  Allocations:")
alloc_dist = @allocated distance(metric, p1, p2)
@printf("    %.2f bytes\n", alloc_dist)

println()

# =============================================================================
# 6. Tree Search Performance Breakdown
# =============================================================================
println("6. SEARCH PERFORMANCE BREAKDOWN")
println("-"^80)

println("Comparing search performance on different data distributions:")
println()

# Random data (worst case)
data_random = randn(5000, 20)
tree_random = ATRIATree(data_random)
println("Random data (N=5000, D=20):")
@btime knn($tree_random, $query, k=10) samples=3

# Clustered data (good case)
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

data_clustered = make_clustered_data(5000, 20, 50)
tree_clustered = ATRIATree(data_clustered)
println("\nClustered data (N=5000, D=20, 50 clusters):")
@btime knn($tree_clustered, $query, k=10) samples=3

println()

# =============================================================================
# Summary
# =============================================================================
println("\n" * "="^80)
println("ANALYSIS COMPLETE")
println("="^80)
println("\nNext steps:")
println("1. Address any type instabilities found by @code_warntype")
println("2. Investigate unexpected allocations highlighted by AllocCheck")
println("3. Optimize hot paths identified in allocation profiling")
println("4. Consider SIMD/vectorization for distance calculations")
println("5. Profile CPU time (not just allocations) to find computational bottlenecks")
println()

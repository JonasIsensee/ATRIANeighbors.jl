"""
analyze_bottlenecks.jl

Detailed performance analysis to identify bottlenecks in ATRIA neighbor search.
"""

using Pkg
Pkg.activate(@__DIR__)
using ATRIANeighbors
using Random
using Printf
using Profile
using InteractiveUtils  # For @code_warntype

# Load data generators
include(joinpath(@__DIR__, "utils", "data_generators.jl"))

println("=" ^ 80)
println("ATRIA Performance Bottleneck Analysis")
println("=" ^ 80)
println()

# =============================================================================
# 1. Type Stability Check
# =============================================================================
println("1. TYPE STABILITY ANALYSIS")
println("=" ^ 80)
println()

rng = MersenneTwister(42)
N, D = 100, 10
data = generate_dataset(:gaussian_mixture, N, D, rng=rng)
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=10)
query = data[1, :]

println("Checking type stability of key functions...")
println()

println("--- distance(ps, i, query) ---")
@code_warntype distance(ps, 1, query)
println()

println("--- knn(tree, query, k=10) ---")
@code_warntype ATRIANeighbors.knn(tree, query, k=10)
println()

println("--- getpoint(ps, i) ---")
@code_warntype getpoint(ps, 1)
println()

# =============================================================================
# 2. Memory Allocation Analysis
# =============================================================================
println("\n" * "=" ^ 80)
println("2. MEMORY ALLOCATION ANALYSIS")
println("=" ^ 80)
println()

println("Testing allocations in hot path functions...")
println()

# Warmup
for i in 1:10
    ATRIANeighbors.knn(tree, query, k=10)
end

println("--- k-NN search (single query) ---")
@time ATRIANeighbors.knn(tree, query, k=10)
alloc_info = @allocated ATRIANeighbors.knn(tree, query, k=10)
println("Total allocations: $(alloc_info) bytes")
println()

println("--- k-NN search (100 queries, amortized) ---")
queries = [data[i, :] for i in 1:100]
@time for q in queries
    ATRIANeighbors.knn(tree, q, k=10)
end
total_alloc = @allocated for q in queries
    ATRIANeighbors.knn(tree, q, k=10)
end
println("Total allocations: $(total_alloc) bytes")
println("Per query: $(total_alloc / 100) bytes")
println()

# =============================================================================
# 3. Intensive Profiling with Larger Workload
# =============================================================================
println("\n" * "=" ^ 80)
println("3. INTENSIVE PROFILING (Larger Workload)")
println("=" ^ 80)
println()

# Use larger dataset for better profiling signal
N_large = 10000
D_large = 20
println("Generating large dataset: N=$N_large, D=$D_large")
data_large = generate_dataset(:gaussian_mixture, N_large, D_large, rng=rng)
ps_large = PointSet(data_large, EuclideanMetric())

println("Building ATRIA tree...")
@time tree_large = ATRIA(ps_large, min_points=20)
println("  Total clusters: $(tree_large.total_clusters)")
println("  Terminal nodes: $(tree_large.terminal_nodes)")
println()

# Generate many queries
n_queries = 500
println("Generating $n_queries query points...")
query_indices = rand(rng, 1:N_large, n_queries)
queries_large = [data_large[i, :] for i in query_indices]

# Warmup
println("Warming up...")
for q in queries_large[1:10]
    ATRIANeighbors.knn(tree_large, q, k=20)
end

# Profile k-NN search
println("\nProfiling k-NN search (20-NN, $n_queries queries)...")
Profile.clear()
@profile begin
    for q in queries_large
        ATRIANeighbors.knn(tree_large, q, k=20)
    end
end

# Print profile
println("\n--- Top 30 Functions by Sample Count ---")
Profile.print(maxdepth=15, noisefloor=2.0)

# =============================================================================
# 4. Micro-benchmarks of Hot Path Functions
# =============================================================================
println("\n" * "=" ^ 80)
println("4. MICRO-BENCHMARKS")
println("=" ^ 80)
println()

println("Testing individual function performance...")
println()

# Distance calculation
p1 = rand(D_large)
p2 = rand(D_large)
metric = EuclideanMetric()

println("--- distance(metric, p1, p2) ---")
@time for _ in 1:1000000
    distance(metric, p1, p2)
end
println()

# getpoint
println("--- getpoint(ps, i) ---")
@time for _ in 1:1000000
    getpoint(ps_large, 1)
end
println()

# Neighbor table insert
println("--- SortedNeighborTable insert ---")
table = SortedNeighborTable(20)
init_search!(table, 20)
neighbors = [Neighbor(i, rand()) for i in 1:100]
@time for _ in 1:10000
    init_search!(table, 20)
    for n in neighbors
        insert!(table, n)
    end
end
println()

# =============================================================================
# 5. Cache Behavior Analysis
# =============================================================================
println("\n" * "=" ^ 80)
println("5. CACHE BEHAVIOR ANALYSIS")
println("=" ^ 80)
println()

println("Comparing sequential vs random access patterns...")
println()

# Sequential queries (better cache locality)
println("--- Sequential queries (cache-friendly) ---")
queries_seq = [data_large[i, :] for i in 1:n_queries]
@time for q in queries_seq
    ATRIANeighbors.knn(tree_large, q, k=20)
end
println()

# Random queries (worse cache locality)
println("--- Random queries (cache-unfriendly) ---")
random_indices = rand(rng, 1:N_large, n_queries)
queries_rand = [data_large[i, :] for i in random_indices]
@time for q in queries_rand
    ATRIANeighbors.knn(tree_large, q, k=20)
end
println()

# =============================================================================
# Summary
# =============================================================================
println("\n" * "=" ^ 80)
println("ANALYSIS COMPLETE")
println("=" ^ 80)
println()
println("Review the output above for:")
println("  1. Type instabilities (red text in @code_warntype)")
println("  2. Excessive memory allocations")
println("  3. Functions consuming most CPU time (in profile)")
println("  4. Cache effects (sequential vs random query performance)")
println()

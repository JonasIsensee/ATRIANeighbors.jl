"""
Benchmark ATRIA in conditions where it should excel:
- High-dimensional time series data (D > 15)
- Embedded attractors (non-uniform distributions)
- Larger datasets (N > 5000)
- Larger k values (k > 20)
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
println("ATRIA Favorable Conditions Benchmark")
println("=" ^ 80)
println()
println("Testing scenarios where ATRIA should outperform KDTree:")
println("  - High-dimensional embedded time series (D >= 15)")
println("  - Non-uniform attractor data")
println("  - Larger k values (k >= 20)")
println()

rng = MersenneTwister(42)

# Test configurations
configs = [
    # (name, N, D, k, dataset_type)
    ("Lorenz D=15", 5000, 15, 20, :lorenz),
    ("Lorenz D=20", 5000, 20, 20, :lorenz),
    ("Lorenz D=30", 5000, 30, 20, :lorenz),
    ("Lorenz D=20 k=50", 5000, 20, 50, :lorenz),
    ("Henon D=20", 5000, 20, 20, :henon),
    ("Clustered D=20", 5000, 20, 20, :gaussian_mixture),
]

n_queries = 20
results = []

for (name, N, D, k, dataset_type) in configs
    println("Testing: $name (N=$N, D=$D, k=$k)")
    println("-" ^ 80)

    # Generate data
    data = generate_dataset(dataset_type, N, D, rng=rng)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    # === ATRIA ===
    println("  Building ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    atria_build = @benchmark ATRIA($ps, min_points=32) samples=3
    atria_tree = ATRIA(ps, min_points=32)

    atria_build_time = median(atria_build).time / 1e6
    println("    Build time: $(round(atria_build_time, digits=2)) ms")
    println("    Clusters: $(atria_tree.total_clusters) ($(atria_tree.terminal_nodes) terminal)")

    # Benchmark queries
    function run_atria_queries()
        for i in 1:n_queries
            ATRIANeighbors.knn(atria_tree, queries[i, :], k=k)
        end
    end
    atria_query = @benchmark $run_atria_queries() samples=5
    atria_time_per_query = (median(atria_query).time / 1e6) / n_queries
    atria_allocs = median(atria_query).allocs / n_queries
    println("    Query time: $(round(atria_time_per_query, digits=3)) ms per query")
    println("    Allocations: $(round(Int, atria_allocs)) per query")

    # === KDTree ===
    println("  Building KDTree...")
    data_transposed = Matrix(data')
    kdtree_build = @benchmark KDTree($data_transposed) samples=3
    kdtree = KDTree(data_transposed)

    kdtree_build_time = median(kdtree_build).time / 1e6
    println("    Build time: $(round(kdtree_build_time, digits=2)) ms")

    # Benchmark queries
    function run_kdtree_queries()
        for i in 1:n_queries
            NearestNeighbors.knn(kdtree, queries[i, :], k)
        end
    end
    kdtree_query = @benchmark $run_kdtree_queries() samples=5
    kdtree_time_per_query = (median(kdtree_query).time / 1e6) / n_queries
    kdtree_allocs = median(kdtree_query).allocs / n_queries
    println("    Query time: $(round(kdtree_time_per_query, digits=3)) ms per query")
    println("    Allocations: $(round(Int, kdtree_allocs)) per query")

    # Calculate speedups
    speedup_vs_kdtree = kdtree_time_per_query / atria_time_per_query

    if speedup_vs_kdtree > 1.0
        println("  ✅ ATRIA is $(round(speedup_vs_kdtree, digits=2))x FASTER than KDTree")
    else
        println("  ⚠️  ATRIA is $(round(1/speedup_vs_kdtree, digits=2))x SLOWER than KDTree")
    end
    println()

    push!(results, (
        name=name,
        N=N,
        D=D,
        k=k,
        atria_build=atria_build_time,
        atria_query=atria_time_per_query,
        atria_allocs=atria_allocs,
        kdtree_build=kdtree_build_time,
        kdtree_query=kdtree_time_per_query,
        kdtree_allocs=kdtree_allocs,
        speedup=speedup_vs_kdtree
    ))
end

println("=" ^ 80)
println("Summary Table")
println("=" ^ 80)
println(@sprintf("%-20s %5s %5s %5s | %10s %10s | %10s",
    "Test", "N", "D", "k", "ATRIA (ms)", "KDTree (ms)", "Speedup"))
println("-" ^ 80)

for r in results
    status = r.speedup > 1.0 ? "✅" : "⚠️ "
    speedup_str = r.speedup > 1.0 ? "$(round(r.speedup, digits=2))x" : "$(round(1/r.speedup, digits=2))x slower"
    println(@sprintf("%-20s %5d %5d %5d | %10.3f %10.3f | %10s %s",
        r.name, r.N, r.D, r.k, r.atria_query, r.kdtree_query, speedup_str, status))
end

println("=" ^ 80)
println()

# Count wins
wins = sum(r.speedup > 1.0 for r in results)
total = length(results)

if wins > total / 2
    println("✅ ATRIA outperformed KDTree in $wins/$total favorable conditions")
    println("   This is expected for high-dimensional, non-uniform data")
else
    println("⚠️  ATRIA only won in $wins/$total tests")
    println("   Possible issues:")
    println("   - Further optimization needed (try LoopVectorization.jl)")
    println("   - Tree construction parameters (try different min_points)")
    println("   - Need even higher dimensions or larger k")
    println("   - Profile to find remaining bottlenecks")
end

println()
println("Allocation Analysis:")
println("-" ^ 80)
for r in results
    alloc_ratio = r.atria_allocs / r.kdtree_allocs
    if alloc_ratio < 1.5
        println("✅ $(r.name): $(round(Int, r.atria_allocs)) vs $(round(Int, r.kdtree_allocs)) ($(round(alloc_ratio, digits=2))x)")
    else
        println("⚠️  $(r.name): $(round(Int, r.atria_allocs)) vs $(round(Int, r.kdtree_allocs)) ($(round(alloc_ratio, digits=2))x - too many!)")
    end
end

println()
println("=" ^ 80)
println("Benchmark complete!")
println("=" ^ 80)

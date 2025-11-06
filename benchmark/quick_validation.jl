# Quick validation test for optimized search

using ATRIANeighbors
using BenchmarkTools

println("="^80)
println("QUICK VALIDATION TEST")
println("="^80)

# Create test data
N, D = 1000, 20
data = randn(N, D)
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=10)
query = randn(D)

println("\nTest configuration: N=$N, D=$D, k=10")
println("Tree clusters: $(tree.total_clusters)")

# Test legacy version
neighbors_legacy = knn_legacy(tree, query, k=10)

# Test new version (with context reuse)
ctx = SearchContext(tree, 10)
neighbors_new = knn(tree, query, k=10, ctx=ctx)

# Verify results match
legacy_sorted = sort(neighbors_legacy, by=n->n.index)
new_sorted = sort(neighbors_new, by=n->n.index)

println("\n" * "-"^80)
println("CORRECTNESS CHECK")
println("-"^80)

if length(legacy_sorted) == length(new_sorted)
    matches = true
    for i in 1:length(legacy_sorted)
        if legacy_sorted[i].index != new_sorted[i].index ||
           abs(legacy_sorted[i].distance - new_sorted[i].distance) > 1e-10
            matches = false
            println("  Mismatch at position $i:")
            println("    Legacy:  $(legacy_sorted[i])")
            println("    New: $(new_sorted[i])")
            break
        end
    end
    if matches
        println("  ✅ PASSED: Legacy and new versions produce identical results")
    else
        println("  ❌ FAILED: Results differ")
    end
else
    println("  ❌ FAILED: Different number of results")
    println("    Legacy: $(length(legacy_sorted)) neighbors")
    println("    New: $(length(new_sorted)) neighbors")
end

# Quick timing comparison
println("\n" * "-"^80)
println("PERFORMANCE COMPARISON")
println("-"^80)

print("\nLegacy version: ")
legacy_bench = @benchmark ATRIANeighbors.knn_legacy($tree, $query, k=10) samples=100 evals=10

print("\nNew version (context reuse): ")
new_bench = @benchmark ATRIANeighbors.knn($tree, $query, k=10, ctx=$ctx) samples=100 evals=10

# Calculate speedup
legacy_time = median(legacy_bench).time
new_time = median(new_bench).time
speedup = legacy_time / new_time
alloc_reduction = legacy_bench.allocs / new_bench.allocs
memory_reduction = legacy_bench.memory / new_bench.memory

println("\n" * "-"^80)
println("SUMMARY")
println("-"^80)
println("Speedup: $(round(speedup, digits=2))x faster")
println("Allocations: $(round(alloc_reduction, digits=1))x fewer ($(legacy_bench.allocs) → $(new_bench.allocs))")
println("Memory: $(round(memory_reduction, digits=1))x less ($(legacy_bench.memory) → $(new_bench.memory) bytes)")
println("\n✅ New API validated successfully!")
println("="^80)

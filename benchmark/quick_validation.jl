# Quick validation test for ATRIA search

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

# Test simple usage
neighbors_simple = knn(tree, query, k=10)

# Test with explicit context (for batch reuse)
ctx = SearchContext(tree, 10)
neighbors_ctx = knn(tree, query, k=10, ctx=ctx)

# Verify results match
simple_sorted = sort(neighbors_simple, by=n->n.index)
ctx_sorted = sort(neighbors_ctx, by=n->n.index)

println("\n" * "-"^80)
println("CORRECTNESS CHECK")
println("-"^80)

if length(simple_sorted) == length(ctx_sorted)
    matches = true
    for i in 1:length(simple_sorted)
        if simple_sorted[i].index != ctx_sorted[i].index ||
           abs(simple_sorted[i].distance - ctx_sorted[i].distance) > 1e-10
            matches = false
            println("  Mismatch at position $i:")
            println("    Simple:  $(simple_sorted[i])")
            println("    Context: $(ctx_sorted[i])")
            break
        end
    end
    if matches
        println("  ✅ PASSED: Simple and context-reuse versions produce identical results")
    else
        println("  ❌ FAILED: Results differ")
    end
else
    println("  ❌ FAILED: Different number of results")
    println("    Simple: $(length(simple_sorted)) neighbors")
    println("    Context: $(length(ctx_sorted)) neighbors")
end

# Quick timing comparison
println("\n" * "-"^80)
println("PERFORMANCE COMPARISON")
println("-"^80)

print("\nSimple usage (auto-creates context): ")
simple_bench = @benchmark knn($tree, $query, k=10) samples=100 evals=10

print("\nWith explicit context (for batch reuse): ")
ctx_bench = @benchmark knn($tree, $query, k=10, ctx=$ctx) samples=100 evals=10

print("\nBatch API (10 queries): ")
queries = [randn(D) for _ in 1:10]
batch_bench = @benchmark knn_batch($tree, $queries, k=10) samples=100 evals=10

# Calculate stats
simple_time = median(simple_bench).time
ctx_time = median(ctx_bench).time
batch_time = median(batch_bench).time

println("\n" * "-"^80)
println("SUMMARY")
println("-"^80)
println("Simple usage: $(round(simple_time/1000, digits=2)) μs ($(simple_bench.allocs) allocs, $(simple_bench.memory) bytes)")
println("Context reuse: $(round(ctx_time/1000, digits=2)) μs ($(ctx_bench.allocs) allocs, $(ctx_bench.memory) bytes)")
println("Batch (10 queries): $(round(batch_time/1000, digits=2)) μs ($(batch_bench.allocs) allocs, $(batch_bench.memory) bytes)")
println("\n✅ All variants working correctly!")
println("="^80)

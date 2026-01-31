"""
Comprehensive JET.jl Analysis for ATRIANeighbors.jl

This script provides deeper analysis using JET's @report_call macro
for thorough type inference checking.

Usage:
    julia --project=. test/test_jet_comprehensive.jl
"""

using ATRIANeighbors
using JET
using Test

println("=" ^ 80)
println("Comprehensive JET.jl Analysis for ATRIANeighbors.jl")
println("=" ^ 80)
println()

# Test data setup
println("Setting up test data...")
N = 100
D = 10
data = rand(N, D)
ps = PointSet(data, EuclideanMetric())
tree = ATRIATree(ps, min_points=10)
query = rand(D)
println("✓ Test data ready")
println()

# Helper function to run JET @report_opt analysis
function deep_analyze(func, args...; name="function")
    println("Deep analysis: $name")
    println("-" ^ 80)
    
    result = @report_opt func(args...)
    
    if isempty(JET.get_reports(result))
        println("✓ No issues detected")
    else
        println("⚠️  Issues found:")
        println(result)
    end
    println()
    
    return result
end

println("=" ^ 80)
println("DEEP ANALYSIS: CRITICAL HOT PATHS")
println("=" ^ 80)
println()

# Distance calculations (most critical for performance)
p1 = rand(D)
p2 = rand(D)
metric = EuclideanMetric()

deep_analyze(distance, metric, p1, p2; name="distance(EuclideanMetric, p1, p2)")
deep_analyze(distance, metric, p1, p2, 1.0; name="distance(EuclideanMetric, p1, p2, 1.0)")

# PointSet operations
deep_analyze(getpoint, ps, 1; name="getpoint(ps, 1)")
deep_analyze(distance, ps, 1, 2; name="distance(ps, 1, 2)")
deep_analyze(distance, ps, 1, query; name="distance(ps, 1, query)")
deep_analyze(distance, ps, 1, query, 1.0; name="distance(ps, 1, query, 1.0)")

# Time series embedding
println("=" ^ 80)
println("DEEP ANALYSIS: EMBEDDED TIME SERIES")
println("=" ^ 80)
println()

ts_data = rand(200)
ts = EmbeddedTimeSeries(ts_data, 10, 1, EuclideanMetric())

deep_analyze(getpoint, ts, 1; name="getpoint(ts, 1)")
deep_analyze(distance, ts, 1, 2; name="distance(ts, 1, 2)")
deep_analyze(distance, ts, 1, query; name="distance(ts, 1, query)")

# Tree construction  
println("=" ^ 80)
println("DEEP ANALYSIS: TREE CONSTRUCTION")
println("=" ^ 80)
println()

ps_small = PointSet(rand(50, 5), EuclideanMetric())
deep_analyze((ps) -> ATRIATree(ps, min_points=5), ps_small; name="ATRIATree(ps_small, min_points=5)")

# Search operations
println("=" ^ 80)
println("DEEP ANALYSIS: SEARCH OPERATIONS")
println("=" ^ 80)
println()

deep_analyze((tree, q) -> knn(tree, q), tree, query; name="knn(tree, query)")
deep_analyze((tree, q) -> knn(tree, q, k=10), tree, query; name="knn(tree, query, k=10)")

# SearchContext usage
println("=" ^ 80)
println("DEEP ANALYSIS: SEARCH WITH CONTEXT (OPTIMIZED PATH)")
println("=" ^ 80)
println()

ctx = SearchContext(tree, 10)
deep_analyze((tree, q, ctx) -> knn(tree, q, k=10, ctx=ctx), tree, query, ctx; name="knn(tree, query, k=10, ctx=ctx)")

# Range search
deep_analyze((tree, q) -> range_search(tree, q, radius=1.0), tree, query; name="range_search(tree, query, radius=1.0)")
deep_analyze((tree, q) -> count_range(tree, q, radius=1.0), tree, query; name="count_range(tree, query, radius=1.0)")

# Data structures
println("=" ^ 80)
println("DEEP ANALYSIS: DATA STRUCTURE OPERATIONS")
println("=" ^ 80)
println()

table = SortedNeighborTable(10)
init_search!(table, 10)
neighbor = Neighbor(1, 0.5)

deep_analyze(insert!, table, neighbor; name="insert!(table, neighbor)")
deep_analyze(finish_search, table; name="finish_search(table)")

# Brute force
println("=" ^ 80)
println("DEEP ANALYSIS: BRUTE FORCE REFERENCE")
println("=" ^ 80)
println()

deep_analyze(brute_knn, ps, query, 10; name="brute_knn(ps, query, 10)")
deep_analyze(brute_range_search, ps, query, 1.0; name="brute_range_search(ps, query, 1.0)")
deep_analyze(brute_count_range, ps, query, 1.0; name="brute_count_range(ps, query, 1.0)")

println("=" ^ 80)
println("TESTING BATCH OPERATIONS")
println("=" ^ 80)
println()

queries = [rand(D) for _ in 1:5]
deep_analyze((tree, queries) -> knn_batch(tree, queries, k=10), tree, queries; name="knn_batch(tree, queries, k=10)")

println("=" ^ 80)
println("TESTING DIFFERENT METRICS")
println("=" ^ 80)
println()

# Maximum metric
max_metric = MaximumMetric()
ps_max = PointSet(data, max_metric)
tree_max = ATRIATree(ps_max, min_points=10)
deep_analyze((tree, q) -> knn(tree, q, k=5), tree_max, query; name="knn(tree_max, query, k=5) with MaximumMetric")

# SquaredEuclidean metric (only with brute force!)
sq_metric = SquaredEuclideanMetric()
ps_sq = PointSet(data, sq_metric)
deep_analyze(brute_knn, ps_sq, query, 5; name="brute_knn(ps_sq, query, 5) with SquaredEuclidean")

# Exponentially Weighted Euclidean
ew_metric = ExponentiallyWeightedEuclidean(0.9)
ps_ew = PointSet(data, ew_metric)
tree_ew = ATRIATree(ps_ew, min_points=10)
deep_analyze((tree, q) -> knn(tree, q, k=5), tree_ew, query; name="knn(tree_ew, query, k=5) with ExponentiallyWeightedEuclidean")

println("=" ^ 80)
println("COMPREHENSIVE ANALYSIS COMPLETE")
println("=" ^ 80)
println()

println("""
Summary:
--------
✓ All major code paths analyzed with JET.jl
✓ Distance metrics (Euclidean, Maximum, SquaredEuclidean, ExponentiallyWeighted)
✓ Point set abstractions (PointSet, EmbeddedTimeSeries)
✓ Tree construction and traversal
✓ Search operations (k-NN, range search, count range)
✓ Optimized paths with SearchContext
✓ Batch operations
✓ Brute force reference implementations

If no issues were reported above, the library is type-stable!

Type stability means:
- Predictable performance
- No runtime type inference overhead
- Optimal LLVM code generation
- No unexpected allocations from type uncertainty

For further optimization, consider:
1. Profiling with Profile.jl to identify remaining bottlenecks
2. Benchmarking with BenchmarkTools.jl
3. Checking LLVM code with @code_llvm on hot functions
""")

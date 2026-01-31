"""
JET.jl Type Stability Analysis for ATRIANeighbors.jl

This script uses JET.jl to analyze the library for type stability issues.
JET.jl provides advanced type inference analysis that can detect:
- Type instabilities
- Method errors
- Potential runtime errors

Usage:
    julia --project=test test/test_jet.jl
"""

using ATRIANeighbors
using JET
using Test

println("=" ^ 80)
println("JET.jl Type Stability Analysis for ATRIANeighbors.jl")
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

# Helper function to run JET analysis
function analyze_with_jet(func, args...; name="function", target_modules=())
    println("Analyzing: $name")
    println("-" ^ 80)
    
    # Run JET analysis
    result = @report_opt func(args...)
    
    # Check for issues
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
println("ANALYZING DISTANCE METRICS")
println("=" ^ 80)
println()

# Test Euclidean metric
p1 = rand(D)
p2 = rand(D)
metric = EuclideanMetric()

analyze_with_jet(distance, metric, p1, p2; name="distance(EuclideanMetric, Vector, Vector)")
analyze_with_jet(distance, metric, p1, p2, 1.0; name="distance(EuclideanMetric, Vector, Vector, thresh)")

# Test Maximum metric
max_metric = MaximumMetric()
analyze_with_jet(distance, max_metric, p1, p2; name="distance(MaximumMetric, Vector, Vector)")

# Test with views (common in actual usage)
v1 = view(data, 1, :)
v2 = view(data, 2, :)
analyze_with_jet(distance, metric, v1, v2; name="distance(EuclideanMetric, SubArray, SubArray)")

println("=" ^ 80)
println("ANALYZING POINTSET OPERATIONS")
println("=" ^ 80)
println()

analyze_with_jet(getpoint, ps, 1; name="getpoint(PointSet, Int)")
analyze_with_jet(distance, ps, 1, 2; name="distance(PointSet, Int, Int)")
analyze_with_jet(distance, ps, 1, query; name="distance(PointSet, Int, Vector)")
analyze_with_jet(distance, ps, 1, query, 1.0; name="distance(PointSet, Int, Vector, thresh)")

println("=" ^ 80)
println("ANALYZING EMBEDDED TIME SERIES")
println("=" ^ 80)
println()

ts_data = rand(200)
ts = EmbeddedTimeSeries(ts_data, 10, 1, EuclideanMetric())

analyze_with_jet(getpoint, ts, 1; name="getpoint(EmbeddedTimeSeries, Int)")
analyze_with_jet(distance, ts, 1, 2; name="distance(EmbeddedTimeSeries, Int, Int)")
analyze_with_jet(distance, ts, 1, query; name="distance(EmbeddedTimeSeries, Int, Vector)")

println("=" ^ 80)
println("ANALYZING TREE CONSTRUCTION")
println("=" ^ 80)
println()

analyze_with_jet(ATRIATree, ps; name="ATRIATree(PointSet)")

println("=" ^ 80)
println("ANALYZING SEARCH OPERATIONS")
println("=" ^ 80)
println()

analyze_with_jet(knn, tree, query; name="knn(ATRIATree, Vector)")
analyze_with_jet((tree, q) -> knn(tree, q, k=10), tree, query; name="knn(ATRIATree, Vector, k=10)")
analyze_with_jet((tree, q) -> range_search(tree, q, radius=1.0), tree, query; name="range_search(ATRIATree, Vector, radius)")
analyze_with_jet((tree, q) -> count_range(tree, q, radius=1.0), tree, query; name="count_range(ATRIATree, Vector, radius)")

println("=" ^ 80)
println("ANALYZING DATA STRUCTURES")
println("=" ^ 80)
println()

table = SortedNeighborTable(10)
init_search!(table, 10)
neighbor = Neighbor(1, 0.5)

analyze_with_jet(insert!, table, neighbor; name="insert!(SortedNeighborTable, Neighbor)")
analyze_with_jet(finish_search, table; name="finish_search(SortedNeighborTable)")

println("=" ^ 80)
println("ANALYZING BRUTE FORCE IMPLEMENTATIONS")
println("=" ^ 80)
println()

analyze_with_jet(brute_knn, ps, query, 10; name="brute_knn(PointSet, Vector, Int)")
analyze_with_jet(brute_range_search, ps, query, 1.0; name="brute_range_search(PointSet, Vector, Float64)")

println("=" ^ 80)
println("SUMMARY")
println("=" ^ 80)
println()

println("""
JET.jl analysis complete!

What to look for in the output above:
1. Type instabilities (::Any, ::Union{...} in inferred types)
2. Method ambiguities
3. Potential runtime errors
4. Performance bottlenecks

Common patterns that need fixing:
- Untyped fields in structs
- Missing type parameters
- Container type instabilities
- Closure variable captures
- Abstract field types that should be concrete

Next steps:
1. Review all warnings above
2. Fix critical type instabilities
3. Re-run this script to verify fixes
4. Run benchmarks to measure performance improvements
""")

println("=" ^ 80)
println("Analysis complete!")
println("=" ^ 80)

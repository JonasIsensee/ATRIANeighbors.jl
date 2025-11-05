"""
Type Stability Testing Script for ATRIANeighbors.jl

This script uses @code_warntype and other Julia introspection tools to check
for type instabilities that could cause performance issues.

Usage:
    julia --project=. test/test_type_stability.jl
"""

using ATRIANeighbors
using Test

println("=" ^ 80)
println("Type Stability Analysis for ATRIANeighbors.jl")
println("=" ^ 80)
println()

# Helper function to check for type instabilities
function check_type_stability(func, args...; name="function")
    println("Checking: $name")
    println("-" ^ 80)

    # Use code_warntype to check for type issues
    io = IOBuffer()
    code_warntype(io, func, typeof.(args))
    output = String(take!(io))

    # Check for common type instability markers
    has_any = occursin("Any", output) || occursin("Union{", output)
    has_core_any = occursin("::Any", output)

    if has_core_any
        println("⚠️  WARNING: Type instability detected (::Any found)")
        println(output)
    elseif has_any
        println("⚠️  POSSIBLE ISSUE: Union types or Any detected")
        # Don't print full output for minor issues
    else
        println("✓ Type stable")
    end
    println()

    return !has_core_any
end

# Test data setup
println("Setting up test data...")
N = 100
D = 10
data = rand(N, D)
ps = PointSet(data, EuclideanMetric())
tree = ATRIA(ps, min_points=10)
query = rand(D)

println()
println("=" ^ 80)
println("DISTANCE METRICS")
println("=" ^ 80)
println()

# Test Euclidean metric
p1 = rand(D)
p2 = rand(D)
metric = EuclideanMetric()

check_type_stability(distance, metric, p1, p2; name="distance(EuclideanMetric, Vector, Vector)")
check_type_stability(distance, metric, p1, p2, 1.0; name="distance(EuclideanMetric, Vector, Vector, thresh)")

# Test with views (common in actual usage)
v1 = view(data, 1, :)
v2 = view(data, 2, :)
check_type_stability(distance, metric, v1, v2; name="distance(EuclideanMetric, SubArray, SubArray)")

println("=" ^ 80)
println("POINTSET OPERATIONS")
println("=" ^ 80)
println()

check_type_stability(getpoint, ps, 1; name="getpoint(PointSet, Int)")
check_type_stability(distance, ps, 1, 2; name="distance(PointSet, Int, Int)")
check_type_stability(distance, ps, 1, query; name="distance(PointSet, Int, Vector)")
check_type_stability(distance, ps, 1, query, 1.0; name="distance(PointSet, Int, Vector, thresh)")

println("=" ^ 80)
println("EMBEDDED TIME SERIES")
println("=" ^ 80)
println()

ts_data = rand(200)
ts = EmbeddedTimeSeries(ts_data, 10, 1, EuclideanMetric())

check_type_stability(getpoint, ts, 1; name="getpoint(EmbeddedTimeSeries, Int)")
check_type_stability(distance, ts, 1, 2; name="distance(EmbeddedTimeSeries, Int, Int)")
check_type_stability(distance, ts, 1, query; name="distance(EmbeddedTimeSeries, Int, Vector)")

println("=" ^ 80)
println("TREE CONSTRUCTION")
println("=" ^ 80)
println()

check_type_stability(ATRIA, ps; name="ATRIA(PointSet)")

println("=" ^ 80)
println("SEARCH OPERATIONS")
println("=" ^ 80)
println()

check_type_stability(ATRIANeighbors.knn, tree, query; name="knn(ATRIATree, Vector)")
check_type_stability(ATRIANeighbors.knn, tree, query, k=10; name="knn(ATRIATree, Vector, k=10)")
check_type_stability(range_search, tree, query, 1.0; name="range_search(ATRIATree, Vector, Float64)")
check_type_stability(count_range, tree, query, 1.0; name="count_range(ATRIATree, Vector, Float64)")

println("=" ^ 80)
println("DATA STRUCTURES")
println("=" ^ 80)
println()

table = SortedNeighborTable(10)
init_search!(table, 10)
neighbor = Neighbor(1, 0.5)

check_type_stability(insert!, table, neighbor; name="insert!(SortedNeighborTable, Neighbor)")
check_type_stability(finish_search, table; name="finish_search(SortedNeighborTable)")

println("=" ^ 80)
println("ALLOCATION PROFILING")
println("=" ^ 80)
println()

println("Testing allocations in hot paths...")
println()

# Test distance calculation allocations
println("distance(ps, i, j):")
@time for i in 1:N-1
    distance(ps, i, i+1)
end

println("\ngetpoint(ps, i):")
@time for i in 1:N
    getpoint(ps, i)
end

println("\nEmbeddedTimeSeries getpoint allocations:")
@time for i in 1:50
    getpoint(ts, i)
end

println("\nknn search (k=10):")
@time ATRIANeighbors.knn(tree, query, k=10)

println()
println("=" ^ 80)
println("SUMMARY & RECOMMENDATIONS")
println("=" ^ 80)
println()

println("""
Common Performance Issues to Check:

1. Type Instability:
   - Look for ::Any or ::Union{...} in hot paths
   - Ensure metric types are concrete and inferable
   - Check that views and arrays don't cause type instability

2. Allocations:
   - getpoint() should return views where possible
   - Distance calculations should not allocate
   - EmbeddedTimeSeries is known to allocate in getpoint()

3. Bounds Checking:
   - Use @inbounds in tight loops (already done in metrics)
   - Consider @simd for vectorization (already done in some places)

4. Data Structure Overhead:
   - PriorityQueue usage in knn search
   - Set operations in range_search/count_range
   - Linear search for duplicates in SortedNeighborTable

Next steps:
1. Run this script to identify type instabilities
2. Use Profile.@profile on slow benchmarks
3. Consider using @code_llvm to check generated code quality
4. Benchmark individual functions with BenchmarkTools
""")

println("=" ^ 80)
println("Type stability testing complete!")
println("=" ^ 80)

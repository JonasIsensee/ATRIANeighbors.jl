"""
benchmark_timing.jl

Simple timing benchmark to measure performance improvements.
"""

using Random
using Printf
using Statistics

# Load ATRIA implementation
using ATRIANeighbors

function benchmark_scenario(N, D, k, n_queries)
    rng = MersenneTwister(42)

    # Generate data
    data = randn(rng, N, D)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    # Build tree
    ps = PointSet(data, EuclideanMetric())

    build_time = @elapsed tree = ATRIA(ps, min_points=64)

    # Warmup
    for i in 1:min(10, n_queries)
        query = queries[i, :]
        knn(tree, query, k=k)
    end

    # Benchmark queries
    query_times = Float64[]
    for i in 1:n_queries
        query = queries[i, :]
        t = @elapsed knn(tree, query, k=k)
        push!(query_times, t)
    end

    return (
        build_time = build_time,
        mean_query = mean(query_times),
        median_query = median(query_times),
        min_query = minimum(query_times),
        max_query = maximum(query_times)
    )
end

println("ATRIANeighbors Performance Benchmark")
println("=" ^ 80)
println()

scenarios = [
    (name="Small", N=1000, D=10, k=10, queries=100),
    (name="Medium", N=10000, D=20, k=20, queries=500),
    (name="Large", N=20000, D=30, k=10, queries=500),
]

for scenario in scenarios
    @printf("%-10s: N=%5d, D=%2d, k=%2d, queries=%3d\n",
            scenario.name, scenario.N, scenario.D, scenario.k, scenario.queries)

    result = benchmark_scenario(scenario.N, scenario.D, scenario.k, scenario.queries)

    @printf("  Build time:    %8.3f ms\n", result.build_time * 1000)
    @printf("  Query time:    %8.6f ms (mean)\n", result.mean_query * 1000)
    @printf("  Query time:    %8.6f ms (median)\n", result.median_query * 1000)
    @printf("  Query time:    %8.6f ms (min)\n", result.min_query * 1000)
    @printf("  Query time:    %8.6f ms (max)\n", result.max_query * 1000)
    @printf("  Throughput:    %8.1f queries/sec\n", 1.0 / result.mean_query)
    println()
end

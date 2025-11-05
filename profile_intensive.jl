"""
profile_intensive.jl

More intensive profiling workload to capture better performance data.
"""

using Profile
using Random
using Printf

# Load ATRIA implementation
using ATRIANeighbors

function intensive_workload()
    rng = MersenneTwister(42)

    # Larger datasets for better profiling signal
    scenarios = [
        (N=10000, D=20, k=20, queries=500),
        (N=20000, D=30, k=10, queries=500),
    ]

    for scenario in scenarios
        @info "Running scenario: N=$(scenario.N), D=$(scenario.D), k=$(scenario.k)"

        # Generate data
        data = randn(rng, scenario.N, scenario.D)

        # Generate query points
        query_indices = rand(rng, 1:scenario.N, scenario.queries)
        queries = copy(data[query_indices, :])
        queries .+= randn(rng, size(queries)...) .* 0.01

        # Build tree
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=64)

        # Run many queries
        for i in 1:scenario.queries
            query = queries[i, :]
            knn(tree, query, k=scenario.k)
        end
    end
end

# Warm up
println("Warming up...")
intensive_workload()

# Profile
println("\nProfiling...")
Profile.clear()
@profile intensive_workload()

# Save profile data
using Profile
data = Profile.fetch()
println("\nProfile samples collected: ", length(data))

# Print results
Profile.print(format=:flat, sortedby=:count, mincount=10)

println("\n\nTop functions by sample count:")
println("=" ^ 80)

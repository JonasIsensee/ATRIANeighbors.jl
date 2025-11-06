#!/usr/bin/env julia
"""
Test basic profiling to ensure Profile module works correctly.
"""

using Profile
cd(joinpath(@__DIR__, ".."))
using Pkg
Pkg.activate(".")
using ATRIANeighbors
using Random

function test_workload()
    rng = MersenneTwister(42)
    data = randn(rng, 5000, 20)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=64)

    queries = randn(rng, 200, 20)

    # Run many iterations to ensure samples
    for iter in 1:10
        for i in 1:200
            query = queries[i, :]
            knn(tree, query, k=10)
        end
    end
end

println("Testing basic profiling...")
println()

# Warmup
println("Warming up (compilation)...")
test_workload()

# Now profile
println("Running profile...")
Profile.clear()
Profile.init(n=10_000_000)  # Large buffer
@profile test_workload()

data = Profile.fetch()
println("Collected $(length(data)) samples")

if length(data) > 0
    println("\nProfile seems to work! Top functions:")
    Profile.print(format=:flat, maxdepth=15, sortedby=:count)
else
    println("\nNo samples collected. Possible issues:")
    println("  - Workload too fast")
    println("  - Profile sampling rate too low")
    println("  - Code too optimized (rare)")
end

#!/usr/bin/env julia
"""
Test ProfileTools macros directly.
"""

cd(joinpath(@__DIR__, ".."))
using Pkg
Pkg.activate(".")
using ATRIANeighbors

# Load ProfileTools
include(joinpath(@__DIR__, "ProfileTools.jl"))
using .ProfileTools
using Random

function test_workload()
    rng = MersenneTwister(42)
    data = randn(rng, 5000, 20)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=64)
    queries = randn(rng, 200, 20)

    for i in 1:200
        knn(tree, queries[i, :], k=10)
    end
end

println("Testing ProfileTools macros...")
println()

# Test the macro directly with a begin block
result = ProfileTools.@profile_quick begin
    test_workload()
end

println("Result collected")
println("Runtime profile samples: ", result.runtime === nothing ? "none" : result.runtime.total_samples)

if result.runtime !== nothing && result.runtime.total_samples > 0
    println("\n✅ Macro works!")
    ProfileTools.print_report(result)
else
    println("\n⚠️  Macro collected no samples")
    println("Testing direct Profile.@profile...")

    using Profile
    Profile.clear()
    Profile.@profile test_workload()
    data = Profile.fetch()
    println("Direct @profile collected $(length(data)) samples")
end

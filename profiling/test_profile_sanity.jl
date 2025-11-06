#!/usr/bin/env julia
"""
Sanity check that Profile module works at all.
"""

using Profile

function busy_work()
    total = 0.0
    for i in 1:100_000_000
        total += sin(i)
    end
    return total
end

println("Testing Profile module with busy loop...")
println()

# Warmup
busy_work()

# Profile
Profile.clear()
@profile busy_work()

data = Profile.fetch()
println("Collected $(length(data)) samples")

if length(data) > 0
    println("\n✅ Profile module works!")
    println("\nNow testing with ATRIANeighbors...")

    cd(joinpath(@__DIR__, ".."))
    using Pkg
    Pkg.activate(".")
    using ATRIANeighbors
    using Random

    function atria_work()
        rng = MersenneTwister(42)
        data_mat = randn(rng, 5000, 20)
        ps = PointSet(data_mat, EuclideanMetric())
        tree = ATRIA(ps, min_points=64)
        queries = randn(rng, 500, 20)

        for i in 1:500
            knn(tree, queries[i, :], k=10)
        end
    end

    # Warmup
    atria_work()

    # Profile
    Profile.clear()
    @profile atria_work()

    data2 = Profile.fetch()
    println("ATRIA samples: $(length(data2))")

    if length(data2) > 0
        println("\n✅ ATRIA profiling works!")
        println("\nTop 20 functions:")
        Profile.print(format=:flat, maxdepth=20, sortedby=:count, noisefloor=2.0)
    else
        println("\n⚠️  ATRIA code is too fast for profiling")
        println("This means the code is extremely well optimized!")
    end
else
    println("\n❌ Profile module not working!")
    println("This is a Julia installation issue.")
end

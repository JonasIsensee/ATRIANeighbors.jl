#!/usr/bin/env julia

# Benchmark @turbo vs @simd for distance calculations

using BenchmarkTools
using Random
using LoopVectorization

println("="^80)
println("@turbo vs @simd BENCHMARK")
println("="^80)
println()

Random.seed!(42)

# Test different vector sizes
dimensions = [3, 10, 20, 50, 100]

# @simd version (current)
function dist_simd(p1, p2)
    sum_sq = 0.0
    @inbounds @fastmath @simd for i in eachindex(p1)
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
    end
    return sqrt(sum_sq)
end

# @turbo version (experimental)
function dist_turbo(p1, p2)
    sum_sq = 0.0
    @turbo for i in eachindex(p1)
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
    end
    return sqrt(sum_sq)
end

println("Testing Euclidean distance performance:")
println()

for D in dimensions
    println("D = $D dimensions:")
    println("-"^80)

    p1 = randn(D)
    p2 = randn(D)

    # Warmup
    for _ in 1:100
        dist_simd(p1, p2)
        dist_turbo(p1, p2)
    end

    # Benchmark
    t_simd = @belapsed dist_simd($p1, $p2)
    t_turbo = @belapsed dist_turbo($p1, $p2)

    ratio = t_simd / t_turbo
    winner = ratio > 1.0 ? "@turbo" : "@simd"
    speedup = abs(ratio - 1.0) * 100

    println("  @simd:  $(round(t_simd * 1e9, digits=2)) ns")
    println("  @turbo: $(round(t_turbo * 1e9, digits=2)) ns")
    println("  Ratio:  $(round(ratio, digits=3))x ($winner is $(round(speedup, digits=1))% $(ratio > 1.0 ? "faster" : "slower"))")
    println()
end

println("="^80)
println("SUMMARY")
println("="^80)
println()
println("Testing whether @turbo from LoopVectorization.jl provides")
println("better performance than @simd @fastmath for distance calculations.")
println()
println("If @turbo consistently wins, we should use it!")
println("If @simd wins or it's close, stick with current implementation.")
println()

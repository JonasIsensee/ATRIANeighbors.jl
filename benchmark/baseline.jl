"""
    baseline.jl — Performance baseline and regression check

Establish a baseline:
  julia --project=benchmark -e 'include("benchmark/baseline.jl"); establish_baseline()'

Check for regressions (e.g. in CI):
  julia --project=benchmark -e 'include("benchmark/baseline.jl"); check_regression(0.10)'
  Exit code 0 if no regression, 1 otherwise.
"""

using Pkg
using ATRIANeighbors
using BenchmarkTools
using Dates
using JSON
using Random

const BASELINE_FILE = joinpath(@__DIR__, "baseline.json")

function _run_benchmark()
    N, D, k = 1000, 20, 10
    Random.seed!(42)
    data = randn(D, N)
    tree = ATRIATree(data)
    query = randn(D)

    build_time = @belapsed ATRIATree($data) samples = 20 evals = 3
    query_time = @belapsed knn($tree, $query, k=$k) samples = 100 evals = 5
    allocs = @allocated knn(tree, query, k=k)

    return (; build_time, query_time, allocs, N, D, k)
end

function establish_baseline()
    result = _run_benchmark()
    ver = string(Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["version"])
    baseline = Dict(
        "build_time_ms" => result.build_time * 1000,
        "query_time_us" => result.query_time * 1e6,
        "query_allocs_bytes" => result.allocs,
        "version" => ver,
        "julia_version" => string(VERSION),
        "date" => string(Dates.now()),
    )
    open(BASELINE_FILE, "w") do io
        JSON.print(io, baseline, 4)
    end
    println("Baseline established:")
    for (k, v) in baseline
        println("  $k: $v")
    end
    return baseline
end

function check_regression(tolerance_build_query = 0.10, tolerance_alloc = 0.20)
    if !isfile(BASELINE_FILE)
        @warn "No baseline file at $BASELINE_FILE. Run establish_baseline() first."
        return true
    end
    baseline = JSON.parse(read(BASELINE_FILE, String))
    result = _run_benchmark()

    regressions = String[]
    bt_ms = result.build_time * 1000
    qt_us = result.query_time * 1e6
    build_slow = (bt_ms - baseline["build_time_ms"]) / baseline["build_time_ms"]
    if build_slow > tolerance_build_query
        push!(regressions, "Build time: $(round(build_slow * 100, digits=1))% slower")
    end
    query_slow = (qt_us - baseline["query_time_us"]) / baseline["query_time_us"]
    if query_slow > tolerance_build_query
        push!(regressions, "Query time: $(round(query_slow * 100, digits=1))% slower")
    end
    alloc_more = (result.allocs - baseline["query_allocs_bytes"]) / max(baseline["query_allocs_bytes"], 1)
    if alloc_more > tolerance_alloc
        push!(regressions, "Allocations: $(round(alloc_more * 100, digits=1))% more")
    end

    if isempty(regressions)
        println("✅ No performance regressions detected")
        return true
    else
        println("❌ Performance regressions:")
        for r in regressions
            println("  - $r")
        end
        return false
    end
end

# Usage:
#   establish_baseline()  — save baseline.json
#   check_regression(0.10) — compare current to baseline; return true iff no regression

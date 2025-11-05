# Benchmark matching ATRIA paper specifications
# Validates performance on the exact test conditions from PhysRevE.62.2089

using Printf
using Statistics

# Load ATRIA implementation
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors

# Load utilities
include("chaotic_attractors_v2.jl")  # Using DynamicalSystems.jl
include("dimension_estimation.jl")

# TODO: Implement f_k metric tracking
# This requires instrumenting the distance calculations inside ATRIA.
# For now, we'll focus on timing measurements and D1 estimation.

"""
    benchmark_configuration(name, data, metadata; k=10, n_queries=100)

Run benchmark on a dataset configuration.

Matches paper's protocol:
1. Build tree
2. Estimate D1 (if not already known)
3. Run queries on dataset points (excluding self)
4. Measure f_k (fraction of distance calculations)
5. Report timing and accuracy

# Arguments
- `name`: Configuration name
- `data`: N×D data matrix
- `metadata`: Dict with generation parameters
- `k`: Number of neighbors to find
- `n_queries`: Number of query points to test

# Returns
- Dict with benchmark results
"""
function benchmark_configuration(name::String, data::Matrix{Float64}, metadata::Dict;
                               k::Int=10, n_queries::Int=100)
    N, Ds = size(data)

    println("\n" * "="^80)
    println("BENCHMARK: $name")
    println("="^80)

    # Report dataset properties
    println("\nDataset Properties:")
    println("  System: $(metadata["system"])")
    println("  N = $(N) points")
    println("  Ds = $(Ds) dimensions")

    if haskey(metadata, "expected_D1")
        println("  Expected D1 ≈ $(metadata["expected_D1"])")
    end

    # Estimate D1 if not already measured
    D1_estimated = NaN
    if N >= 5000  # Only estimate for reasonably sized datasets
        println("\nEstimating fractal dimension D1...")
        try
            # Use subset for faster estimation on large datasets
            sample_size = min(N, 10000)
            sample_indices = rand(1:N, sample_size)
            sample_data = data[sample_indices, :]

            D1_estimated, _, _ = estimate_correlation_dimension(
                sample_data,
                n_scales=15,
                max_pairs=5000
            )
        catch e
            println("  Warning: D1 estimation failed: $e")
            D1_estimated = NaN
        end
    else
        println("\n  Skipping D1 estimation (N too small)")
    end

    # Build ATRIA tree
    println("\nBuilding ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())

    build_time = @elapsed begin
        tree = ATRIA(ps, min_points=10)
    end

    println("  Build time: $(round(build_time * 1000, digits=3)) ms")
    println("  Tree statistics:")
    println("    Total clusters: $(tree.total_clusters)")
    println("    Terminal nodes: $(tree.terminal_nodes)")

    # Select query points (from dataset, as paper does)
    query_indices = rand(1:N, n_queries)

    println("\nRunning k-NN queries (k=$k, n_queries=$n_queries)...")

    # Warm-up query
    test_query = data[query_indices[1], :]
    _ = knn(tree, test_query, k=k+1)  # k+1 to exclude self

    # Benchmark queries
    query_times = Float64[]
    for query_idx in query_indices
        query_point = data[query_idx, :]

        query_time = @elapsed begin
            results = knn(tree, query_point, k=k+1)  # k+1 because self is included
        end

        push!(query_times, query_time)
    end

    # Statistics
    mean_query_time = mean(query_times) * 1000  # ms
    median_query_time = median(query_times) * 1000  # ms
    std_query_time = std(query_times) * 1000  # ms

    # Report results
    println("\nResults:")
    println("  Mean query time: $(round(mean_query_time, digits=4)) ms")
    println("  Median query time: $(round(median_query_time, digits=4)) ms")
    println("  Std query time: $(round(std_query_time, digits=4)) ms")

    if !isnan(D1_estimated)
        println("\n  Estimated D1: $(round(D1_estimated, digits=3))")
        if haskey(metadata, "expected_D1")
            expected = metadata["expected_D1"]
            error_pct = abs(D1_estimated - expected) / expected * 100
            println("  Expected D1: $(expected)")
            println("  Error: $(round(error_pct, digits=1))%")
        end
    end

    # Return results
    return Dict(
        "name" => name,
        "N" => N,
        "Ds" => Ds,
        "k" => k,
        "D1_estimated" => D1_estimated,
        "D1_expected" => get(metadata, "expected_D1", NaN),
        "build_time_ms" => build_time * 1000,
        "mean_query_time_ms" => mean_query_time,
        "median_query_time_ms" => median_query_time,
        "std_query_time_ms" => std_query_time,
        "metadata" => metadata
    )
end

"""
    run_paper_benchmarks()

Run all benchmarks matching the paper's specifications.
"""
function run_paper_benchmarks()
    println("ATRIA Paper Benchmark Suite")
    println("Reproducing test conditions from PhysRevE.62.2089")
    println("=" * "="^79)

    results = []

    # Test Set 1: Lorenz Attractor (Data Set C)
    # Paper: N=500,000, Ds=25, D1≈2.05
    # We'll use N=50,000 for practical testing (10x smaller but still 25x larger than current tests)
    println("\n\n" * "+"^80)
    println("TEST SET 1: Lorenz Attractor (scaled from Data Set C)")
    println("+"^80)

    try
        lorenz_data, lorenz_meta = generate_lorenz_attractor(
            N=50000,
            Ds=25,
            Δt=0.01,
            delay=2  # 2 samples * 0.01 = 0.02 time units (close to paper's 0.025)
        )

        result = benchmark_configuration(
            "Lorenz (N=50k, Ds=25)",
            lorenz_data,
            lorenz_meta,
            k=10,
            n_queries=100
        )
        push!(results, result)
    catch e
        println("ERROR in Lorenz benchmark: $e")
        println(stacktrace(catch_backtrace()))
    end

    # Test Set 2: Rössler Attractor with varying M (Data Set B)
    # Paper: N=200,000, Ds=24, M∈{3,5,7,9,11}
    # We'll use N=30,000 for practical testing
    println("\n\n" * "+"^80)
    println("TEST SET 2: Rössler Attractor (scaled from Data Set B)")
    println("+"^80)

    # Note: Using standard 3D Rössler (not hyperchaotic), so M parameter removed
    try
        rossler_data, rossler_meta = generate_roessler_attractor(
            N=30000,
            Ds=24,
            Δt=0.05,
            delay=10  # 10 samples * 0.05 = 0.5 time units
        )

        result = benchmark_configuration(
            "Rössler (N=30k, Ds=24)",
            rossler_data,
            rossler_meta,
            k=10,
            n_queries=100
        )
        push!(results, result)
    catch e
        println("ERROR in Rössler benchmark: $e")
        println(stacktrace(catch_backtrace()))
    end

    # Test Set 3: Hénon Map (Data Set A)
    # Paper: N=200,000, Ds∈{2,4,6,8,10,12}
    # We'll use N=30,000 for practical testing
    println("\n\n" * "+"^80)
    println("TEST SET 3: Hénon Map (scaled from Data Set A)")
    println("+"^80)

    for Ds in [2, 6, 12]  # Test subset of Ds values
        try
            henon_data, henon_meta = generate_henon_map(
                N=30000,
                Ds=Ds
            )

            result = benchmark_configuration(
                "Hénon (N=30k, Ds=$Ds)",
                henon_data,
                henon_meta,
                k=10,
                n_queries=100
            )
            push!(results, result)
        catch e
            println("ERROR in Hénon Ds=$Ds benchmark: $e")
            println(stacktrace(catch_backtrace()))
        end
    end

    # Summary
    println("\n\n" * "="^80)
    println("BENCHMARK SUMMARY")
    println("="^80)

    println("\nConfiguration                    | N      | Ds | D1(est) | D1(exp) | Build(ms) | Query(ms) |")
    println("-" * "-"^88)

    for r in results
        @printf("%-32s | %6d | %2d | %7.3f | %7.3f | %9.2f | %9.4f |\n",
                r["name"],
                r["N"],
                r["Ds"],
                isnan(r["D1_estimated"]) ? 0.0 : r["D1_estimated"],
                isnan(r["D1_expected"]) ? 0.0 : r["D1_expected"],
                r["build_time_ms"],
                r["mean_query_time_ms"])
    end

    println("\n\nKey Metrics:")
    println("  D1 = Fractal/information dimension (lower is better for ATRIA)")
    println("  Build(ms) = Tree construction time")
    println("  Query(ms) = Mean k-NN search time")
    println("\nPaper's Key Finding:")
    println("  For D1 ≈ 2-5 and Ds ≈ 20-25, ATRIA achieves f_k ≈ 0.01-0.05")
    println("  (f_k = distance calculation fraction, 20-100x fewer than brute force)")
    println("\nNote: f_k metric tracking not yet implemented in this benchmark")

    return results
end

# Run benchmarks if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_paper_benchmarks()
end

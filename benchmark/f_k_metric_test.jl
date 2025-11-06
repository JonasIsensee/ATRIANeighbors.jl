# Test f_k metric (distance calculation fraction) on chaotic attractors
# Validates paper's claim: f_k ≈ 0.01-0.05 for D1 < 3

using Printf
using Statistics

# Load ATRIA implementation
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors

# Load utilities
include("chaotic_attractors_v2.jl")
include("dimension_estimation.jl")

"""
    test_f_k_metric(name, data, metadata; k=10, n_queries=100)

Test f_k metric on a dataset.

According to paper (PhysRevE.62.2089, Fig 6):
- For D1 ≈ 1-2: f_k ≈ 0.001-0.01 (100-1000x speedup vs brute force)
- For D1 ≈ 3-5: f_k ≈ 0.01-0.1 (10-100x speedup)
- For D1 > 7: f_k → 1 (no advantage)

# Returns
- Dict with f_k statistics
"""
function test_f_k_metric(name::String, data::Matrix{Float64}, metadata::Dict;
                        k::Int=10, n_queries::Int=100)
    N, Ds = size(data)

    println("\n" * "="^80)
    println("F_K METRIC TEST: $name")
    println("="^80)

    println("\nDataset Properties:")
    println("  System: $(metadata["system"])")
    println("  N = $(N) points")
    println("  Ds = $(Ds) dimensions")

    # Estimate D1 if available
    D1_estimated = NaN
    if haskey(metadata, "expected_D1") && !isnan(metadata["expected_D1"])
        D1_estimated = metadata["expected_D1"]
    end
    if isnan(D1_estimated) && N >= 5000
        # Estimate D1
        sample_size = min(N, 10000)
        sample_indices = rand(1:N, sample_size)
        sample_data = data[sample_indices, :]
        D1_estimated, _, _ = estimate_correlation_dimension(
            sample_data,
            n_scales=15,
            max_pairs=5000
        )
    end

    if !isnan(D1_estimated)
        println("  D1 ≈ $(round(D1_estimated, digits=2))")
    end

    # Build ATRIA tree
    println("\nBuilding ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

    println("  Total clusters: $(tree.total_clusters)")
    println("  Terminal nodes: $(tree.terminal_nodes)")

    # Run queries with f_k tracking
    println("\nRunning k-NN queries with f_k tracking (k=$k, n_queries=$n_queries)...")

    query_indices = rand(1:N, n_queries)
    f_k_values = Float64[]
    distance_calc_counts = Int[]

    for query_idx in query_indices
        query_point = data[query_idx, :]

        # Query with stats tracking
        neighbors, stats = knn(tree, query_point, k=k+1, track_stats=true)

        push!(f_k_values, stats.f_k)
        push!(distance_calc_counts, stats.distance_calcs)
    end

    # Statistics
    mean_f_k = mean(f_k_values)
    median_f_k = median(f_k_values)
    min_f_k = minimum(f_k_values)
    max_f_k = maximum(f_k_values)
    std_f_k = std(f_k_values)

    mean_dist_calcs = mean(distance_calc_counts)
    speedup = 1.0 / mean_f_k

    # Report results
    println("\nF_K METRIC RESULTS:")
    println("  Mean f_k:   $(round(mean_f_k, digits=5)) ($(round(speedup, digits=1))x vs brute force)")
    println("  Median f_k: $(round(median_f_k, digits=5))")
    println("  Min f_k:    $(round(min_f_k, digits=5)) (best case)")
    println("  Max f_k:    $(round(max_f_k, digits=5)) (worst case)")
    println("  Std f_k:    $(round(std_f_k, digits=5))")
    println("\n  Mean distance calcs: $(round(Int, mean_dist_calcs)) / $N points")

    # Paper expectations
    if !isnan(D1_estimated)
        println("\nPAPER EXPECTATIONS (Figure 6):")
        if D1_estimated < 2.0
            println("  For D1 ≈ $(round(D1_estimated, digits=1)): f_k ≈ 0.001-0.01")
            if mean_f_k < 0.02
                println("  ✅ Result matches paper expectations")
            else
                println("  ⚠️ Result higher than expected")
            end
        elseif D1_estimated < 4.0
            println("  For D1 ≈ $(round(D1_estimated, digits=1)): f_k ≈ 0.01-0.05")
            if mean_f_k < 0.1
                println("  ✅ Result matches paper expectations")
            else
                println("  ⚠️ Result higher than expected")
            end
        elseif D1_estimated < 6.0
            println("  For D1 ≈ $(round(D1_estimated, digits=1)): f_k ≈ 0.05-0.2")
            if mean_f_k < 0.3
                println("  ✅ Result matches paper expectations")
            else
                println("  ⚠️ Result higher than expected")
            end
        else
            println("  For D1 ≈ $(round(D1_estimated, digits=1)): f_k → 1 (no advantage expected)")
            println("  ⚠️ High D1 - ATRIA may not be effective")
        end
    end

    return Dict(
        "name" => name,
        "N" => N,
        "Ds" => Ds,
        "D1" => D1_estimated,
        "mean_f_k" => mean_f_k,
        "median_f_k" => median_f_k,
        "min_f_k" => min_f_k,
        "max_f_k" => max_f_k,
        "std_f_k" => std_f_k,
        "speedup" => speedup,
        "mean_distance_calcs" => mean_dist_calcs
    )
end

"""
    run_f_k_tests()

Run f_k metric tests on chaotic attractors.
"""
function run_f_k_tests()
    println("="^80)
    println("F_K METRIC VALIDATION")
    println("Testing distance calculation efficiency on chaotic attractors")
    println("="^80)

    results = []

    # Test 1: Lorenz (D1 ≈ 1.6-2.0)
    println("\n\n" * "+"^80)
    println("TEST 1: Lorenz Attractor (D1 ≈ 2.0)")
    println("+"^80)

    try
        lorenz_data, lorenz_meta = generate_lorenz_attractor(
            N=30000,
            Ds=25,
            Δt=0.01,
            delay=2
        )

        result = test_f_k_metric("Lorenz (N=30k, Ds=25)", lorenz_data, lorenz_meta)
        push!(results, result)
    catch e
        println("ERROR in Lorenz test: $e")
    end

    # Test 2: Rössler (D1 ≈ 2.0)
    println("\n\n" * "+"^80)
    println("TEST 2: Rössler Attractor (D1 ≈ 2.0)")
    println("+"^80)

    try
        rossler_data, rossler_meta = generate_roessler_attractor(
            N=30000,
            Ds=24,
            Δt=0.05,
            delay=10
        )

        result = test_f_k_metric("Rössler (N=30k, Ds=24)", rossler_data, rossler_meta)
        push!(results, result)
    catch e
        println("ERROR in Rössler test: $e")
    end

    # Test 3: Hénon Ds=2 (D1 ≈ 1.2)
    println("\n\n" * "+"^80)
    println("TEST 3: Hénon Map Ds=2 (D1 ≈ 1.2)")
    println("+"^80)

    try
        henon_data, henon_meta = generate_henon_map(N=30000, Ds=2)

        result = test_f_k_metric("Hénon (N=30k, Ds=2)", henon_data, henon_meta)
        push!(results, result)
    catch e
        println("ERROR in Hénon Ds=2 test: $e")
    end

    # Test 4: Hénon Ds=6 (D1 ≈ 3.3)
    println("\n\n" * "+"^80)
    println("TEST 4: Hénon Map Ds=6 (D1 ≈ 3.3)")
    println("+"^80)

    try
        henon_data, henon_meta = generate_henon_map(N=30000, Ds=6)

        result = test_f_k_metric("Hénon (N=30k, Ds=6)", henon_data, henon_meta)
        push!(results, result)
    catch e
        println("ERROR in Hénon Ds=6 test: $e")
    end

    # Test 5: Hénon Ds=12 (D1 ≈ 5.0)
    println("\n\n" * "+"^80)
    println("TEST 5: Hénon Map Ds=12 (D1 ≈ 5.0)")
    println("+"^80)

    try
        henon_data, henon_meta = generate_henon_map(N=30000, Ds=12)

        result = test_f_k_metric("Hénon (N=30k, Ds=12)", henon_data, henon_meta)
        push!(results, result)
    catch e
        println("ERROR in Hénon Ds=12 test: $e")
    end

    # Summary
    println("\n\n" * "="^80)
    println("F_K METRIC SUMMARY")
    println("="^80)

    println("\nConfiguration                    | N      | Ds | D1    | f_k (mean) | Speedup |")
    println("-" * "-"^80)

    for r in results
        @printf("%-32s | %6d | %2d | %5.2f | %10.5f | %7.1fx |\n",
                r["name"],
                r["N"],
                r["Ds"],
                isnan(r["D1"]) ? 0.0 : r["D1"],
                r["mean_f_k"],
                r["speedup"])
    end

    println("\n\nKEY FINDINGS:")
    println("  f_k = fraction of distance calculations vs brute force")
    println("  Speedup = 1 / f_k (lower f_k = higher speedup)")
    println("\nPAPER'S CLAIM (PhysRevE.62.2089, Fig 6):")
    println("  For D1 < 3: f_k ≈ 0.01-0.05 (20-100x speedup)")
    println("  For D1 ≈ 5: f_k ≈ 0.1-0.2 (5-10x speedup)")

    return results
end

# Run tests if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_f_k_tests()
end

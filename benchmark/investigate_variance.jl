# Investigate high query variance on Hénon Ds=2
# Mean=0.0957 ms, Std=0.8974 ms (coefficient of variation = 9.4!)

using Printf
using Statistics
using Plots

# Load ATRIA implementation
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors

# Load utilities
include("chaotic_attractors_v2.jl")

"""
    analyze_query_variance(data, tree; n_queries=1000, k=10)

Analyze query time variance in detail.
"""
function analyze_query_variance(data::Matrix{Float64}, tree::ATRIATree;
                                n_queries::Int=1000, k::Int=10)
    N, D = size(data)

    println("\n" * "="^80)
    println("QUERY VARIANCE ANALYSIS")
    println("="^80)
    println("\nDataset: N=$N, D=$D")
    println("Queries: $n_queries queries, k=$k neighbors")

    # Run queries and collect detailed stats
    query_indices = rand(1:N, n_queries)

    query_times = Float64[]
    distance_calcs = Int[]
    clusters_visited = Int[]

    println("\nRunning $n_queries queries...")

    for (idx, query_idx) in enumerate(query_indices)
        query_point = data[query_idx, :]

        # Measure query time
        time = @elapsed neighbors, stats = ATRIANeighbors.knn(tree, query_point, k=k+1, track_stats=true)

        push!(query_times, time * 1000)  # Convert to ms
        push!(distance_calcs, stats.distance_calcs)

        # Would need to instrument to count clusters visited
        # For now, use distance_calcs as proxy
        push!(clusters_visited, stats.distance_calcs)

        if idx % 100 == 0
            println("  Progress: $idx/$n_queries")
        end
    end

    # Statistics
    mean_time = mean(query_times)
    median_time = median(query_times)
    std_time = std(query_times)
    min_time = minimum(query_times)
    max_time = maximum(query_times)
    cv = std_time / mean_time  # Coefficient of variation

    println("\n" * "-"^80)
    println("QUERY TIME STATISTICS")
    println("-"^80)
    println("  Mean:     $(round(mean_time, digits=4)) ms")
    println("  Median:   $(round(median_time, digits=4)) ms")
    println("  Std Dev:  $(round(std_time, digits=4)) ms")
    println("  Min:      $(round(min_time, digits=4)) ms")
    println("  Max:      $(round(max_time, digits=4)) ms")
    println("  CV:       $(round(cv, digits=3)) (std/mean)")
    println("\n  Ratio (max/min): $(round(max_time/min_time, digits=1))x")

    # Percentiles
    p25 = quantile(query_times, 0.25)
    p75 = quantile(query_times, 0.75)
    p95 = quantile(query_times, 0.95)
    p99 = quantile(query_times, 0.99)

    println("\n  Percentiles:")
    println("    25th: $(round(p25, digits=4)) ms")
    println("    75th: $(round(p75, digits=4)) ms")
    println("    95th: $(round(p95, digits=4)) ms")
    println("    99th: $(round(p99, digits=4)) ms")

    # Distance calculation statistics
    mean_dist_calcs = mean(distance_calcs)
    median_dist_calcs = median(distance_calcs)
    min_dist_calcs = minimum(distance_calcs)
    max_dist_calcs = maximum(distance_calcs)

    println("\n" * "-"^80)
    println("DISTANCE CALCULATION STATISTICS")
    println("-"^80)
    println("  Mean:   $(round(Int, mean_dist_calcs))")
    println("  Median: $(median_dist_calcs)")
    println("  Min:    $(min_dist_calcs)")
    println("  Max:    $(max_dist_calcs)")
    println("  Ratio (max/min): $(round(max_dist_calcs/min_dist_calcs, digits=1))x")

    # Correlation between distance calcs and query time
    correlation = cor(distance_calcs, query_times)
    println("\n  Correlation with query time: $(round(correlation, digits=3))")

    # Identify outliers
    println("\n" * "-"^80)
    println("OUTLIER ANALYSIS")
    println("-"^80)

    # Define outliers as queries > 95th percentile
    outlier_threshold = p95
    outlier_indices = findall(query_times .> outlier_threshold)
    n_outliers = length(outlier_indices)

    println("\n  Outliers (>95th percentile): $n_outliers / $n_queries ($(round(100*n_outliers/n_queries, digits=1))%)")
    println("  Outlier threshold: $(round(outlier_threshold, digits=4)) ms")

    if n_outliers > 0
        println("\n  Top 10 slowest queries:")
        sorted_indices = sortperm(query_times, rev=true)
        for i in 1:min(10, length(sorted_indices))
            idx = sorted_indices[i]
            q_idx = query_indices[idx]
            t = query_times[idx]
            dc = distance_calcs[idx]
            println("    Query #$(i): $(round(t, digits=4)) ms ($(dc) dist calcs, point index: $q_idx)")
        end

        # Analyze outlier characteristics
        outlier_dist_calcs = distance_calcs[outlier_indices]
        normal_dist_calcs = distance_calcs[setdiff(1:n_queries, outlier_indices)]

        mean_outlier_dc = mean(outlier_dist_calcs)
        mean_normal_dc = mean(normal_dist_calcs)

        println("\n  Outlier vs Normal characteristics:")
        println("    Outlier mean dist calcs: $(round(Int, mean_outlier_dc))")
        println("    Normal mean dist calcs:  $(round(Int, mean_normal_dc))")
        println("    Ratio: $(round(mean_outlier_dc / mean_normal_dc, digits=2))x")
    end

    # Tree statistics
    println("\n" * "-"^80)
    println("TREE STATISTICS")
    println("-"^80)
    println("  Total clusters: $(tree.total_clusters)")
    println("  Terminal nodes: $(tree.terminal_nodes)")
    println("  Average cluster size: $(round(N / tree.terminal_nodes, digits=1)) points/terminal")

    # Hypothesis testing
    println("\n" * "-"^80)
    println("HYPOTHESIS TESTING")
    println("-"^80)

    if cv > 1.0
        println("  ❌ HIGH VARIANCE DETECTED (CV > 1.0)")
        println("\n  Possible causes:")
        println("    1. Unbalanced tree structure")
        println("    2. Some queries hit worst-case paths")
        println("    3. Degenerate partitions in 2D space")
        println("    4. Center selection not optimal for 2D maps")
    elseif cv > 0.5
        println("  ⚠️ MODERATE VARIANCE (CV > 0.5)")
        println("\n  Some queries significantly slower than others")
    else
        println("  ✅ ACCEPTABLE VARIANCE (CV < 0.5)")
    end

    # Plot histogram if Plots available
    println("\n" * "-"^80)
    println("VISUALIZATION")
    println("-"^80)

    try
        # Histogram of query times
        p1 = histogram(query_times,
                      bins=50,
                      xlabel="Query Time (ms)",
                      ylabel="Frequency",
                      title="Query Time Distribution (CV=$(round(cv, digits=2)))",
                      legend=false,
                      fillalpha=0.7)

        # Add vertical lines for mean and median
        vline!([mean_time], linewidth=2, linestyle=:dash, color=:red, label="Mean")
        vline!([median_time], linewidth=2, linestyle=:dash, color=:blue, label="Median")

        # Scatter plot: distance calcs vs query time
        p2 = scatter(distance_calcs, query_times,
                    xlabel="Distance Calculations",
                    ylabel="Query Time (ms)",
                    title="Query Time vs Distance Calculations",
                    legend=false,
                    alpha=0.5,
                    markersize=3)

        # Log scale version
        p3 = scatter(distance_calcs, query_times,
                    xlabel="Distance Calculations",
                    ylabel="Query Time (ms)",
                    title="Query Time vs Distance Calculations (log scale)",
                    legend=false,
                    alpha=0.5,
                    markersize=3,
                    yscale=:log10,
                    xscale=:log10)

        # Combined plot
        plot_combined = plot(p1, p2, p3, layout=(1, 3), size=(1400, 400))

        output_file = joinpath(@__DIR__, "variance_analysis.png")
        savefig(plot_combined, output_file)
        println("\n  Visualization saved to: $(output_file)")
    catch e
        println("\n  Warning: Could not generate plots: $e")
    end

    return Dict(
        "mean_time" => mean_time,
        "std_time" => std_time,
        "cv" => cv,
        "correlation" => correlation
    )
end

"""
    run_variance_investigation()

Run variance investigation on Hénon Ds=2.
"""
function run_variance_investigation()
    println("="^80)
    println("HÉNON DS=2 VARIANCE INVESTIGATION")
    println("="^80)

    # Generate Hénon Ds=2 data
    println("\nGenerating Hénon Ds=2 data...")
    henon_data, henon_meta = generate_henon_map(N=30000, Ds=2)

    println("Dataset generated:")
    println("  N = $(size(henon_data, 1)) points")
    println("  Ds = $(size(henon_data, 2)) dimensions")

    # Build ATRIA tree
    println("\nBuilding ATRIA tree...")
    ps = PointSet(henon_data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

    println("  Total clusters: $(tree.total_clusters)")
    println("  Terminal nodes: $(tree.terminal_nodes)")

    # Analyze variance with large sample
    analyze_query_variance(henon_data, tree, n_queries=1000, k=10)

    println("\n\n" * "="^80)
    println("VARIANCE INVESTIGATION COMPLETE")
    println("="^80)
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_variance_investigation()
end

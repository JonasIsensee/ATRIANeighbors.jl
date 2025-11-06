"""
    plotting.jl

Visualization utilities for benchmark results.
Creates publication-quality plots matching the style of the ATRIA paper.
"""

using Plots
using Statistics
using Printf

# Set default plot style
default(
    fontfamily="Computer Modern",
    linewidth=2,
    framestyle=:box,
    label=nothing,
    grid=true,
    legend=:best
)

"""
    BenchmarkResult

Container for benchmark results from a single run.
"""
struct BenchmarkResult
    algorithm::Symbol
    dataset_type::Symbol
    N::Int
    D::Int
    k::Int
    build_time::Float64  # seconds
    query_time::Float64  # seconds per query
    memory_mb::Float64   # megabytes
    n_distance_calcs::Int  # number of distance computations
    metadata::Dict{String, Any}
end

"""
    plot_build_time_vs_n(results::Vector{BenchmarkResult};
                        fixed_D::Union{Nothing,Int}=nothing,
                        algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                        title::String="Tree Construction Time vs Dataset Size")

Plot tree construction time vs dataset size N.
"""
function plot_build_time_vs_n(results::Vector{BenchmarkResult};
                             fixed_D::Union{Nothing,Int}=nothing,
                             algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                             title::String="Tree Construction Time vs Dataset Size")
    # Filter results
    filtered = results
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if algorithms !== nothing
        filtered = filter(r -> r.algorithm in algorithms, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Dataset Size (N)",
        ylabel="Build Time (seconds)",
        title=title,
        xscale=:log10,
        yscale=:log10,
        legend=:topleft
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.N)
        N_vals = [r.N for r in group]
        times = [r.build_time for r in group]

        plot!(plt, N_vals, times,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_build_time_vs_d(results::Vector{BenchmarkResult};
                        fixed_N::Union{Nothing,Int}=nothing,
                        algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                        title::String="Tree Construction Time vs Dimension")

Plot tree construction time vs dimension D.
"""
function plot_build_time_vs_d(results::Vector{BenchmarkResult};
                             fixed_N::Union{Nothing,Int}=nothing,
                             algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                             title::String="Tree Construction Time vs Dimension")
    # Filter results
    filtered = results
    if fixed_N !== nothing
        filtered = filter(r -> r.N == fixed_N, filtered)
    end
    if algorithms !== nothing
        filtered = filter(r -> r.algorithm in algorithms, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Dimension (D)",
        ylabel="Build Time (seconds)",
        title=title,
        xscale=:log10,
        yscale=:log10,
        legend=:topleft
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.D)
        D_vals = [r.D for r in group]
        times = [r.build_time for r in group]

        plot!(plt, D_vals, times,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_query_time_vs_n(results::Vector{BenchmarkResult};
                        fixed_D::Union{Nothing,Int}=nothing,
                        fixed_k::Union{Nothing,Int}=nothing,
                        algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                        title::String="Query Time vs Dataset Size")

Plot query time vs dataset size N.
"""
function plot_query_time_vs_n(results::Vector{BenchmarkResult};
                             fixed_D::Union{Nothing,Int}=nothing,
                             fixed_k::Union{Nothing,Int}=nothing,
                             algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                             title::String="Query Time vs Dataset Size")
    # Filter results
    filtered = results
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if fixed_k !== nothing
        filtered = filter(r -> r.k == fixed_k, filtered)
    end
    if algorithms !== nothing
        filtered = filter(r -> r.algorithm in algorithms, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Dataset Size (N)",
        ylabel="Query Time (seconds)",
        title=title,
        xscale=:log10,
        yscale=:log10,
        legend=:topleft
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.N)
        N_vals = [r.N for r in group]
        times = [r.query_time for r in group]

        plot!(plt, N_vals, times,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_query_time_vs_k(results::Vector{BenchmarkResult};
                        fixed_N::Union{Nothing,Int}=nothing,
                        fixed_D::Union{Nothing,Int}=nothing,
                        algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                        title::String="Query Time vs k")

Plot query time vs number of neighbors k.
"""
function plot_query_time_vs_k(results::Vector{BenchmarkResult};
                             fixed_N::Union{Nothing,Int}=nothing,
                             fixed_D::Union{Nothing,Int}=nothing,
                             algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                             title::String="Query Time vs k")
    # Filter results
    filtered = results
    if fixed_N !== nothing
        filtered = filter(r -> r.N == fixed_N, filtered)
    end
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if algorithms !== nothing
        filtered = filter(r -> r.algorithm in algorithms, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Number of Neighbors (k)",
        ylabel="Query Time (seconds)",
        title=title,
        xscale=:log10,
        yscale=:log10,
        legend=:topleft
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.k)
        k_vals = [r.k for r in group]
        times = [r.query_time for r in group]

        plot!(plt, k_vals, times,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_speedup_factor(results::Vector{BenchmarkResult},
                       baseline_algorithm::Symbol;
                       fixed_D::Union{Nothing,Int}=nothing,
                       fixed_k::Union{Nothing,Int}=nothing,
                       title::String="Speedup Factor vs Dataset Size")

Plot speedup factor relative to a baseline algorithm.
Speedup = baseline_time / algorithm_time (>1 means faster than baseline).
"""
function plot_speedup_factor(results::Vector{BenchmarkResult},
                            baseline_algorithm::Symbol;
                            fixed_D::Union{Nothing,Int}=nothing,
                            fixed_k::Union{Nothing,Int}=nothing,
                            title::String="Speedup Factor vs Dataset Size")
    # Filter results
    filtered = results
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if fixed_k !== nothing
        filtered = filter(r -> r.k == fixed_k, filtered)
    end

    # Group by (dataset_type, N, D, k) to match baseline with test algorithms
    baseline_times = Dict()
    for r in filter(r -> r.algorithm == baseline_algorithm, filtered)
        key = (r.dataset_type, r.N, r.D, r.k)
        baseline_times[key] = r.query_time
    end

    # Calculate speedups
    speedups = []
    for r in filter(r -> r.algorithm != baseline_algorithm, filtered)
        key = (r.dataset_type, r.N, r.D, r.k)
        if haskey(baseline_times, key)
            speedup = baseline_times[key] / r.query_time
            push!(speedups, (r.algorithm, r.dataset_type, r.N, speedup))
        end
    end

    if isempty(speedups)
        @warn "No matching baseline results found"
        return nothing
    end

    # Group by algorithm and dataset
    groups = Dict()
    for (alg, dataset, N, speedup) in speedups
        key = (alg, dataset)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], (N, speedup))
    end

    # Create plot
    plt = plot(
        xlabel="Dataset Size (N)",
        ylabel="Speedup vs $baseline_algorithm",
        title=title,
        xscale=:log10,
        legend=:topleft
    )

    # Add baseline line
    hline!(plt, [1.0], linestyle=:dash, color=:black, label="Baseline ($baseline_algorithm)")

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=x -> x[1])
        N_vals = [x[1] for x in group]
        speedup_vals = [x[2] for x in group]

        plot!(plt, N_vals, speedup_vals,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_memory_usage(results::Vector{BenchmarkResult};
                     fixed_D::Union{Nothing,Int}=nothing,
                     algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                     title::String="Memory Usage vs Dataset Size")

Plot memory usage vs dataset size.
"""
function plot_memory_usage(results::Vector{BenchmarkResult};
                          fixed_D::Union{Nothing,Int}=nothing,
                          algorithms::Union{Nothing,Vector{Symbol}}=nothing,
                          title::String="Memory Usage vs Dataset Size")
    # Filter results
    filtered = results
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if algorithms !== nothing
        filtered = filter(r -> r.algorithm in algorithms, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Dataset Size (N)",
        ylabel="Memory Usage (MB)",
        title=title,
        xscale=:log10,
        yscale=:log10,
        legend=:topleft
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.N)
        N_vals = [r.N for r in group]
        memory = [r.memory_mb for r in group]

        plot!(plt, N_vals, memory,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    plot_pruning_effectiveness(results::Vector{BenchmarkResult};
                              fixed_D::Union{Nothing,Int}=nothing,
                              fixed_k::Union{Nothing,Int}=nothing,
                              title::String="Pruning Effectiveness")

Plot percentage of distance computations saved vs dataset size.
"""
function plot_pruning_effectiveness(results::Vector{BenchmarkResult};
                                   fixed_D::Union{Nothing,Int}=nothing,
                                   fixed_k::Union{Nothing,Int}=nothing,
                                   title::String="Pruning Effectiveness")
    # Filter results
    filtered = results
    if fixed_D !== nothing
        filtered = filter(r -> r.D == fixed_D, filtered)
    end
    if fixed_k !== nothing
        filtered = filter(r -> r.k == fixed_k, filtered)
    end

    if isempty(filtered)
        @warn "No results match the filter criteria"
        return nothing
    end

    # Group by algorithm and dataset type
    groups = Dict()
    for r in filtered
        key = (r.algorithm, r.dataset_type)
        if !haskey(groups, key)
            groups[key] = []
        end
        push!(groups[key], r)
    end

    # Create plot
    plt = plot(
        xlabel="Dataset Size (N)",
        ylabel="Distance Computations Saved (%)",
        title=title,
        xscale=:log10,
        legend=:bottomright,
        ylim=(0, 100)
    )

    # Plot each group
    sorted_keys = sort(collect(keys(groups)))
    for key in sorted_keys
        (alg, dataset) = key
        group = groups[key]
        sort!(group, by=r -> r.N)
        N_vals = [r.N for r in group]
        # Percentage saved = (1 - actual/total) * 100
        # For brute force: actual = N, for ATRIA: actual < N
        pct_saved = [(1 - r.n_distance_calcs / r.N) * 100 for r in group]

        plot!(plt, N_vals, pct_saved,
              marker=:circle,
              label="$alg ($dataset)",
              markersize=4)
    end

    return plt
end

"""
    create_benchmark_report(results::Vector{BenchmarkResult}, output_dir::String;
                           baseline_algorithm::Symbol=:BruteTree)

Generate a complete benchmark report with all plots.
Saves plots to output_dir.
"""
function create_benchmark_report(results::Vector{BenchmarkResult}, output_dir::String;
                                baseline_algorithm::Symbol=:BruteTree)
    mkpath(output_dir)

    @info "Generating benchmark report in $output_dir"

    # Figure 1: Construction time vs N
    plt = plot_build_time_vs_n(results, fixed_D=20)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "build_time_vs_n.png"))
    end

    # Figure 2: Construction time vs D
    plt = plot_build_time_vs_d(results, fixed_N=10000)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "build_time_vs_d.png"))
    end

    # Figure 3: Query time vs N
    plt = plot_query_time_vs_n(results, fixed_D=20, fixed_k=10)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "query_time_vs_n.png"))
    end

    # Figure 4: Query time vs k
    plt = plot_query_time_vs_k(results, fixed_N=10000, fixed_D=20)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "query_time_vs_k.png"))
    end

    # Figure 5: Speedup factor
    plt = plot_speedup_factor(results, baseline_algorithm, fixed_D=20, fixed_k=10)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "speedup_vs_n.png"))
    end

    # Figure 6: Memory usage
    plt = plot_memory_usage(results, fixed_D=20)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "memory_vs_n.png"))
    end

    # Figure 7: Pruning effectiveness
    plt = plot_pruning_effectiveness(results, fixed_D=20, fixed_k=10)
    if plt !== nothing
        savefig(plt, joinpath(output_dir, "pruning_effectiveness.png"))
    end

    @info "Benchmark report generated successfully"
end

"""
    print_results_table(results::Vector{BenchmarkResult}; sortby=:query_time)

Print a formatted table of benchmark results.
"""
function print_results_table(results::Vector{BenchmarkResult}; sortby=:query_time)
    if isempty(results)
        println("No results to display")
        return
    end

    # Sort results
    if sortby == :query_time
        sort!(results, by=r -> r.query_time)
    elseif sortby == :build_time
        sort!(results, by=r -> r.build_time)
    elseif sortby == :N
        sort!(results, by=r -> r.N)
    end

    # Print header
    println("=" ^ 120)
    println(@sprintf("%-15s %-20s %8s %5s %5s %12s %12s %10s %12s",
                     "Algorithm", "Dataset", "N", "D", "k", "Build (s)", "Query (ms)", "Memory (MB)", "Dist Calcs"))
    println("=" ^ 120)

    # Print rows
    for r in results
        println(@sprintf("%-15s %-20s %8d %5d %5d %12.6f %12.6f %10.2f %12d",
                        r.algorithm, r.dataset_type, r.N, r.D, r.k,
                        r.build_time, r.query_time * 1000, r.memory_mb, r.n_distance_calcs))
    end

    println("=" ^ 120)
end

# Export plotting functions
export BenchmarkResult
export plot_build_time_vs_n, plot_build_time_vs_d
export plot_query_time_vs_n, plot_query_time_vs_k
export plot_speedup_factor, plot_memory_usage, plot_pruning_effectiveness
export create_benchmark_report, print_results_table

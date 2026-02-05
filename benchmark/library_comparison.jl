"""
    library_comparison.jl

Comprehensive benchmark comparison of nearest neighbor search libraries:
- ATRIANeighbors.jl (this package)
- NearestNeighbors.jl (KDTree, BallTree)
- HNSW.jl (Hierarchical Navigable Small World graphs)

This script:
1. Runs benchmarks across multiple datasets and parameter combinations
2. Caches results for reproducibility
3. Generates comprehensive plots comparing all libraries
4. Creates a markdown summary report with embedded plots
"""

using Pkg
Pkg.activate(@__DIR__)

# Core dependencies
using ATRIANeighbors
using ATRIANeighbors: EuclideanMetric, knn_batch, knn_batch_parallel
using BenchmarkTools
using NearestNeighbors
using Random
using LinearAlgebra
using Statistics
using Printf
using Dates
using Base.Threads

# Load benchmark modules
include(joinpath(@__DIR__, "utils", "cache.jl"))
include(joinpath(@__DIR__, "utils", "data_generators.jl"))
include(joinpath(@__DIR__, "utils", "plotting.jl"))

# Try to load HNSW
HNSW_AVAILABLE = false
try
    using HNSW
    global HNSW_AVAILABLE = true
    @info "HNSW.jl is available and will be included in benchmarks"
catch e
    @warn "HNSW.jl not available. Install with: Pkg.add(\"HNSW\")" exception=e
end

"""
    LibraryBenchmarkConfig

Extended configuration that includes all library options.
"""
struct LibraryBenchmarkConfig
    algorithm::Symbol  # :ATRIA, :KDTree, :BallTree, :BruteTree, :HNSW
    dataset_type::Symbol
    N::Int
    D::Int
    k::Int
    n_queries::Int
    trials::Int
    use_cache::Bool
    query_mode::Symbol   # :single or :batch
    threading::Symbol    # :single or :multi

    # Algorithm-specific parameters
    min_points::Int       # For ATRIA
    leaf_size::Int        # For KDTree/BallTree
    hnsw_ef_construction::Int  # For HNSW construction
    hnsw_ef_search::Int        # For HNSW search
    hnsw_M::Int                # For HNSW max connections
end

"""
    LibraryBenchmarkConfig with default parameters
"""
function LibraryBenchmarkConfig(algorithm::Symbol, dataset_type::Symbol, N::Int, D::Int, k::Int;
                               n_queries::Int=100, trials::Int=3, use_cache::Bool=true,
                               query_mode::Symbol=:single, threading::Symbol=:single,
                               min_points::Int=64, leaf_size::Int=10,
                               hnsw_ef_construction::Int=200, hnsw_ef_search::Int=50, hnsw_M::Int=16)
    return LibraryBenchmarkConfig(algorithm, dataset_type, N, D, k, n_queries, trials, use_cache,
                                  query_mode, threading, min_points, leaf_size,
                                  hnsw_ef_construction, hnsw_ef_search, hnsw_M)
end

"""
    build_tree_with_config(config::LibraryBenchmarkConfig, data::Matrix{Float64})

Build a search structure based on the algorithm in config.
All data is in D×N format (columns are points).
"""
function build_tree_with_config(config::LibraryBenchmarkConfig, data::Matrix{Float64})
    if config.algorithm == :ATRIA
        ps = PointSet(data, EuclideanMetric())
        return ATRIATree(ps, min_points=config.min_points)
    elseif config.algorithm == :HNSW
        if !HNSW_AVAILABLE
            error("HNSW.jl not available")
        end
        # HNSW expects data in D×N format (same as our layout)
        return HierarchicalNSW(data; M=config.hnsw_M, efConstruction=config.hnsw_ef_construction, ef=config.hnsw_ef_search)
    else
        # NearestNeighbors.jl algorithms expect D×N format (same as our layout)
        if config.algorithm == :KDTree
            return KDTree(data, leafsize=config.leaf_size)
        elseif config.algorithm == :BallTree
            return BallTree(data, leafsize=config.leaf_size)
        elseif config.algorithm == :BruteTree
            return BruteTree(data)
        else
            error("Unknown algorithm: $(config.algorithm)")
        end
    end
end

"""
    benchmark_build_time_lib(config::LibraryBenchmarkConfig, data::Matrix{Float64}) -> Float64

Benchmark tree/graph construction time.
"""
function benchmark_build_time_lib(config::LibraryBenchmarkConfig, data::Matrix{Float64})
    result = @benchmark build_tree_with_config($config, $data) samples=config.trials
    return median(result).time / 1e9  # Convert to seconds
end

"""
    benchmark_query_time_lib(config::LibraryBenchmarkConfig, tree, queries::Matrix{Float64}) -> Tuple{Float64, Int, Dict}

Benchmark query time for all libraries.
Queries is in D×N format (each column is a query point).
Returns (median_query_time_seconds, estimated_distance_computations, metadata).
"""
function benchmark_query_time_lib(config::LibraryBenchmarkConfig, tree, queries::Matrix{Float64})
    n_queries = size(queries, 2)  # Number of columns = number of queries
    k = config.k

    # Normalize modes
    query_mode = config.query_mode
    threading = config.threading
    threads_available = Threads.nthreads()
    threads_used = threading == :multi ? threads_available : 1
    threading = (threading == :multi && threads_available > 1) ? :multi : :single

    # Shared query representations (already in D×N format)
    query_cols = [(@view queries[:, i]) for i in 1:n_queries]  # views over columns

    if config.algorithm == :ATRIA
        avg_dist_calcs = config.N  # Placeholder until we add instrumentation

        if query_mode == :single && threading == :single
            function run_atria_single_serial()
                ctx = SearchContext(tree, k)
                for i in 1:n_queries
                    ATRIANeighbors.knn(tree, (@view queries[:, i]), k=k, ctx=ctx)
                end
            end
            result = @benchmark $run_atria_single_serial() samples=config.trials

        elseif query_mode == :single && threading == :multi
            function run_atria_single_threaded()
                Threads.@threads for i in 1:n_queries
                    local_ctx = SearchContext(tree, k)
                    ATRIANeighbors.knn(tree, (@view queries[:, i]), k=k, ctx=local_ctx)
                end
            end
            result = @benchmark $run_atria_single_threaded() samples=config.trials

        elseif query_mode == :batch && threading == :single
            function run_atria_batch_serial()
                knn_batch(tree, query_cols, k=k)
            end
            result = @benchmark $run_atria_batch_serial() samples=config.trials

        elseif query_mode == :batch && threading == :multi
            function run_atria_batch_parallel()
                knn_batch_parallel(tree, query_cols, k=k)
            end
            result = @benchmark $run_atria_batch_parallel() samples=config.trials
        else
            error("Unsupported ATRIA mode")
        end

    elseif config.algorithm == :HNSW
        if !HNSW_AVAILABLE
            error("HNSW.jl not available")
        end
        HNSW.set_ef!(tree, config.hnsw_ef_search)
        avg_dist_calcs = config.hnsw_ef_search  # Approximate

        if threading == :single
            function run_hnsw_serial()
                for i in 1:n_queries
                    HNSW.knn_search(tree, (@view queries[:, i]), k)
                end
            end
            result = @benchmark $run_hnsw_serial() samples=config.trials
        else
            function run_hnsw_threaded()
                Threads.@threads for i in 1:n_queries
                    HNSW.knn_search(tree, (@view queries[:, i]), k)
                end
            end
            result = @benchmark $run_hnsw_threaded() samples=config.trials
        end

    else
        # NearestNeighbors.jl queries (also uses D×N format)
        avg_dist_calcs = config.algorithm == :BruteTree ? config.N : config.N ÷ 2

        if query_mode == :single && threading == :single
            function run_nn_single_serial()
                for i in 1:n_queries
                    NearestNeighbors.knn(tree, (@view queries[:, i]), k)
                end
            end
            result = @benchmark $run_nn_single_serial() samples=config.trials

        elseif query_mode == :single && threading == :multi
            function run_nn_single_threaded()
                Threads.@threads for i in 1:n_queries
                    NearestNeighbors.knn(tree, (@view queries[:, i]), k)
                end
            end
            result = @benchmark $run_nn_single_threaded() samples=config.trials

        elseif query_mode == :batch && threading == :single
            function run_nn_batch_serial()
                NearestNeighbors.knn(tree, queries, k, true)  # Already D×N
            end
            result = @benchmark $run_nn_batch_serial() samples=config.trials

        elseif query_mode == :batch && threading == :multi
            function run_nn_batch_threaded()
                Threads.@threads for i in 1:n_queries
                    NearestNeighbors.knn(tree, (@view queries[:, i]), k)
                end
            end
            result = @benchmark $run_nn_batch_threaded() samples=config.trials
        else
            error("Unsupported NearestNeighbors mode")
        end
    end

    query_time = (median(result).time / 1e9) / n_queries  # Time per query in seconds
    metadata = Dict(
        "query_mode" => query_mode,
        "threading" => threading,
        "threads_available" => threads_available,
        "threads_used" => threads_used
    )

    return (query_time, avg_dist_calcs, metadata)
end

"""
    run_library_benchmark(config::LibraryBenchmarkConfig; verbose::Bool=true) -> BenchmarkResult

Run a single benchmark with the given configuration.
"""
function run_library_benchmark(config::LibraryBenchmarkConfig; verbose::Bool=true)
    # Generate cache key
    params = Dict(
        "N" => config.N,
        "D" => config.D,
        "k" => config.k,
        "n_queries" => config.n_queries,
        "trials" => config.trials,
        "query_mode" => config.query_mode,
        "threading" => config.threading,
        "min_points" => config.min_points,
        "leaf_size" => config.leaf_size,
        "hnsw_ef_construction" => config.hnsw_ef_construction,
        "hnsw_ef_search" => config.hnsw_ef_search,
        "hnsw_M" => config.hnsw_M,
        "threads_available" => Threads.nthreads()
    )
    cache_key = generate_cache_key(config.algorithm, config.dataset_type, params)

    # Try to load from cache
    if config.use_cache
        cached = load_cached_result(cache_key)
        if cached !== nothing
            result, metadata = cached
            if is_cache_valid(metadata)
                verbose && @info "Using cached result for $cache_key"
                return result
            end
        end
    end

    verbose && @info "Running benchmark: $(config.algorithm) on $(config.dataset_type) (N=$(config.N), D=$(config.D), k=$(config.k), query_mode=$(config.query_mode), threading=$(config.threading))"

    # Generate dataset (returns D×N matrix)
    rng = MersenneTwister(42)  # Fixed seed for reproducibility
    data = generate_dataset(config.dataset_type, config.N, config.D, rng=rng)

    # Generate query points (D×n_queries matrix)
    query_indices = rand(rng, 1:config.N, config.n_queries)
    queries = copy(data[:, query_indices])  # D×n_queries
    queries .+= randn(rng, size(queries)...) .* 0.01  # Small noise

    # Build tree and benchmark construction
    verbose && @info "  Building tree..."
    build_time = benchmark_build_time_lib(config, data)

    # Build tree for query benchmarking
    tree = build_tree_with_config(config, data)

    # Benchmark queries
    verbose && @info "  Benchmarking queries..."
    query_time, dist_calcs, query_metadata = benchmark_query_time_lib(config, tree, queries)

    # Estimate memory
    memory_mb = Base.summarysize(tree) / (1024 * 1024)

    # Create result
    merged_metadata = merge(params, query_metadata)

    result = BenchmarkResult(
        config.algorithm,
        config.dataset_type,
        config.N,
        config.D,
        config.k,
        build_time,
        query_time,
        memory_mb,
        dist_calcs,
        merged_metadata
    )

    # Cache result
    if config.use_cache
        save_cached_result(cache_key, result, params)
    end

    verbose && @info "  Done! Build: $(round(build_time, digits=4))s, Query: $(round(query_time*1000, digits=4))ms"

    return result
end

"""
    run_comprehensive_library_comparison(;kwargs...) -> Vector{BenchmarkResult}

Run comprehensive benchmarks across all available libraries.
"""
function run_comprehensive_library_comparison(;
    algorithms::Union{Nothing,Vector{Symbol}}=nothing,
    dataset_types::Vector{Symbol}=[:lorenz, :gaussian_mixture, :uniform_hypercube, :sphere],
    N_values::Vector{Int}=[1000, 5000, 10000, 50000],
    D_values::Vector{Int}=[10, 20, 50],
    k_values::Vector{Int}=[1, 10, 50],
    query_modes::Vector{Symbol}=[:single, :batch],
    threading_modes::Vector{Symbol}=[:single, :multi],
    n_queries::Int=100,
    trials::Int=3,
    use_cache::Bool=true,
    verbose::Bool=true)

    # Determine which algorithms to test
    if algorithms === nothing
        algorithms = [:ATRIA, :KDTree, :BallTree]
        if HNSW_AVAILABLE
            push!(algorithms, :HNSW)
        end
    end

    @info "Running library comparison with algorithms: $algorithms"

    results = BenchmarkResult[]

    # Helper to run a single configuration with all query/threading variants
    function run_all_modes(algorithm, dataset_type, N, D, k)
        for query_mode in query_modes
            for threading_mode in threading_modes
                if threading_mode == :multi && Threads.nthreads() == 1
                    verbose && @warn "Skipping :multi threading (only 1 thread available)" algorithm=algorithm dataset=dataset_type N=N D=D k=k mode=query_mode
                    continue
                end

                config = LibraryBenchmarkConfig(
                    algorithm, dataset_type, N, D, k,
                    n_queries=n_queries, trials=trials, use_cache=use_cache,
                    query_mode=query_mode, threading=threading_mode
                )
                try
                    result = run_library_benchmark(config, verbose=verbose)
                    push!(results, result)
                catch e
                    @warn "Benchmark failed" exception=e algorithm=algorithm dataset=dataset_type N=N D=D k=k mode=query_mode threading=threading_mode
                end
            end
        end
    end

    # Benchmark 1: Vary N (dataset size) with fixed D and k
    @info "Benchmarking: Varying dataset size N"
    D_fixed = 20
    k_fixed = 10
    for dataset_type in dataset_types
        for N in N_values
            for algorithm in algorithms
                run_all_modes(algorithm, dataset_type, N, D_fixed, k_fixed)
            end
        end
    end

    # Benchmark 2: Vary D (dimension) with fixed N and k
    @info "Benchmarking: Varying dimension D"
    N_fixed = 10000
    k_fixed = 10
    for dataset_type in [:gaussian_mixture, :uniform_hypercube, :sphere]  # Only dimension-agnostic datasets
        for D in D_values
            for algorithm in algorithms
                run_all_modes(algorithm, dataset_type, N_fixed, D, k_fixed)
            end
        end
    end

    # Benchmark 3: Vary k (number of neighbors) with fixed N and D
    @info "Benchmarking: Varying number of neighbors k"
    N_fixed = 10000
    D_fixed = 20
    for dataset_type in dataset_types
        for k in k_values
            for algorithm in algorithms
                run_all_modes(algorithm, dataset_type, N_fixed, D_fixed, k)
            end
        end
    end

    @info "Benchmark complete: $(length(results)) results collected"

    return results
end

"""
    generate_comparison_report(results::Vector{BenchmarkResult}, output_dir::String)

Generate a comprehensive markdown report with plots comparing all libraries.
"""
function generate_comparison_report(results::Vector{BenchmarkResult}, output_dir::String)
    mkpath(output_dir)
    plots_dir = joinpath(output_dir, "plots")
    mkpath(plots_dir)

    @info "Generating comparison report in $output_dir"

    # Generate plots
    plot_files = Dict{String, String}()

    # Plot 1: Query time vs N for each dataset
    for dataset in unique([r.dataset_type for r in results])
        plt = plot_query_time_vs_n(results, fixed_D=20, fixed_k=10,
                                   title="Query Time vs Dataset Size ($dataset)")
        if plt !== nothing
            # Filter for this dataset
            filtered_results = filter(r -> r.dataset_type == dataset && r.D == 20 && r.k == 10, results)
            if !isempty(filtered_results)
                plt_filtered = plot_query_time_vs_n(filtered_results,
                                                     title="Query Time vs Dataset Size ($dataset)")
                if plt_filtered !== nothing
                    filename = "query_time_vs_n_$(dataset).png"
                    savefig(plt_filtered, joinpath(plots_dir, filename))
                    plot_files["query_time_vs_n_$(dataset)"] = filename
                end
            end
        end
    end

    # Plot 2: Query time vs D
    plt = plot_query_time_vs_n(filter(r -> r.N == 10000 && r.k == 10, results),
                               title="Query Time vs Dimension")
    if plt !== nothing
        filename = "query_time_vs_d.png"
        savefig(plt, joinpath(plots_dir, filename))
        plot_files["query_time_vs_d"] = filename
    end

    # Plot 3: Query time vs k
    plt = plot_query_time_vs_k(filter(r -> r.N == 10000 && r.D == 20, results),
                               title="Query Time vs k")
    if plt !== nothing
        filename = "query_time_vs_k.png"
        savefig(plt, joinpath(plots_dir, filename))
        plot_files["query_time_vs_k"] = filename
    end

    # Plot 4: Build time vs N
    plt = plot_build_time_vs_n(filter(r -> r.D == 20 && r.k == 10, results))
    if plt !== nothing
        filename = "build_time_vs_n.png"
        savefig(plt, joinpath(plots_dir, filename))
        plot_files["build_time_vs_n"] = filename
    end

    # Plot 5: Memory usage vs N
    plt = plot_memory_usage(filter(r -> r.D == 20 && r.k == 10, results))
    if plt !== nothing
        filename = "memory_vs_n.png"
        savefig(plt, joinpath(plots_dir, filename))
        plot_files["memory_vs_n"] = filename
    end

    # Plot 6: Speedup comparison (use BruteTree as baseline)
    plt = plot_speedup_factor(filter(r -> r.D == 20 && r.k == 10, results), :BruteTree)
    if plt !== nothing
        filename = "speedup_vs_brutetree.png"
        savefig(plt, joinpath(plots_dir, filename))
        plot_files["speedup_vs_brutetree"] = filename
    end

    # Generate markdown report
    report_path = joinpath(output_dir, "BENCHMARK_REPORT.md")
    open(report_path, "w") do io
        write(io, """
        # Nearest Neighbor Library Comparison Benchmark Report

        Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

        ## Summary

        This report compares the performance of different nearest neighbor search libraries:
        - **ATRIANeighbors.jl**: Our implementation of the ATRIA algorithm
        - **NearestNeighbors.jl**: KDTree and BallTree implementations
        $(HNSW_AVAILABLE ? "- **HNSW.jl**: Hierarchical Navigable Small World graphs" : "")

        Total benchmarks run: $(length(results))

        ## Methodology

        All benchmarks were run with:
        - Multiple dataset types (chaotic attractors, clustered data, uniform distributions)
        - Varying dataset sizes (N), dimensions (D), and number of neighbors (k)
        - Median timing over multiple trials
        - Cached results for reproducibility

        ## Results

        ### Query Performance vs Dataset Size

        """)

        # Add plots for each dataset type
        for dataset in unique([r.dataset_type for r in results])
            if haskey(plot_files, "query_time_vs_n_$(dataset)")
                write(io, """
                #### Dataset: $dataset

                ![Query Time vs N for $dataset](plots/$(plot_files["query_time_vs_n_$(dataset)"]))

                """)
            end
        end

        write(io, """
        ### Build Time Comparison

        """)

        if haskey(plot_files, "build_time_vs_n")
            write(io, """
            ![Build Time vs N](plots/$(plot_files["build_time_vs_n"]))

            """)
        end

        write(io, """
        ### Memory Usage

        """)

        if haskey(plot_files, "memory_vs_n")
            write(io, """
            ![Memory Usage vs N](plots/$(plot_files["memory_vs_n"]))

            """)
        end

        write(io, """
        ### Speedup Analysis

        """)

        if haskey(plot_files, "speedup_vs_brutetree")
            write(io, """
            ![Speedup vs BruteTree](plots/$(plot_files["speedup_vs_brutetree"]))

            """)
        end

        write(io, """
        ### Performance vs Dimension

        """)

        if haskey(plot_files, "query_time_vs_d")
            write(io, """
            ![Query Time vs D](plots/$(plot_files["query_time_vs_d"]))

            """)
        end

        write(io, """
        ### Performance vs Number of Neighbors

        """)

        if haskey(plot_files, "query_time_vs_k")
            write(io, """
            ![Query Time vs k](plots/$(plot_files["query_time_vs_k"]))

            """)
        end

        write(io, """
        ## Detailed Results Table

        """)

        # Print formatted table
        write(io, "| Algorithm | Dataset | N | D | k | Query Mode | Threading | Threads | Build (s) | Query (ms) | Memory (MB) |\n")
        write(io, "|-----------|---------|---|---|---|------------|-----------|---------|-----------|------------|-------------|\n")

        # Sort by dataset, N, algorithm for better readability
        sorted_results = sort(results, by = r -> (r.dataset_type, r.N, r.algorithm))
        for r in sorted_results
            qmode = get(r.metadata, "query_mode", :single)
            threading = get(r.metadata, "threading", :single)
            threads_used = get(r.metadata, "threads_used", get(r.metadata, "threads_available", Threads.nthreads()))

            write(io, @sprintf("| %-9s | %-7s | %5d | %2d | %2d | %-10s | %-9s | %7d | %9.4f | %10.4f | %11.2f |\n",
                              r.algorithm, r.dataset_type, r.N, r.D, r.k,
                              string(qmode), string(threading), threads_used,
                              r.build_time, r.query_time * 1000, r.memory_mb))
        end

        write(io, """

        ## Conclusions

        *Note: Add your analysis of the results here*

        - **ATRIA**:
        - **KDTree**:
        - **BallTree**:
        $(HNSW_AVAILABLE ? "- **HNSW**: " : "")

        ## System Information

        - Julia Version: $(VERSION)
        - Number of Threads: $(Threads.nthreads())
        - Platform: $(Sys.MACHINE)

        """)
    end

    @info "Report generated: $report_path"
    return report_path
end

# Export main functions
export LibraryBenchmarkConfig, run_library_benchmark
export run_comprehensive_library_comparison, generate_comparison_report

# Main execution when run as script
if abspath(PROGRAM_FILE) == @__FILE__
    @info "Running comprehensive library comparison..."

    results = run_comprehensive_library_comparison(
        N_values=[1000, 5000, 10000],
        D_values=[10, 20],
        k_values=[10],
        n_queries=50,
        trials=3
    )

    # Generate report
    output_dir = joinpath(@__DIR__, "results", "library_comparison_$(Dates.format(now(), "yyyy-mm-dd_HHMMSS"))")
    generate_comparison_report(results, output_dir)

    @info "Benchmark complete! Report saved to $output_dir"
end

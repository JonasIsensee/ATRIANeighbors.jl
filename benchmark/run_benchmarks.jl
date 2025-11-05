"""
    run_benchmarks.jl

Main benchmark runner for ATRIANeighbors.jl performance evaluation.

This script orchestrates the entire benchmarking process:
1. Loads benchmark configuration
2. Generates or loads cached datasets
3. Runs benchmarks for ATRIA and reference implementations
4. Caches results
5. Generates plots and reports
"""

# Set up the environment
using Pkg
Pkg.activate(@__DIR__)

# Load dependencies
using ATRIANeighbors
using BenchmarkTools
using NearestNeighbors
using Random
using LinearAlgebra
using Statistics
using Printf
using Dates

# Load local modules
include("cache.jl")
include("data_generators.jl")
include("plotting.jl")

"""
    BenchmarkConfig

Configuration for a single benchmark run.
"""
struct BenchmarkConfig
    algorithm::Symbol  # :ATRIA, :KDTree, :BallTree, :BruteTree
    dataset_type::Symbol
    N::Int
    D::Int
    k::Int
    n_queries::Int
    trials::Int
    use_cache::Bool
    min_points::Int  # For ATRIA tree construction
end

"""
    build_atria_tree(data::Matrix{Float64}, min_points::Int) -> ATRIATree

Build an ATRIA tree from data matrix.
"""
function build_atria_tree(data::Matrix{Float64}, min_points::Int)
    ps = PointSet(data, EuclideanMetric())
    return ATRIA(ps, min_points=min_points)
end

"""
    build_reference_tree(algorithm::Symbol, data::Matrix{Float64})

Build a tree from NearestNeighbors.jl.
"""
function build_reference_tree(algorithm::Symbol, data::Matrix{Float64})
    # NearestNeighbors.jl expects D×N (dimensions × points)
    data_transposed = Matrix(data')

    if algorithm == :KDTree
        return KDTree(data_transposed)
    elseif algorithm == :BallTree
        return BallTree(data_transposed)
    elseif algorithm == :BruteTree
        return BruteTree(data_transposed)
    else
        error("Unknown reference algorithm: $algorithm")
    end
end

"""
    benchmark_build_time(config::BenchmarkConfig, data::Matrix{Float64}) -> Float64

Benchmark tree construction time.
"""
function benchmark_build_time(config::BenchmarkConfig, data::Matrix{Float64})
    if config.algorithm == :ATRIA
        # Benchmark ATRIA tree construction
        result = @benchmark build_atria_tree($data, $(config.min_points)) samples=config.trials
    else
        # Benchmark reference tree construction
        result = @benchmark build_reference_tree($(config.algorithm), $data) samples=config.trials
    end

    return median(result).time / 1e9  # Convert nanoseconds to seconds
end

"""
    benchmark_query_time(config::BenchmarkConfig, tree, queries::Matrix{Float64}) -> Tuple{Float64, Int}

Benchmark query time and count distance computations.
Returns (median_query_time_seconds, avg_distance_computations).
"""
function benchmark_query_time(config::BenchmarkConfig, tree, queries::Matrix{Float64})
    n_queries = size(queries, 1)
    k = config.k

    if config.algorithm == :ATRIA
        # Benchmark ATRIA queries
        function run_atria_query()
            for i in 1:n_queries
                query = queries[i, :]
                ATRIANeighbors.knn(tree, query, k=k)
            end
        end

        result = @benchmark $run_atria_query() samples=config.trials

        # Estimate distance computations (would need instrumentation for exact count)
        # For now, use a heuristic based on tree size
        avg_dist_calcs = config.N  # Placeholder - would need actual counting

    else
        # Benchmark reference queries (NearestNeighbors.jl)
        function run_reference_query()
            for i in 1:n_queries
                query = queries[i, :]
                NearestNeighbors.knn(tree, query, k)
            end
        end

        result = @benchmark $run_reference_query() samples=config.trials

        # Brute force always computes N distances
        if config.algorithm == :BruteTree
            avg_dist_calcs = config.N
        else
            # KDTree/BallTree compute fewer
            avg_dist_calcs = config.N ÷ 2  # Rough estimate
        end
    end

    query_time = (median(result).time / 1e9) / n_queries  # Time per query in seconds
    return (query_time, avg_dist_calcs)
end

"""
    estimate_memory_usage(tree) -> Float64

Estimate memory usage in MB.
"""
function estimate_memory_usage(tree)
    # Use Base.summarysize for approximate memory usage
    bytes = Base.summarysize(tree)
    return bytes / (1024 * 1024)  # Convert to MB
end

"""
    run_single_benchmark(config::BenchmarkConfig; verbose::Bool=true) -> BenchmarkResult

Run a single benchmark configuration.
"""
function run_single_benchmark(config::BenchmarkConfig; verbose::Bool=true)
    # Generate cache key
    params = Dict(
        "N" => config.N,
        "D" => config.D,
        "k" => config.k,
        "n_queries" => config.n_queries,
        "trials" => config.trials,
        "min_points" => config.min_points
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

    verbose && @info "Running benchmark: $(config.algorithm) on $(config.dataset_type) (N=$(config.N), D=$(config.D), k=$(config.k))"

    # Generate dataset
    rng = MersenneTwister(42)  # Fixed seed for reproducibility
    data = generate_dataset(config.dataset_type, config.N, config.D, rng=rng)

    # Generate query points (from the dataset + some noise)
    query_indices = rand(rng, 1:config.N, config.n_queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01  # Small noise

    # Build tree and benchmark construction
    verbose && @info "  Building tree..."
    build_time = benchmark_build_time(config, data)

    # Build tree for query benchmarking
    if config.algorithm == :ATRIA
        tree = build_atria_tree(data, config.min_points)
    else
        tree = build_reference_tree(config.algorithm, data)
    end

    # Benchmark queries
    verbose && @info "  Benchmarking queries..."
    query_time, dist_calcs = benchmark_query_time(config, tree, queries)

    # Estimate memory
    memory_mb = estimate_memory_usage(tree)

    # Create result
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
        Dict("min_points" => config.min_points)
    )

    # Cache result
    if config.use_cache
        save_cached_result(cache_key, result, params)
    end

    verbose && @info "  Done! Build: $(round(build_time, digits=4))s, Query: $(round(query_time*1000, digits=4))ms"

    return result
end

"""
    run_benchmark_suite(;
        algorithms::Vector{Symbol}=[:ATRIA, :KDTree, :BallTree, :BruteTree],
        dataset_types::Vector{Symbol}=[:lorenz, :gaussian_mixture, :uniform_hypercube],
        N_values::Vector{Int}=[100, 500, 1000, 5000, 10000],
        D_values::Vector{Int}=[2, 5, 10, 20, 50],
        k_values::Vector{Int}=[1, 5, 10, 50],
        n_queries::Int=100,
        trials::Int=5,
        min_points::Int=64,
        use_cache::Bool=true,
        verbose::Bool=true) -> Vector{BenchmarkResult}

Run a comprehensive benchmark suite.

This generates a Cartesian product of all parameter combinations,
which can result in many benchmarks. Use filtering to reduce the number.
"""
function run_benchmark_suite(;
    algorithms::Vector{Symbol}=[:ATRIA, :KDTree, :BallTree],
    dataset_types::Vector{Symbol}=[:lorenz, :gaussian_mixture, :uniform_hypercube],
    N_values::Vector{Int}=[1000, 5000, 10000],
    D_values::Vector{Int}=[10, 20],
    k_values::Vector{Int}=[10],
    n_queries::Int=50,
    trials::Int=3,
    min_points::Int=64,
    use_cache::Bool=true,
    verbose::Bool=true)

    results = BenchmarkResult[]

    # For each dataset type, vary N while keeping D and k fixed
    @info "Benchmark Suite: Varying N"
    for dataset_type in dataset_types
        D_fixed = 20  # Fixed dimension
        k_fixed = 10   # Fixed k
        for N in N_values
            for algorithm in algorithms
                config = BenchmarkConfig(
                    algorithm, dataset_type, N, D_fixed, k_fixed,
                    n_queries, trials, use_cache, min_points
                )
                try
                    result = run_single_benchmark(config, verbose=verbose)
                    push!(results, result)
                catch e
                    @warn "Benchmark failed: $algorithm on $dataset_type (N=$N)" exception=e
                end
            end
        end
    end

    # For each dataset type, vary D while keeping N and k fixed
    @info "Benchmark Suite: Varying D"
    for dataset_type in dataset_types
        # Skip fixed-dimension datasets
        if dataset_type in [:lorenz, :rossler, :henon, :logistic, :swiss_roll, :s_curve, :torus]
            continue
        end

        N_fixed = 10000  # Fixed size
        k_fixed = 10     # Fixed k
        for D in D_values
            for algorithm in algorithms
                config = BenchmarkConfig(
                    algorithm, dataset_type, N_fixed, D, k_fixed,
                    n_queries, trials, use_cache, min_points
                )
                try
                    result = run_single_benchmark(config, verbose=verbose)
                    push!(results, result)
                catch e
                    @warn "Benchmark failed: $algorithm on $dataset_type (D=$D)" exception=e
                end
            end
        end
    end

    # For each dataset type, vary k while keeping N and D fixed
    @info "Benchmark Suite: Varying k"
    for dataset_type in dataset_types
        N_fixed = 10000
        D_fixed = 20
        for k in k_values
            for algorithm in algorithms
                config = BenchmarkConfig(
                    algorithm, dataset_type, N_fixed, D_fixed, k,
                    n_queries, trials, use_cache, min_points
                )
                try
                    result = run_single_benchmark(config, verbose=verbose)
                    push!(results, result)
                catch e
                    @warn "Benchmark failed: $algorithm on $dataset_type (k=$k)" exception=e
                end
            end
        end
    end

    return results
end

"""
    quick_benchmark(; use_cache::Bool=true)

Run a quick benchmark for smoke testing (small datasets, few trials).
"""
function quick_benchmark(; use_cache::Bool=true)
    @info "Running quick benchmark suite (small datasets for testing)..."

    results = run_benchmark_suite(
        algorithms=[:ATRIA, :KDTree, :BruteTree],
        dataset_types=[:gaussian_mixture, :uniform_hypercube],
        N_values=[100, 500, 1000],
        D_values=[10],
        k_values=[10],
        n_queries=20,
        trials=2,
        use_cache=use_cache,
        verbose=true
    )

    @info "Quick benchmark complete: $(length(results)) results"
    print_results_table(results, sortby=:query_time)

    return results
end

"""
    full_benchmark(; use_cache::Bool=true)

Run the full benchmark suite (takes significant time).
"""
function full_benchmark(; use_cache::Bool=true)
    @info "Running full benchmark suite (this will take a while)..."

    results = run_benchmark_suite(
        algorithms=[:ATRIA, :KDTree, :BallTree, :BruteTree],
        dataset_types=[:lorenz, :rossler, :gaussian_mixture, :hierarchical,
                      :uniform_hypercube, :sphere, :line],
        N_values=[100, 500, 1000, 5000, 10000, 50000],
        D_values=[2, 5, 10, 20, 50, 100],
        k_values=[1, 5, 10, 50, 100],
        n_queries=100,
        trials=5,
        use_cache=use_cache,
        verbose=true
    )

    @info "Full benchmark complete: $(length(results)) results"

    # Generate report
    output_dir = joinpath(@__DIR__, "results", "report_$(Dates.format(now(), "yyyy-mm-dd_HHMMSS"))")
    create_benchmark_report(results, output_dir)

    @info "Report saved to $output_dir"

    return results
end

# Export main functions
export BenchmarkConfig, run_single_benchmark, run_benchmark_suite
export quick_benchmark, full_benchmark

# Allow running from command line
if abspath(PROGRAM_FILE) == @__FILE__
    @info "Running quick benchmark..."
    results = quick_benchmark()
end

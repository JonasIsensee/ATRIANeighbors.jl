"""
    run_full_comparison.jl

Run the full comprehensive library comparison benchmark suite.
This is the main entry point for running all benchmarks and generating the report.

Usage:
    ~/.juliaup/bin/julialauncher --project=. benchmark/run_full_comparison.jl

Or with custom parameters:
    julia> include("benchmark/run_full_comparison.jl")
    julia> run_full_benchmark(mode=:quick)  # or :standard, :comprehensive
"""

using Pkg
Pkg.activate(@__DIR__)

using Base.Threads

@info "Loading library comparison framework..."
include("library_comparison.jl")

"""
    run_full_benchmark(; mode=:standard)

Run the full benchmark suite with predefined configurations.

Modes:
- :quick - Fast test with small datasets (2-5 minutes)
- :standard - Standard benchmark suite (15-30 minutes)
- :comprehensive - Full comprehensive benchmarks (1-2 hours)
"""
function run_full_benchmark(; mode=:standard)
    if mode == :quick
        @info "Running QUICK benchmark mode (estimated time: 2-5 minutes)"
        results = run_comprehensive_library_comparison(
            dataset_types=[:gaussian_mixture, :uniform_hypercube, :sphere],
            N_values=[1000, 5000, 10000],
            D_values=[10, 20],
            k_values=[10],
            n_queries=50,
            trials=3,
            use_cache=true,
            verbose=true
        )
    elseif mode == :standard
        @info "Running STANDARD benchmark mode (estimated time: 15-30 minutes)"
        results = run_comprehensive_library_comparison(
            dataset_types=[:lorenz, :gaussian_mixture, :uniform_hypercube, :sphere, :hierarchical],
            N_values=[1000, 5000, 10000, 50000],
            D_values=[5, 10, 20, 50],
            k_values=[1, 10, 50],
            n_queries=100,
            trials=5,
            use_cache=true,
            verbose=true
        )
    elseif mode == :comprehensive
        @info "Running COMPREHENSIVE benchmark mode (estimated time: 1-2 hours)"
        results = run_comprehensive_library_comparison(
            dataset_types=[:lorenz, :rossler, :gaussian_mixture, :hierarchical,
                          :uniform_hypercube, :sphere, :line, :swiss_roll],
            N_values=[500, 1000, 5000, 10000, 50000, 100000],
            D_values=[2, 5, 10, 20, 50, 100],
            k_values=[1, 5, 10, 25, 50, 100],
            n_queries=200,
            trials=10,
            use_cache=true,
            verbose=true
        )
    else
        error("Unknown mode: $mode. Choose from :quick, :standard, or :comprehensive")
    end

    # Generate report
    mode_str = string(mode)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    output_dir = joinpath(@__DIR__, "results", "library_comparison_$(mode_str)_$(timestamp)")

    @info "Generating report..."
    report_path = generate_comparison_report(results, output_dir)

    # Print summary
    println("\n" * "="^80)
    println("BENCHMARK COMPLETE!")
    println("="^80)
    println("Mode: $mode_str")
    println("Total benchmarks: $(length(results))")
    println("Report location: $report_path")
    println("Plots directory: $(joinpath(output_dir, "plots"))")
    println("="^80)

    # Print top performers
    println("Top Performers (by query time):")
    println("-"^80)
    top_results = sort(results, by=r->r.query_time)[1:min(10, length(results))]
    for (i, r) in enumerate(top_results)
        qmode = get(r.metadata, "query_mode", :single)
        threading = get(r.metadata, "threading", :single)
        threads = get(r.metadata, "threads_used", Threads.nthreads())
        println(@sprintf("%2d. %-10s %-15s N=%-6d D=%-3d k=%-3d mode=%-6s thr=%-5s threads=%-2d Query=%.4fms",
                        i, r.algorithm, r.dataset_type, r.N, r.D, r.k,
                        string(qmode), string(threading), threads, r.query_time*1000))
    end

    println("\n" * "="^80)
    println("View the full report at: $report_path")
    println("="^80 * "\n")

    return results, report_path
end

# Run when executed as a script
if abspath(PROGRAM_FILE) == @__FILE__
    # Default to standard mode when run as a script
    mode = get(ENV, "BENCHMARK_MODE", "standard") |> Symbol
    @info "Starting benchmark suite in $mode mode..."
    @info "To change mode, set BENCHMARK_MODE environment variable to 'quick', 'standard', or 'comprehensive'"

    results, report_path = run_full_benchmark(mode=mode)

    println("\n✓ Benchmark suite completed successfully!")
    println("📊 View your results at: $report_path")
end

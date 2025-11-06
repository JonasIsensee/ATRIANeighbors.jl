#!/usr/bin/env julia
"""
profile_cli.jl

Command-line interface for ProfileTools.jl - streamlined profiling analysis
optimized for LLM agents and CLI workflows.

Usage:
    # Quick runtime profile
    julia --project=. profiling/profile_cli.jl quick [workload]

    # Deep profile (runtime + allocations)
    julia --project=. profiling/profile_cli.jl deep [workload]

    # Allocation-only profile
    julia --project=. profiling/profile_cli.jl allocs [workload]

    # Type stability check
    julia --project=. profiling/profile_cli.jl type-check <function> <types>

    # Run guided profiling session
    julia --project=. profiling/profile_cli.jl guided

    # Help
    julia --project=. profiling/profile_cli.jl help

Workloads:
    small       - 1K points, D=10, 50 queries (fast, for quick checks)
    medium      - 5K points, D=20, 200 queries (default, balanced)
    large       - 10K points, D=30, 500 queries (thorough, slower)
    custom      - Run custom workload (will prompt for parameters)
"""

# Load ATRIANeighbors first
cd(joinpath(@__DIR__, ".."))
using Pkg
Pkg.activate(".")
using ATRIANeighbors

# Load ProfileTools module (local file)
include(joinpath(@__DIR__, "ProfileTools.jl"))
using .ProfileTools
using Random
using Printf

# ============================================================================
# Workload Definitions
# ============================================================================

"""
Predefined workload configurations.
"""
const WORKLOADS = Dict(
    "small" => (N=1000, D=10, k=10, queries=50),
    "medium" => (N=5000, D=20, k=10, queries=200),
    "large" => (N=10000, D=30, k=15, queries=500),
)

"""
    run_atria_workload(config; iterations=5)

Run ATRIA workload with given configuration.
Runs multiple iterations to ensure enough samples for profiling.
"""
function run_atria_workload(config; iterations=5)
    rng = MersenneTwister(42)

    # Generate data
    data = randn(rng, config.N, config.D)
    ps = PointSet(data, EuclideanMetric())

    # Build tree
    tree = ATRIA(ps, min_points=64)

    # Generate queries
    query_indices = rand(rng, 1:config.N, config.queries)
    queries = copy(data[query_indices, :])
    queries .+= randn(rng, size(queries)...) .* 0.01

    # Run k-NN searches multiple times to ensure enough runtime for profiling
    for iter in 1:iterations
        for i in 1:config.queries
            query = queries[i, :]
            knn(tree, query, k=config.k)
        end
    end
end

# ============================================================================
# CLI Commands
# ============================================================================

"""
    cmd_quick(workload::String)

Run quick runtime profile.
"""
function cmd_quick(workload::String="medium")
    config = get(WORKLOADS, workload, WORKLOADS["medium"])

    println("⚡ Quick Profile")
    println("="^80)
    println("Workload: $workload")
    println("  N=$(config.N), D=$(config.D), k=$(config.k), queries=$(config.queries)")
    println()
    println("Running profile...")
    println()

    result = ProfileTools.@profile_quick run_atria_workload(config)

    ProfileTools.print_report(result)

    println("\n💡 Next Steps:")
    println("  • Run 'deep' profile for allocation analysis")
    println("  • Use 'guided' mode for interactive optimization workflow")
    println("  • Focus on top 3 hotspots for maximum impact")
end

"""
    cmd_deep(workload::String)

Run deep profile with runtime and allocations.
"""
function cmd_deep(workload::String="medium")
    config = get(WORKLOADS, workload, WORKLOADS["medium"])

    println("🔍 Deep Profile (Runtime + Allocations)")
    println("="^80)
    println("Workload: $workload")
    println("  N=$(config.N), D=$(config.D), k=$(config.k), queries=$(config.queries)")
    println()
    println("This will take longer than quick profile...")
    println()

    result = ProfileTools.@profile_deep run_atria_workload(config)

    ProfileTools.print_report(result)

    println("\n💡 Next Steps:")
    println("  • Address high-byte allocation sites first")
    println("  • Use type-check command for functions with dynamic dispatch")
    println("  • Re-run profile after optimizations to measure improvement")
end

"""
    cmd_allocs(workload::String)

Run allocation-focused profile.
"""
function cmd_allocs(workload::String="medium")
    config = get(WORKLOADS, workload, WORKLOADS["medium"])

    println("📊 Allocation Profile")
    println("="^80)
    println("Workload: $workload")
    println("  N=$(config.N), D=$(config.D), k=$(config.k), queries=$(config.queries)")
    println()
    println("Sampling all allocations (this will be slower)...")
    println()

    result = ProfileTools.@profile_allocs run_atria_workload(config)

    ProfileTools.print_report(result)

    println("\n💡 Next Steps:")
    println("  • Fix allocations in hot loops")
    println("  • Use @allocated macro to verify improvements")
    println("  • Run BenchmarkTools.@btime for precise before/after comparison")
end

"""
    cmd_type_check()

Interactive type stability checking.
"""
function cmd_type_check()
    println("🔬 Type Stability Checker")
    println("="^80)
    println()
    println("Common functions to check:")
    println("  1. ATRIANeighbors.knn")
    println("  2. ATRIANeighbors._search")
    println("  3. ATRIANeighbors.distance")
    println("  4. Custom function")
    println()
    print("Select (1-4): ")

    choice = readline()

    # For now, show example
    println("\n⚠️  Type stability checking requires interactive mode")
    println()
    println("To check type stability manually:")
    println("  1. Start Julia REPL: julia --project=.")
    println("  2. Load code: using ATRIANeighbors")
    println("  3. Check function: @code_warntype knn(tree, query, k=10)")
    println()
    println("Look for:")
    println("  🔴 Body::Any or Body::Union{...} - indicates type instability")
    println("  🟡 Red highlighted variables - have unstable types")
    println("  ✅ Body::<ConcreteType> - type stable!")
    println()
    println("Advanced tools:")
    println("  • Cthulhu.jl: @descend function(args...) for interactive analysis")
    println("  • JET.jl: @report_opt function(args...) for automated checks")
end

"""
    cmd_guided()

Run guided profiling session with step-by-step workflow.
"""
function cmd_guided()
    println("🎯 Guided Profiling Session")
    println("="^80)
    println()
    println("This will walk you through a complete performance analysis workflow.")
    println()

    # Step 1: Initial profile
    println("STEP 1: Initial Runtime Profile")
    println("-"^80)
    println("We'll start with a quick runtime profile to identify hotspots.")
    println()
    print("Press Enter to continue...")
    readline()

    result1 = ProfileTools.@profile_quick run_atria_workload(WORKLOADS["medium"])
    ProfileTools.print_report(result1)

    println("\n📋 Analysis:")
    if result1.runtime !== nothing && !isempty(result1.runtime.atria_specific)
        # Get top category
        max_cat = ""
        max_samples = 0
        for (cat, hotspots) in result1.runtime.categorized
            if !isempty(hotspots)
                samples = sum(h.samples for h in hotspots)
                if samples > max_samples
                    max_samples = samples
                    max_cat = cat
                end
            end
        end

        cat_name = replace(max_cat, "_" => " ") |> ProfileTools.titlecase
        println("Your biggest bottleneck appears to be: $cat_name")
        println()
    end

    print("Continue to allocation analysis? (y/n): ")
    response = readline()
    if lowercase(strip(response)) != "y"
        println("Session ended. Run 'guided' again anytime!")
        return
    end

    # Step 2: Allocation profile
    println("\nSTEP 2: Allocation Analysis")
    println("-"^80)
    println("Now we'll check for memory allocation hotspots.")
    println()

    result2 = ProfileTools.@profile_allocs run_atria_workload(WORKLOADS["medium"])

    if result2.allocations !== nothing
        ProfileTools.print_allocation_report(result2.allocations)

        if result2.allocations.total_bytes > 1_000_000
            println("📋 Analysis:")
            println("Your code allocates $(ProfileTools.format_bytes(result2.allocations.total_bytes)).")
            println("This is relatively high - focus on reducing allocations in hot loops.")
        else
            println("📋 Analysis:")
            println("Allocation volume is reasonable.")
        end
    end

    println()
    print("Continue to recommendations? (y/n): ")
    response = readline()
    if lowercase(strip(response)) != "y"
        println("Session ended. Run 'guided' again anytime!")
        return
    end

    # Step 3: Action plan
    println("\nSTEP 3: Action Plan")
    println("-"^80)
    println()
    println("Based on the analysis, here's your optimization roadmap:")
    println()

    for (i, rec) in enumerate(result1.recommendations)
        println("$i. $rec")
    end

    println()
    println("Recommended workflow:")
    println("  1. Fix top allocation site first")
    println("  2. Add @inbounds/@simd to hot inner loops")
    println("  3. Run 'quick' profile to measure improvement")
    println("  4. Repeat until performance target met")
    println()

    println("="^80)
    println("Guided session complete!")
    println()
    println("Next: Implement fixes and re-run this guided analysis to compare.")
end

"""
    cmd_compare()

Compare two profile runs (placeholder for future).
"""
function cmd_compare()
    println("📊 Profile Comparison")
    println("="^80)
    println()
    println("⚠️  Comparison mode not yet implemented")
    println()
    println("To manually compare profiles:")
    println("  1. Run profile before optimization, save output to file1.txt")
    println("  2. Make optimizations")
    println("  3. Run profile again, save to file2.txt")
    println("  4. Compare files side-by-side")
    println()
    println("Future: This will automate before/after comparison with metrics")
end

"""
    cmd_help()

Show help message.
"""
function cmd_help()
    println("""
ATRIANeighbors.jl - Profile CLI
================================

QUICK START:
    # Run a quick profile (takes ~2 seconds)
    julia --project=. profiling/profile_cli.jl quick

    # Run comprehensive analysis (takes ~10 seconds)
    julia --project=. profiling/profile_cli.jl deep

    # Guided workflow for beginners
    julia --project=. profiling/profile_cli.jl guided

COMMANDS:

  quick [workload]
      Fast runtime profiling to identify hotspots.
      Use for quick iteration during optimization.
      Default workload: medium (5K points, 200 queries)

  deep [workload]
      Comprehensive profiling with runtime + allocations.
      Use when you need detailed allocation analysis.
      Takes longer but provides complete picture.

  allocs [workload]
      Allocation-focused profiling with full sampling.
      Use to debug memory allocation issues.
      Slowest but most detailed allocation data.

  guided
      Interactive session that walks through complete
      performance analysis workflow step-by-step.
      Best for first-time profiling.

  type-check
      Instructions for checking type stability.
      Type instabilities cause dynamic dispatch (slow!).

  compare (coming soon)
      Compare before/after profile results.

  help
      Show this message.

WORKLOADS:

  small       1K points, D=10, 50 queries       (~1 second)
  medium      5K points, D=20, 200 queries      (~5 seconds, default)
  large       10K points, D=30, 500 queries     (~20 seconds)

UNDERSTANDING OUTPUT:

Runtime Profile:
  • Shows where CPU time is spent
  • Focus on categories with >15% of samples
  • Top functions are your optimization targets

Allocation Profile:
  • Shows memory allocation hotspots
  • "Total bytes" matters more than count
  • Look for allocations in inner loops

Recommendations:
  • Prioritized list of optimizations
  • Start from the top
  • Re-profile after each major change

OPTIMIZATION WORKFLOW:

  1. Run 'quick' profile to identify bottleneck category
  2. Run 'deep' profile to see allocations
  3. Fix top 1-2 issues
  4. Run 'quick' again to verify improvement
  5. Repeat until performance goals met

ADVANCED TIPS:

  • Use @code_warntype to check type stability
  • Use @btime from BenchmarkTools for micro-benchmarks
  • Use ProfileView.jl for graphical flame graphs
  • Use Cthulhu.jl for deep type inference analysis

For more information, see profiling/README.md
""")
end

# ============================================================================
# Main Entry Point
# ============================================================================

"""
    main(args::Vector{String})

Main CLI dispatcher.
"""
function main(args::Vector{String})
    if isempty(args)
        println("❌ No command specified")
        println()
        cmd_help()
        return
    end

    command = args[1]
    rest = args[2:end]

    if command == "quick"
        workload = isempty(rest) ? "medium" : rest[1]
        cmd_quick(workload)
    elseif command == "deep"
        workload = isempty(rest) ? "medium" : rest[1]
        cmd_deep(workload)
    elseif command == "allocs" || command == "allocations"
        workload = isempty(rest) ? "medium" : rest[1]
        cmd_allocs(workload)
    elseif command == "type-check" || command == "typecheck"
        cmd_type_check()
    elseif command == "guided" || command == "guide"
        cmd_guided()
    elseif command == "compare"
        cmd_compare()
    elseif command == "help" || command == "--help" || command == "-h"
        cmd_help()
    else
        println("❌ Unknown command: $command")
        println()
        cmd_help()
    end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

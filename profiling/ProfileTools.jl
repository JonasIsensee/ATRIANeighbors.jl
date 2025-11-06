"""
ProfileTools.jl

A comprehensive, LLM-friendly profiling analysis library for ATRIANeighbors.jl.
Combines runtime profiling, allocation tracking, and type stability analysis
into a single streamlined interface.

Key Features:
- Runtime hotspot detection
- Allocation profiling with source tracking
- Type instability detection
- Dynamic dispatch identification
- Concise, actionable reports optimized for LLM analysis
- CLI-friendly output with clear next steps

Usage:
    using ProfileTools

    # Quick analysis
    result = @profile_quick my_function(args...)

    # Deep analysis
    result = @profile_deep my_function(args...)

    # Allocation-focused analysis
    result = @profile_allocs my_function(args...)

    # Type stability check
    check_type_stability(my_function, (ArgType1, ArgType2))
"""
module ProfileTools

using Profile
using InteractiveUtils
using Printf
using Statistics
using Dates

export ProfileResult, RuntimeProfile, AllocationProfile, TypeStabilityReport
export profile_runtime, profile_allocations, check_type_stability
export @profile_quick, @profile_deep, @profile_allocs
export print_report, save_report

# ============================================================================
# Data Structures
# ============================================================================

"""
A single hotspot entry from profiling.
"""
struct HotspotEntry
    function_name::String
    file::String
    line::Int
    samples::Int
    percentage::Float64
end

"""
Runtime profiling results.
"""
struct RuntimeProfile
    total_samples::Int
    hotspots::Vector{HotspotEntry}
    atria_specific::Vector{HotspotEntry}
    categorized::Dict{String, Vector{HotspotEntry}}
    timestamp::String
end

"""
A single allocation site.
"""
struct AllocationSite
    function_name::String
    file::String
    line::Int
    count::Int
    total_bytes::Int
    avg_bytes::Float64
end

"""
Allocation profiling results.
"""
struct AllocationProfile
    total_allocations::Int
    total_bytes::Int
    allocation_sites::Vector{AllocationSite}
    atria_specific::Vector{AllocationSite}
    timestamp::String
end

"""
Type instability information.
"""
struct TypeInstability
    function_name::String
    signature::String
    unstable_variables::Vector{String}
    return_type::String
    severity::Symbol  # :high, :medium, :low
end

"""
Type stability analysis results.
"""
struct TypeStabilityReport
    function_name::String
    is_stable::Bool
    instabilities::Vector{TypeInstability}
    recommendations::Vector{String}
    timestamp::String
end

"""
Complete profiling result combining all analyses.
"""
struct ProfileResult
    runtime::Union{RuntimeProfile, Nothing}
    allocations::Union{AllocationProfile, Nothing}
    type_stability::Union{TypeStabilityReport, Nothing}
    recommendations::Vector{String}
    summary::String
end

# ============================================================================
# Runtime Profiling
# ============================================================================

"""
    profile_runtime(f::Function; warmup=true, samples=10000000) -> RuntimeProfile

Profile runtime performance of function f.
"""
function profile_runtime(f::Function; warmup=true, samples=10000000)
    # Warmup
    if warmup
        f()
    end

    # Profile
    Profile.clear()
    Profile.init(n=samples)
    Profile.@profile f()

    # Analyze results
    return analyze_runtime_profile()
end

"""
    analyze_runtime_profile() -> RuntimeProfile

Analyze current Profile data and return structured results.
"""
function analyze_runtime_profile()
    data = Profile.fetch()

    if isempty(data)
        return RuntimeProfile(0, HotspotEntry[], HotspotEntry[], Dict(), now_string())
    end

    # Count samples per function/line
    function_counts = Dict{Tuple{String,String,Int}, Int}()

    for frame_idx in data
        if frame_idx > 0
            try
                frames = Profile.lookup(frame_idx)
                if !isempty(frames)
                    frame = frames[1]
                    func_name = String(frame.func)
                    file = String(frame.file)
                    line = frame.line

                    # Skip low-level C functions
                    if !startswith(file, "libc") &&
                       !startswith(file, "libopenlibm") &&
                       !startswith(func_name, "jl_") &&
                       func_name != "unknown function"

                        key = (func_name, file, line)
                        function_counts[key] = get(function_counts, key, 0) + 1
                    end
                end
            catch
                continue
            end
        end
    end

    total_samples = length(data)

    # Create hotspot entries
    hotspots = [
        HotspotEntry(func, file, line, count, 100.0 * count / total_samples)
        for ((func, file, line), count) in function_counts
    ]

    # Sort by samples
    sort!(hotspots, by=x->x.samples, rev=true)

    # Filter ATRIA-specific code
    atria_files = ["tree.jl", "search.jl", "structures.jl", "metrics.jl", "pointsets.jl"]
    atria_specific = filter(h ->
        contains(h.file, "ATRIANeighbors") ||
        any(contains(h.file, f) for f in atria_files),
        hotspots
    )

    # Categorize hotspots
    categorized = categorize_hotspots(atria_specific)

    return RuntimeProfile(total_samples, hotspots, atria_specific, categorized, now_string())
end

"""
    categorize_hotspots(hotspots::Vector{HotspotEntry}) -> Dict

Categorize hotspots by type of operation.
"""
function categorize_hotspots(hotspots::Vector{HotspotEntry})
    categories = Dict{String, Vector{HotspotEntry}}(
        "distance_calculation" => HotspotEntry[],
        "heap_operations" => HotspotEntry[],
        "tree_construction" => HotspotEntry[],
        "search_operations" => HotspotEntry[],
        "point_access" => HotspotEntry[],
        "other" => HotspotEntry[]
    )

    for h in hotspots
        func_lower = lowercase(h.function_name)
        file_lower = lowercase(h.file)

        if contains(func_lower, "distance") || contains(func_lower, "metric") || contains(func_lower, "norm")
            push!(categories["distance_calculation"], h)
        elseif contains(func_lower, "heap") || contains(func_lower, "sortedneighbor") ||
               contains(func_lower, "insert") || contains(func_lower, "priority")
            push!(categories["heap_operations"], h)
        elseif contains(func_lower, "assign_points") || contains(func_lower, "partition") ||
               (contains(func_lower, "build") && contains(file_lower, "tree"))
            push!(categories["tree_construction"], h)
        elseif contains(func_lower, "knn") || contains(func_lower, "search") ||
               contains(func_lower, "range") || contains(func_lower, "count")
            push!(categories["search_operations"], h)
        elseif contains(func_lower, "getpoint")
            push!(categories["point_access"], h)
        else
            push!(categories["other"], h)
        end
    end

    return categories
end

# ============================================================================
# Allocation Profiling
# ============================================================================

"""
    profile_allocations(f::Function; warmup=true, sample_rate=0.1) -> AllocationProfile

Profile memory allocations in function f.
Lower sample_rate = faster but less accurate (0.1 = 10% of allocations sampled).
"""
function profile_allocations(f::Function; warmup=true, sample_rate=0.1)
    # Warmup
    if warmup
        f()
    end

    # Profile allocations
    Profile.Allocs.clear()
    Profile.Allocs.@profile sample_rate=sample_rate f()

    # Analyze
    return analyze_allocation_profile()
end

"""
    analyze_allocation_profile() -> AllocationProfile

Analyze allocation profile data.
"""
function analyze_allocation_profile()
    prof_result = Profile.Allocs.fetch()

    if isempty(prof_result.allocs)
        return AllocationProfile(0, 0, AllocationSite[], AllocationSite[], now_string())
    end

    # Aggregate by location
    alloc_counts = Dict{Tuple{String,String,Int}, Int}()
    alloc_bytes = Dict{Tuple{String,String,Int}, Int}()

    total_allocs = 0
    total_bytes = 0

    for alloc in prof_result.allocs
        total_allocs += 1
        total_bytes += alloc.size

        if !isempty(alloc.stacktrace)
            frame = alloc.stacktrace[1]
            func = String(frame.func)
            file = String(frame.file)
            line = frame.line

            # Skip low-level code
            if !startswith(file, "libc") && !startswith(func, "jl_")
                key = (func, file, line)
                alloc_counts[key] = get(alloc_counts, key, 0) + 1
                alloc_bytes[key] = get(alloc_bytes, key, 0) + alloc.size
            end
        end
    end

    # Create allocation sites
    alloc_sites = [
        AllocationSite(func, file, line, count, alloc_bytes[(func,file,line)],
                      alloc_bytes[(func,file,line)] / count)
        for ((func, file, line), count) in alloc_counts
    ]

    # Sort by total bytes
    sort!(alloc_sites, by=x->x.total_bytes, rev=true)

    # Filter ATRIA-specific
    atria_files = ["tree.jl", "search.jl", "structures.jl", "metrics.jl", "pointsets.jl"]
    atria_specific = filter(s ->
        contains(s.file, "ATRIANeighbors") ||
        any(contains(s.file, f) for f in atria_files),
        alloc_sites
    )

    return AllocationProfile(total_allocs, total_bytes, alloc_sites, atria_specific, now_string())
end

# ============================================================================
# Type Stability Analysis
# ============================================================================

"""
    check_type_stability(f::Function, types::Tuple) -> TypeStabilityReport

Check type stability of function f with given argument types.
Uses @code_warntype analysis.
"""
function check_type_stability(f::Function, types::Tuple)
    # Capture @code_warntype output
    io = IOBuffer()
    InteractiveUtils.code_warntype(io, f, types)
    output = String(take!(io))

    # Analyze for type instabilities
    instabilities = TypeInstability[]

    # Look for "Body::Any" or "Body::Union{...}"
    has_any = contains(output, "Body::Any")
    has_union = contains(output, r"Body::Union\{[^}]+\}")

    func_name = string(f)
    sig_str = "$(func_name)$(types)"

    if has_any
        push!(instabilities, TypeInstability(
            func_name,
            sig_str,
            ["Return type is Any (complete type instability)"],
            "Any",
            :high
        ))
    elseif has_union
        m = match(r"Body::(Union\{[^}]+\})", output)
        return_type = m !== nothing ? m.captures[1] : "Union{...}"
        push!(instabilities, TypeInstability(
            func_name,
            sig_str,
            ["Return type is a Union (partial type instability)"],
            return_type,
            :medium
        ))
    end

    # Look for dynamic dispatch indicators
    if contains(output, "invoke")
        push!(instabilities, TypeInstability(
            func_name,
            sig_str,
            ["Contains dynamic dispatch (invoke calls)"],
            "",
            :medium
        ))
    end

    is_stable = isempty(instabilities)

    # Generate recommendations
    recommendations = String[]
    if !is_stable
        for inst in instabilities
            if inst.severity == :high
                push!(recommendations, "🔴 CRITICAL: Add type annotations to ensure concrete return type")
                push!(recommendations, "   Use @code_warntype $(func_name)(args...) to see detailed type flow")
            elseif inst.severity == :medium
                push!(recommendations, "🟡 WARNING: Consider using type assertions or refactoring to avoid Union returns")
            end
        end
        push!(recommendations, "💡 TIP: Run Cthulhu.@descend $(func_name)(args...) for interactive type analysis")
    else
        push!(recommendations, "✅ Function is type-stable")
    end

    return TypeStabilityReport(func_name, is_stable, instabilities, recommendations, now_string())
end

# ============================================================================
# Convenience Macros
# ============================================================================

"""
    @profile_quick expression

Quick profiling with minimal overhead. Returns ProfileResult with runtime analysis.
"""
macro profile_quick(expr)
    quote
        # Warmup first
        $(esc(expr))

        # Clear and profile
        $Profile.clear()
        $Profile.init(n=10_000_000)
        $Profile.@profile $(esc(expr))

        # Analyze
        result = $ProfileTools.analyze_runtime_profile()
        recs = $ProfileTools.generate_runtime_recommendations(result)
        summary = $ProfileTools.generate_quick_summary(result)
        $ProfileTools.ProfileResult(result, nothing, nothing, recs, summary)
    end
end

"""
    @profile_deep expression

Deep profiling including runtime and allocations. Takes longer but more thorough.
"""
macro profile_deep(expr)
    quote
        # Warmup first
        $(esc(expr))

        # Runtime profile
        $Profile.clear()
        $Profile.init(n=10_000_000)
        $Profile.@profile $(esc(expr))
        runtime = $ProfileTools.analyze_runtime_profile()

        # Allocation profile
        $Profile.Allocs.clear()
        $Profile.Allocs.@profile sample_rate=0.1 $(esc(expr))
        allocs = $ProfileTools.analyze_allocation_profile()

        # Combine results
        recs = $ProfileTools.generate_comprehensive_recommendations(runtime, allocs)
        summary = $ProfileTools.generate_deep_summary(runtime, allocs)
        $ProfileTools.ProfileResult(runtime, allocs, nothing, recs, summary)
    end
end

"""
    @profile_allocs expression

Allocation-focused profiling. Higher sample rate for detailed allocation tracking.
"""
macro profile_allocs(expr)
    quote
        # Warmup first
        $(esc(expr))

        # Profile allocations
        $Profile.Allocs.clear()
        $Profile.Allocs.@profile sample_rate=1.0 $(esc(expr))
        allocs = $ProfileTools.analyze_allocation_profile()

        recs = $ProfileTools.generate_allocation_recommendations(allocs)
        summary = $ProfileTools.generate_alloc_summary(allocs)
        $ProfileTools.ProfileResult(nothing, allocs, nothing, recs, summary)
    end
end

# ============================================================================
# Report Generation
# ============================================================================

"""
    print_report(result::ProfileResult)

Print a concise, LLM-friendly report to stdout.
"""
function print_report(result::ProfileResult)
    println("="^80)
    println("PROFILING REPORT")
    println("="^80)
    println()

    # Summary
    println("SUMMARY")
    println("-"^80)
    println(result.summary)
    println()

    # Runtime Profile
    if result.runtime !== nothing
        print_runtime_report(result.runtime)
    end

    # Allocation Profile
    if result.allocations !== nothing
        print_allocation_report(result.allocations)
    end

    # Type Stability
    if result.type_stability !== nothing
        print_type_stability_report(result.type_stability)
    end

    # Recommendations
    if !isempty(result.recommendations)
        println("="^80)
        println("RECOMMENDATIONS")
        println("="^80)
        println()
        for (i, rec) in enumerate(result.recommendations)
            println("$i. $rec")
        end
        println()
    end

    println("="^80)
end

"""
    print_runtime_report(profile::RuntimeProfile)

Print runtime profiling section.
"""
function print_runtime_report(profile::RuntimeProfile)
    println("="^80)
    println("RUNTIME PROFILE")
    println("="^80)
    println()
    println("Total samples: $(profile.total_samples)")
    println()

    # ATRIA-specific hotspots
    if !isempty(profile.atria_specific)
        atria_samples = sum(h.samples for h in profile.atria_specific)
        atria_pct = 100.0 * atria_samples / profile.total_samples

        println("ATRIA Package: $atria_samples samples ($(round(atria_pct, digits=1))%)")
        println()

        # Show by category
        for (category, hotspots) in sort(collect(profile.categorized),
                                         by=x->isempty(x[2]) ? 0 : sum(h.samples for h in x[2]),
                                         rev=true)
            if !isempty(hotspots)
                cat_samples = sum(h.samples for h in hotspots)
                cat_pct = 100.0 * cat_samples / profile.total_samples

                cat_name = replace(category, "_" => " ") |> titlecase
                println("  $cat_name: $cat_samples samples ($(round(cat_pct, digits=1))%)")

                # Show top 3 hotspots in this category
                for h in hotspots[1:min(3, length(hotspots))]
                    file_short = basename(h.file)
                    println("    • $(h.function_name) @ $file_short:$(h.line) - $(h.samples) samples")
                end
                println()
            end
        end
    else
        println("No ATRIA-specific code found in profile (may be too fast or dominated by Julia internals)")
        println()
    end

    # Top overall hotspots
    println("Top 10 Overall Hotspots:")
    println(@sprintf("%-5s %-8s %-8s %-40s %s", "Rank", "Samples", "% Time", "Function", "Location"))
    println("-"^80)
    for (i, h) in enumerate(profile.hotspots[1:min(10, length(profile.hotspots))])
        file_short = basename(h.file)
        func_short = length(h.function_name) > 40 ? h.function_name[1:37] * "..." : h.function_name
        println(@sprintf("%-5d %-8d %-8.2f %-40s %s:%d",
                        i, h.samples, h.percentage, func_short, file_short, h.line))
    end
    println()
end

"""
    print_allocation_report(profile::AllocationProfile)

Print allocation profiling section.
"""
function print_allocation_report(profile::AllocationProfile)
    println("="^80)
    println("ALLOCATION PROFILE")
    println("="^80)
    println()
    println("Total allocations: $(profile.total_allocations)")
    println("Total bytes: $(format_bytes(profile.total_bytes))")
    println()

    # ATRIA-specific allocations
    if !isempty(profile.atria_specific)
        atria_bytes = sum(s.total_bytes for s in profile.atria_specific)
        atria_pct = 100.0 * atria_bytes / profile.total_bytes

        println("ATRIA Package: $(format_bytes(atria_bytes)) ($(round(atria_pct, digits=1))%)")
        println()

        println("Top 10 ATRIA Allocation Sites:")
        println(@sprintf("%-5s %-10s %-10s %-8s %-30s %s",
                        "Rank", "Count", "Bytes", "Avg", "Function", "Location"))
        println("-"^80)
        for (i, s) in enumerate(profile.atria_specific[1:min(10, length(profile.atria_specific))])
            file_short = basename(s.file)
            func_short = length(s.function_name) > 30 ? s.function_name[1:27] * "..." : s.function_name
            println(@sprintf("%-5d %-10d %-10s %-8s %-30s %s:%d",
                            i, s.count, format_bytes(s.total_bytes),
                            format_bytes(Int(round(s.avg_bytes))),
                            func_short, file_short, s.line))
        end
    else
        println("No ATRIA-specific allocations detected (good!)")
    end
    println()
end

"""
    print_type_stability_report(report::TypeStabilityReport)

Print type stability analysis section.
"""
function print_type_stability_report(report::TypeStabilityReport)
    println("="^80)
    println("TYPE STABILITY ANALYSIS")
    println("="^80)
    println()
    println("Function: $(report.function_name)")
    println("Status: $(report.is_stable ? "✅ STABLE" : "❌ UNSTABLE")")
    println()

    if !isempty(report.instabilities)
        println("Issues Found:")
        for inst in report.instabilities
            severity_str = inst.severity == :high ? "🔴 HIGH" :
                          inst.severity == :medium ? "🟡 MEDIUM" : "🟢 LOW"
            println("  $severity_str: $(inst.signature)")
            for var in inst.unstable_variables
                println("    - $var")
            end
        end
        println()
    end

    if !isempty(report.recommendations)
        println("Recommendations:")
        for rec in report.recommendations
            println("  $rec")
        end
    end
    println()
end

# ============================================================================
# Recommendation Generation
# ============================================================================

"""
    generate_runtime_recommendations(profile::RuntimeProfile) -> Vector{String}

Generate actionable recommendations based on runtime profile.
"""
function generate_runtime_recommendations(profile::RuntimeProfile)
    recommendations = String[]
    total = profile.total_samples

    for (category, hotspots) in profile.categorized
        if isempty(hotspots)
            continue
        end

        cat_samples = sum(h.samples for h in hotspots)
        cat_pct = cat_samples / total

        if category == "distance_calculation" && cat_pct > 0.15
            push!(recommendations, "Distance calculations are a hotspot ($(round(100*cat_pct, digits=1))%)")
            push!(recommendations, "  → Add @inbounds to array accesses in distance functions")
            push!(recommendations, "  → Use @simd for vectorization")
            push!(recommendations, "  → Optimize early termination logic")
        elseif category == "heap_operations" && cat_pct > 0.10
            push!(recommendations, "Heap operations are expensive ($(round(100*cat_pct, digits=1))%)")
            push!(recommendations, "  → Consider StaticArrays for small fixed k")
            push!(recommendations, "  → Reduce allocations in SortedNeighborTable")
        elseif category == "search_operations" && cat_pct > 0.20
            push!(recommendations, "Search operations dominate ($(round(100*cat_pct, digits=1))%)")
            push!(recommendations, "  → Profile priority queue implementation")
            push!(recommendations, "  → Use @inbounds for permutation table access")
        elseif category == "tree_construction" && cat_pct > 0.15
            push!(recommendations, "Tree construction is slow ($(round(100*cat_pct, digits=1))%)")
            push!(recommendations, "  → Optimize assign_points_to_centers! algorithm")
            push!(recommendations, "  → Pre-allocate temporary arrays")
        end
    end

    if isempty(recommendations)
        push!(recommendations, "No major hotspots detected. Code appears well-optimized.")
    end

    return recommendations
end

"""
    generate_allocation_recommendations(profile::AllocationProfile) -> Vector{String}

Generate recommendations based on allocation profile.
"""
function generate_allocation_recommendations(profile::AllocationProfile)
    recommendations = String[]

    if profile.total_bytes > 10_000_000  # 10 MB
        push!(recommendations, "High allocation volume: $(format_bytes(profile.total_bytes))")
        push!(recommendations, "  → Review top allocation sites for unnecessary temporaries")
    end

    # Check for many small allocations
    if !isempty(profile.allocation_sites)
        avg_bytes = mean(s.avg_bytes for s in profile.allocation_sites)
        if avg_bytes < 1000  # Less than 1 KB average
            push!(recommendations, "Many small allocations detected (avg $(format_bytes(Int(round(avg_bytes)))))")
            push!(recommendations, "  → Consider object pooling or pre-allocation")
        end
    end

    # Check ATRIA-specific allocations
    if !isempty(profile.atria_specific)
        atria_pct = 100.0 * sum(s.total_bytes for s in profile.atria_specific) / profile.total_bytes
        if atria_pct > 50
            push!(recommendations, "ATRIA code is responsible for $(round(atria_pct, digits=1))% of allocations")
            push!(recommendations, "  → Focus optimization on top ATRIA allocation sites")
        end
    end

    if isempty(recommendations)
        push!(recommendations, "Allocation profile looks reasonable")
    end

    return recommendations
end

"""
    generate_comprehensive_recommendations(runtime, allocs) -> Vector{String}

Generate comprehensive recommendations from both runtime and allocation profiles.
"""
function generate_comprehensive_recommendations(runtime::RuntimeProfile, allocs::AllocationProfile)
    recs = String[]
    append!(recs, generate_runtime_recommendations(runtime))
    append!(recs, generate_allocation_recommendations(allocs))
    return recs
end

# ============================================================================
# Summary Generation
# ============================================================================

"""
    generate_quick_summary(profile::RuntimeProfile) -> String

Generate a quick summary of runtime profile.
"""
function generate_quick_summary(profile::RuntimeProfile)
    if isempty(profile.atria_specific)
        return "Runtime profile collected ($(profile.total_samples) samples). No ATRIA hotspots detected."
    end

    atria_samples = sum(h.samples for h in profile.atria_specific)
    atria_pct = 100.0 * atria_samples / profile.total_samples

    # Find dominant category
    max_cat = ""
    max_samples = 0
    for (cat, hotspots) in profile.categorized
        if !isempty(hotspots)
            cat_samples = sum(h.samples for h in hotspots)
            if cat_samples > max_samples
                max_samples = cat_samples
                max_cat = cat
            end
        end
    end

    cat_name = replace(max_cat, "_" => " ")
    cat_pct = 100.0 * max_samples / profile.total_samples

    return """
    Runtime profile: $(profile.total_samples) samples collected
    ATRIA code: $(round(atria_pct, digits=1))% of runtime
    Primary bottleneck: $cat_name ($(round(cat_pct, digits=1))%)
    """
end

"""
    generate_alloc_summary(profile::AllocationProfile) -> String

Generate summary of allocation profile.
"""
function generate_alloc_summary(profile::AllocationProfile)
    atria_bytes = !isempty(profile.atria_specific) ?
                  sum(s.total_bytes for s in profile.atria_specific) : 0
    atria_pct = profile.total_bytes > 0 ?
                100.0 * atria_bytes / profile.total_bytes : 0.0

    return """
    Allocation profile: $(profile.total_allocations) allocations, $(format_bytes(profile.total_bytes))
    ATRIA code: $(format_bytes(atria_bytes)) ($(round(atria_pct, digits=1))%)
    """
end

"""
    generate_deep_summary(runtime, allocs) -> String

Generate comprehensive summary combining runtime and allocations.
"""
function generate_deep_summary(runtime::RuntimeProfile, allocs::AllocationProfile)
    return generate_quick_summary(runtime) * "\n" * generate_alloc_summary(allocs)
end

# ============================================================================
# Utilities
# ============================================================================

"""
    format_bytes(bytes::Int) -> String

Format byte count in human-readable form.
"""
function format_bytes(bytes::Int)
    if bytes < 1024
        return "$(bytes)B"
    elseif bytes < 1024^2
        return @sprintf("%.1fKB", bytes / 1024)
    elseif bytes < 1024^3
        return @sprintf("%.1fMB", bytes / 1024^2)
    else
        return @sprintf("%.1fGB", bytes / 1024^3)
    end
end

"""
    now_string() -> String

Get current timestamp as string.
"""
function now_string()
    return string(Dates.now())
end

"""
    titlecase(s::String) -> String

Convert string to title case.
"""
function titlecase(s::String)
    return join([uppercasefirst(word) for word in split(s)], " ")
end

end # module ProfileTools

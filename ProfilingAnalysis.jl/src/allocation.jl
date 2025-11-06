"""
allocation.jl

Allocation profiling support using Profile.Allocs.
"""

using Profile
using Dates
using Printf

"""
    AllocationSite

A single allocation site from profiling.
"""
struct AllocationSite
    func::String
    file::String
    line::Int
    count::Int          # Number of allocations
    total_bytes::Int    # Total bytes allocated
    avg_bytes::Float64  # Average bytes per allocation
end

"""
    AllocationProfile

Complete allocation profiling results.
"""
struct AllocationProfile
    timestamp::DateTime
    total_allocations::Int
    total_bytes::Int
    sites::Vector{AllocationSite}
    metadata::Dict{String, Any}
end

"""
    collect_allocation_profile(workload_fn::Function;
                               warmup=true,
                               sample_rate=0.1,
                               metadata=Dict{String,Any}())

Collect allocation profile data.

# Arguments
- `workload_fn`: Function to profile
- `warmup`: Whether to run warmup first (default: true)
- `sample_rate`: Sampling rate (0.1 = 10% of allocations, 1.0 = all)
- `metadata`: Optional metadata

# Returns
- `AllocationProfile`: Structured allocation data

# Example
```julia
allocs = collect_allocation_profile(sample_rate=0.1) do
    my_function()
end
```
"""
function collect_allocation_profile(workload_fn::Function;
                                   warmup=true,
                                   sample_rate=0.1,
                                   metadata=Dict{String,Any}())
    # Warmup
    if warmup
        println("Warming up (compilation)...")
        workload_fn()
    end

    # Profile allocations
    println("Profiling allocations (sample_rate=$sample_rate)...")
    Profile.Allocs.clear()
    Profile.Allocs.@profile sample_rate=sample_rate workload_fn()

    prof_result = Profile.Allocs.fetch()

    if isempty(prof_result.allocs)
        @warn "No allocations collected. Workload may be allocation-free or sample_rate too low."
        return AllocationProfile(now(), 0, 0, AllocationSite[], metadata)
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
    sites = [
        AllocationSite(func, file, line, count, alloc_bytes[(func,file,line)],
                      alloc_bytes[(func,file,line)] / count)
        for ((func, file, line), count) in alloc_counts
    ]

    # Sort by total bytes (descending)
    sort!(sites, by=s->s.total_bytes, rev=true)

    return AllocationProfile(now(), total_allocs, total_bytes, sites, metadata)
end

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
    print_allocation_table(sites::Vector{AllocationSite}; max_width=120)

Print allocation sites in formatted table.
"""
function print_allocation_table(sites::Vector{AllocationSite}; max_width=120)
    if isempty(sites)
        println("No allocation sites found.")
        return
    end

    println(@sprintf("%-5s %-10s %-12s %-10s %-s",
                    "Rank", "Count", "Total Bytes", "Avg Bytes", "Function @ File:Line"))
    println("-" ^ max_width)

    for (idx, site) in enumerate(sites)
        location = "$(site.func) @ $(site.file):$(site.line)"
        if length(location) > max_width - 45
            location = location[1:max_width-48] * "..."
        end

        println(@sprintf("%-5d %-10d %-12s %-10s %s",
                        idx, site.count,
                        format_bytes(site.total_bytes),
                        format_bytes(Int(round(site.avg_bytes))),
                        location))
    end
end

"""
    summarize_allocations(profile::AllocationProfile;
                         filter_fn=nothing,
                         top_n=20,
                         title="Allocation Summary")

Generate summary of allocation profile.
"""
function summarize_allocations(profile::AllocationProfile;
                               filter_fn=nothing,
                               top_n=20,
                               title="Allocation Summary")
    println("=" ^ 80)
    println(title)
    println("=" ^ 80)
    println("Timestamp: ", profile.timestamp)
    println("Total allocations: ", profile.total_allocations)
    println("Total bytes: ", format_bytes(profile.total_bytes))
    println("Unique sites: ", length(profile.sites))
    println()

    # Apply filter if provided
    sites = profile.sites
    if filter_fn !== nothing
        sites = filter(filter_fn, sites)
        filtered_bytes = sum(s.total_bytes for s in sites)
        pct_filtered = 100.0 * filtered_bytes / profile.total_bytes
        println("Filtered bytes: $(format_bytes(filtered_bytes)) ($(round(pct_filtered, digits=2))%)")
        println()
    end

    # Show top sites
    println("=" ^ 80)
    println("Top $top_n Allocation Sites")
    println("=" ^ 80)
    println()

    display_count = min(top_n, length(sites))
    print_allocation_table(sites[1:display_count])
    println()
end

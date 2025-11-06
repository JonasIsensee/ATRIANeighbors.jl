# Detailed allocation profiling for ATRIA search

using Profile
using BenchmarkTools

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using ATRIANeighbors

"""
Profile allocations in detail using @allocations and manual tracking.
"""
function profile_allocations()
    println("="^80)
    println("DETAILED ALLOCATION PROFILING")
    println("="^80)

    # Create small test dataset
    N, D = 1000, 20
    data = randn(N, D)

    println("\nDataset: N=$N, D=$D")

    # Build tree
    println("\nBuilding ATRIA tree...")
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

    # Profile single query in detail
    query_point = randn(D)
    k = 10

    println("\n" * "-"^80)
    println("SINGLE QUERY ALLOCATION ANALYSIS")
    println("-"^80)

    # Warm up
    for _ in 1:5
        ATRIANeighbors.knn(tree, query_point, k=k)
    end

    # Detailed allocation tracking
    println("\n@btime analysis:")
    @btime ATRIANeighbors.knn($tree, $query_point, k=$k)

    # Use @allocated to measure total allocations
    println("\n@allocated analysis:")
    bytes_allocated = @allocated ATRIANeighbors.knn(tree, query_point, k=k)
    println("Total bytes allocated: $bytes_allocated")

    # Profile with allocation tracking
    println("\nRunning allocation profile (this may take a moment)...")
    Profile.Allocs.clear()
    Profile.Allocs.@profile sample_rate=1.0 begin
        for _ in 1:100
            ATRIANeighbors.knn(tree, query_point, k=k)
        end
    end

    println("\nTop allocation sites:")
    prof_result = Profile.Allocs.fetch()

    # Get allocation summary
    alloc_counts = Dict{String, Int}()
    alloc_bytes = Dict{String, Int}()

    for alloc in prof_result.allocs
        # Get function name and file
        if !isempty(alloc.stacktrace)
            frame = alloc.stacktrace[1]
            key = "$(frame.func) @ $(basename(String(frame.file))):$(frame.line)"

            alloc_counts[key] = get(alloc_counts, key, 0) + 1
            alloc_bytes[key] = get(alloc_bytes, key, 0) + alloc.size
        end
    end

    # Sort by count and show top 20
    sorted_counts = sort(collect(alloc_counts), by=x->x[2], rev=true)

    println("\nTop 20 allocation sites by count:")
    println("Count | Bytes | Location")
    println("-"^80)
    for (i, (location, count)) in enumerate(sorted_counts[1:min(20, length(sorted_counts))])
        bytes = alloc_bytes[location]
        println("$count | $bytes | $location")
    end

    # Sort by bytes
    sorted_bytes = sort(collect(alloc_bytes), by=x->x[2], rev=true)

    println("\n\nTop 20 allocation sites by bytes:")
    println("Bytes | Count | Location")
    println("-"^80)
    for (i, (location, bytes)) in enumerate(sorted_bytes[1:min(20, length(sorted_bytes))])
        count = alloc_counts[location]
        println("$bytes | $count | $location")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    profile_allocations()
end

"""
collection.jl

Profile data collection and I/O operations.
"""

using Profile
using Dates
using JSON

"""
    collect_profile_data(workload_fn::Function; metadata=Dict{String,Any}())

Collect profile data by running the provided workload function.

# Arguments
- `workload_fn`: Function to profile (called twice: once for warmup, once for profiling)
- `metadata`: Optional metadata to store with the profile

# Returns
- `ProfileData`: Structured profile data
"""
function collect_profile_data(workload_fn::Function; metadata=Dict{String,Any}())
    # Clear previous profile data
    Profile.clear()

    # Warm up (compilation)
    println("Warming up (compilation)...")
    workload_fn()

    # Profile
    println("Profiling with sampling enabled...")
    Profile.clear()
    @profile workload_fn()

    # Extract data
    data = Profile.fetch()

    if isempty(data)
        @warn "No profile data collected. The workload may be too fast."
        return ProfileData(now(), 0, ProfileEntry[], metadata)
    end

    # Count samples per function
    function_counts = Dict{Tuple{String,String,Int}, Int}()

    for frame_idx in data
        if frame_idx > 0  # Valid frame
            try
                frames = Profile.lookup(frame_idx)
                if !isempty(frames)
                    func_info = frames[1]
                    func_name = String(func_info.func)
                    file = String(func_info.file)
                    line = func_info.line

                    # Skip invalid entries but keep all valid ones
                    if func_name != "unknown function"
                        key = (func_name, file, line)
                        function_counts[key] = get(function_counts, key, 0) + 1
                    end
                end
            catch
                # Skip invalid frames
                continue
            end
        end
    end

    # Convert to ProfileEntry array
    total_samples = length(data)
    entries = [
        ProfileEntry(func, file, line, count, 100.0 * count / total_samples)
        for ((func, file, line), count) in function_counts
    ]

    # Sort by sample count (descending)
    sort!(entries, by=e -> e.samples, rev=true)

    return ProfileData(now(), total_samples, entries, metadata)
end

"""
    save_profile(profile::ProfileData, filename::String)

Save profile data to JSON file.
"""
function save_profile(profile::ProfileData, filename::String)
    mkpath(dirname(filename))

    # Convert to JSON-friendly format
    data = Dict(
        "timestamp" => string(profile.timestamp),
        "total_samples" => profile.total_samples,
        "entries" => [
            Dict(
                "func" => e.func,
                "file" => e.file,
                "line" => e.line,
                "samples" => e.samples,
                "percentage" => e.percentage
            )
            for e in profile.entries
        ],
        "metadata" => profile.metadata
    )

    open(filename, "w") do io
        JSON.print(io, data, 4)  # 4-space indent for pretty printing
    end

    println("Profile data saved to: $filename")
    println("  Total samples: $(profile.total_samples)")
    println("  Unique locations: $(length(profile.entries))")
end

"""
    load_profile(filename::String) -> ProfileData

Load profile data from JSON file.
"""
function load_profile(filename::String)
    data = JSON.parse(read(filename, String))

    entries = [
        ProfileEntry(
            e["func"],
            e["file"],
            e["line"],
            e["samples"],
            e["percentage"]
        )
        for e in data["entries"]
    ]

    # Metadata is already a Dict{String,Any} from JSON.parse
    metadata = get(data, "metadata", Dict{String,Any}())

    return ProfileData(
        DateTime(data["timestamp"]),
        data["total_samples"],
        entries,
        metadata
    )
end

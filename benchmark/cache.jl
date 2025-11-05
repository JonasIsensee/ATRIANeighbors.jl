"""
    cache.jl

Result caching system for benchmarks to avoid re-running expensive computations.
Cached results are stored in benchmark/results/ directory using JLD2 format.

Cache invalidation occurs when:
- Package versions change
- Julia version changes
- Explicitly requested by user
"""

using JLD2
using Dates
using Pkg

"""
    CacheMetadata

Metadata stored with each cached result to track validity.
"""
struct CacheMetadata
    timestamp::DateTime
    julia_version::VersionNumber
    pkg_versions::Dict{String, String}
    hostname::String
    dataset_params::Dict{String, Any}
end

"""
    get_pkg_version(pkg_name::String) -> String

Get the current version of an installed package.
"""
function get_pkg_version(pkg_name::String)
    deps = Pkg.dependencies()
    for (uuid, dep) in deps
        if dep.name == pkg_name
            return string(dep.version)
        end
    end
    return "unknown"
end

"""
    generate_cache_key(algorithm::Symbol, dataset_type::Symbol, params::Dict) -> String

Generate a unique cache key for a benchmark configuration.
"""
function generate_cache_key(algorithm::Symbol, dataset_type::Symbol, params::Dict)
    # Sort params for consistent key generation
    sorted_keys = sort(collect(keys(params)))
    param_str = join(["$(k)=$(params[k])" for k in sorted_keys], "_")
    return "$(algorithm)_$(dataset_type)_$(param_str)"
end

"""
    get_cache_path(cache_key::String) -> String

Get the file path for a cached result.
"""
function get_cache_path(cache_key::String)
    cache_dir = joinpath(@__DIR__, "results")
    mkpath(cache_dir)
    return joinpath(cache_dir, "$(cache_key).jld2")
end

"""
    save_cached_result(cache_key::String, result::Any, dataset_params::Dict)

Save a benchmark result to cache with metadata.
"""
function save_cached_result(cache_key::String, result::Any, dataset_params::Dict)
    metadata = CacheMetadata(
        now(),
        VERSION,
        Dict(
            "ATRIANeighbors" => get_pkg_version("ATRIANeighbors"),
            "NearestNeighbors" => get_pkg_version("NearestNeighbors"),
            "BenchmarkTools" => get_pkg_version("BenchmarkTools")
        ),
        gethostname(),
        dataset_params
    )

    cache_path = get_cache_path(cache_key)
    jldsave(cache_path; result=result, metadata=metadata)
    @info "Cached result saved to $cache_path"
end

"""
    load_cached_result(cache_key::String) -> Union{Nothing, Tuple{Any, CacheMetadata}}

Load a cached benchmark result if it exists and is valid.
Returns (result, metadata) or nothing if cache miss or invalid.
"""
function load_cached_result(cache_key::String)
    cache_path = get_cache_path(cache_key)

    if !isfile(cache_path)
        @debug "Cache miss: $cache_key"
        return nothing
    end

    try
        data = load(cache_path)
        result = data["result"]
        metadata = data["metadata"]

        @info "Cache hit: $cache_key (cached on $(metadata.timestamp))"
        return (result, metadata)
    catch e
        @warn "Failed to load cache $cache_key: $e"
        return nothing
    end
end

"""
    is_cache_valid(metadata::CacheMetadata;
                   check_versions::Bool=true,
                   max_age_days::Union{Nothing, Int}=nothing) -> Bool

Check if cached result is still valid.
"""
function is_cache_valid(metadata::CacheMetadata;
                       check_versions::Bool=true,
                       max_age_days::Union{Nothing, Int}=nothing)
    # Check age
    if max_age_days !== nothing
        age_days = (now() - metadata.timestamp).value / (1000 * 60 * 60 * 24)
        if age_days > max_age_days
            @info "Cache invalid: too old ($(round(age_days, digits=1)) days)"
            return false
        end
    end

    # Check Julia version
    if check_versions && metadata.julia_version != VERSION
        @info "Cache invalid: Julia version mismatch (cached: $(metadata.julia_version), current: $VERSION)"
        return false
    end

    # Check package versions
    if check_versions
        current_versions = Dict(
            "ATRIANeighbors" => get_pkg_version("ATRIANeighbors"),
            "NearestNeighbors" => get_pkg_version("NearestNeighbors")
        )

        for (pkg, current_ver) in current_versions
            cached_ver = get(metadata.pkg_versions, pkg, "unknown")
            if cached_ver != current_ver
                @info "Cache invalid: $pkg version mismatch (cached: $cached_ver, current: $current_ver)"
                return false
            end
        end
    end

    return true
end

"""
    clear_cache(; pattern::Union{Nothing, String}=nothing)

Clear cached results. If pattern is provided, only clear matching cache files.
"""
function clear_cache(; pattern::Union{Nothing, String}=nothing)
    cache_dir = joinpath(@__DIR__, "results")
    if !isdir(cache_dir)
        @info "No cache directory to clear"
        return
    end

    files = readdir(cache_dir)
    cleared = 0

    for file in files
        if endswith(file, ".jld2")
            if pattern === nothing || occursin(pattern, file)
                rm(joinpath(cache_dir, file))
                cleared += 1
            end
        end
    end

    @info "Cleared $cleared cache file(s)"
end

"""
    list_cache()

List all cached benchmark results with their metadata.
"""
function list_cache()
    cache_dir = joinpath(@__DIR__, "results")
    if !isdir(cache_dir)
        println("No cache directory found")
        return
    end

    files = readdir(cache_dir)
    cache_files = filter(f -> endswith(f, ".jld2"), files)

    if isempty(cache_files)
        println("No cached results found")
        return
    end

    println("Cached benchmark results:")
    println("=" ^ 80)

    for file in sort(cache_files)
        try
            data = load(joinpath(cache_dir, file))
            metadata = data["metadata"]

            println("\nFile: $file")
            println("  Timestamp: $(metadata.timestamp)")
            println("  Julia: $(metadata.julia_version)")
            println("  Host: $(metadata.hostname)")
            println("  Packages:")
            for (pkg, ver) in sort(collect(metadata.pkg_versions))
                println("    $pkg: $ver")
            end
            println("  Dataset params:")
            for (k, v) in sort(collect(metadata.dataset_params))
                println("    $k: $v")
            end
        catch e
            println("\nFile: $file")
            println("  ERROR: Failed to load metadata: $e")
        end
    end
    println("\n" * "=" ^ 80)
end

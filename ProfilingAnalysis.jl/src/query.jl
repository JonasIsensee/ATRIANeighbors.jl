"""
query.jl

Query functions for filtering and analyzing profile data.
"""

"""
    query_top_n(profile::ProfileData, n::Int; filter_fn=nothing) -> Vector{ProfileEntry}

Get top N hotspots.

# Arguments
- `profile`: Profile data to query
- `n`: Number of top entries to return
- `filter_fn`: Optional function to filter entries (e.g., `e -> !is_system_code(e)`)

# Returns
- Vector of top N ProfileEntry objects
"""
function query_top_n(profile::ProfileData, n::Int; filter_fn=nothing)
    entries = profile.entries

    if filter_fn !== nothing
        entries = filter(filter_fn, entries)
    end

    return entries[1:min(n, length(entries))]
end

"""
    query_by_file(profile::ProfileData, file_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a file pattern.
"""
function query_by_file(profile::ProfileData, file_pattern::String)
    return filter(e -> contains(e.file, file_pattern), profile.entries)
end

"""
    query_by_function(profile::ProfileData, func_pattern::String) -> Vector{ProfileEntry}

Get all entries matching a function name pattern.
"""
function query_by_function(profile::ProfileData, func_pattern::String)
    return filter(e -> contains(e.func, func_pattern), profile.entries)
end

"""
    query_by_pattern(profile::ProfileData, pattern::String) -> Vector{ProfileEntry}

Get all entries where function OR file matches pattern.
"""
function query_by_pattern(profile::ProfileData, pattern::String)
    return filter(e -> contains(e.func, pattern) || contains(e.file, pattern), profile.entries)
end

"""
    query_by_filter(profile::ProfileData, filter_fn::Function) -> Vector{ProfileEntry}

Get all entries matching a custom filter function.

# Example
```julia
# Find all entries with more than 100 samples
results = query_by_filter(profile, e -> e.samples > 100)
```
"""
function query_by_filter(profile::ProfileData, filter_fn::Function)
    return filter(filter_fn, profile.entries)
end

"""
    is_system_code(entry::ProfileEntry;
                   system_patterns=["libc", "libopenlibm", "jl_", "julia-release",
                                   "/Base.jl", "/client.jl", "/loading.jl", "/boot.jl",
                                   "/cache/build/", "/workspace/srcdir/", "glibc"]) -> Bool

Check if entry is from system/base Julia code.

You can provide custom system patterns to filter different types of code.
"""
function is_system_code(entry::ProfileEntry;
                        system_patterns=["libc", "libopenlibm", "jl_", "julia-release",
                                        "/Base.jl", "/client.jl", "/loading.jl", "/boot.jl",
                                        "/cache/build/", "/workspace/srcdir/", "glibc"])
    return any(contains(entry.file, p) || contains(entry.func, p) for p in system_patterns)
end

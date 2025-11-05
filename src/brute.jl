# Brute force nearest neighbor search for validation purposes

"""
    brute_knn(ps::AbstractPointSet, query_point, k::Int; exclude_self::Bool=false)

Perform brute force k-nearest neighbor search.

# Arguments
- `ps::AbstractPointSet`: The point set to search in
- `query_point`: The query point (vector or point index if exclude_self=true)
- `k::Int`: Number of nearest neighbors to find
- `exclude_self::Bool`: If true, exclude the query point itself from results (for leave-one-out)

# Returns
- Vector of `Neighbor` objects sorted by distance (closest first)
"""
function brute_knn(ps::AbstractPointSet, query_point, k::Int; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    # Create a sorted neighbor table
    table = SortedNeighborTable(k)

    # Test all points
    for i in 1:N
        # Skip self if requested
        if exclude_self && i == query_idx
            continue
        end

        d = distance(ps, i, query_point)
        insert!(table, Neighbor(i, d))
    end

    return finish_search(table)
end

"""
    brute_knn_batch(ps::AbstractPointSet, query_points::AbstractMatrix, k::Int)

Perform brute force k-nearest neighbor search for multiple query points.

# Arguments
- `ps::AbstractPointSet`: The point set to search in
- `query_points::AbstractMatrix`: Matrix where each row is a query point
- `k::Int`: Number of nearest neighbors to find

# Returns
- Vector of vectors, where result[i] contains the k nearest neighbors for query_points[i,:]
"""
function brute_knn_batch(ps::AbstractPointSet, query_points::AbstractMatrix, k::Int)
    n_queries = size(query_points, 1)
    results = Vector{Vector{Neighbor}}(undef, n_queries)

    for i in 1:n_queries
        query_point = query_points[i, :]
        results[i] = brute_knn(ps, query_point, k)
    end

    return results
end

"""
    brute_range_search(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)

Perform brute force range search (find all neighbors within distance `radius`).

# Arguments
- `ps::AbstractPointSet`: The point set to search in
- `query_point`: The query point
- `radius::Float64`: Search radius
- `exclude_self::Bool`: If true, exclude the query point itself from results

# Returns
- Vector of `Neighbor` objects within the radius, sorted by distance
"""
function brute_range_search(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    # Collect all neighbors within radius
    neighbors = Neighbor[]

    for i in 1:N
        # Skip self if requested
        if exclude_self && i == query_idx
            continue
        end

        d = distance(ps, i, query_point)
        if d <= radius
            push!(neighbors, Neighbor(i, d))
        end
    end

    # Sort by distance
    sort!(neighbors, by=n->n.distance)

    return neighbors
end

"""
    brute_count_range(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)

Count how many neighbors are within distance `radius` (brute force).

# Arguments
- `ps::AbstractPointSet`: The point set to search in
- `query_point`: The query point
- `radius::Float64`: Search radius
- `exclude_self::Bool`: If true, exclude the query point itself from count

# Returns
- Integer count of neighbors within radius
"""
function brute_count_range(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    count = 0

    for i in 1:N
        # Skip self if requested
        if exclude_self && i == query_idx
            continue
        end

        d = distance(ps, i, query_point)
        if d <= radius
            count += 1
        end
    end

    return count
end

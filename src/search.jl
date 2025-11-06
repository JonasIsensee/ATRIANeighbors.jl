# Legacy ATRIA search implementation (not optimized)
# Kept for reference and backward compatibility testing
# Use the optimized version in search_optimized.jl instead

"""
    knn_legacy(tree::ATRIATree, query_point; k::Int=1, epsilon::Float64=0.0, exclude_range::Tuple{Int,Int}=(-1,-1), track_stats::Bool=false)

Legacy k-NN search implementation (not allocation-optimized).
For production use, prefer the optimized version in search_optimized.jl.

# Arguments
- `tree::ATRIATree`: The ATRIA tree to search
- `query_point`: The query point (vector or point from point set)
- `k::Int`: Number of nearest neighbors to find (default: 1)
- `epsilon::Float64`: Approximation parameter (0.0 = exact search, >0.0 = approximate)
- `exclude_range::Tuple{Int,Int}`: Exclude points in range [first, last] from results (for leave-one-out)
- `track_stats::Bool`: If true, return (neighbors, stats) with distance calculation counts

# Returns
- If `track_stats=false`: Vector of `Neighbor` objects sorted by distance (closest first)
- If `track_stats=true`: Tuple of (neighbors, stats) where stats is a NamedTuple with:
  - `distance_calcs::Int`: Number of distance calculations performed
  - `f_k::Float64`: Fraction of distance calculations (distance_calcs / N)
"""
function knn_legacy(tree::ATRIATree, query_point; k::Int=1, epsilon::Float64=0.0, exclude_range::Tuple{Int,Int}=(-1,-1), track_stats::Bool=false)
    # Initialize sorted neighbor table
    table = SortedNeighborTable(k)
    init_search!(table, k)

    # Perform the search
    distance_calcs = _search_knn_legacy!(tree, query_point, table, epsilon, exclude_range)

    # Return sorted results
    neighbors = finish_search(table)

    if track_stats
        N, _ = size(tree.points)
        f_k = distance_calcs / N
        stats = (distance_calcs=distance_calcs, f_k=f_k)
        return (neighbors, stats)
    else
        return neighbors
    end
end

"""
    _search_knn_legacy!(tree::ATRIATree, query_point, table::SortedNeighborTable, epsilon::Float64, exclude_range::Tuple{Int,Int})

Legacy internal search implementation using SortedNeighborTable.

Returns the number of distance calculations performed.
"""
function _search_knn_legacy!(tree::ATRIATree, query_point, table::SortedNeighborTable, epsilon::Float64, exclude_range::Tuple{Int,Int})
    first, last = exclude_range

    # Create MinHeap for best-first search (min-heap by d_min)
    pq = MinHeap{SearchItem}()

    # Track distance calculations
    distance_calcs = 0

    # Calculate distance to root center
    root_dist = distance(tree.points, tree.root.center, query_point)
    distance_calcs += 1

    # Push root onto queue
    root_si = SearchItem(tree.root, root_dist)
    push!(pq, root_si)

    while !isempty(pq)
        si = popfirst!(pq)
        c = si.cluster

        # Test cluster center if not excluded
        if (c.center < first || c.center > last) && table.high_dist > si.dist
            insert!(table, Neighbor(c.center, si.dist))
        end

        # Check if we need to explore this cluster further
        # Use epsilon for approximate queries
        if table.high_dist >= si.d_min * (1.0 + epsilon)
            if is_terminal(c)
                # Terminal node: test points using permutation table
                distance_calcs += _search_terminal_node!(tree, c, si, query_point, table, first, last)
            else
                # Internal node: push children onto queue
                distance_calcs += _push_child_clusters!(tree, c, si, query_point, pq)
            end
        end
    end

    return distance_calcs
end

"""
    _search_terminal_node!(tree, cluster, si, query_point, table, first, last)

Search within a terminal cluster node.

Returns the number of distance calculations performed.
"""
@inline function _search_terminal_node!(tree::ATRIATree, c::Cluster, si::SearchItem, query_point, table::SortedNeighborTable, first::Int, last::Int)
    section_start = c.start
    section_end = c.start + c.length - 1
    distance_calcs = 0

    # Get cluster radius (note: Rmax is negative for terminal nodes)
    Rmax = abs(c.Rmax)

    if Rmax == 0.0
        # Special case: all points at same location as center
        # Distances are pre-computed in permutation table
        # No additional distance calculations needed
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            # Early termination if we can't improve
            if table.high_dist <= si.dist
                break
            end

            if j < first || j > last
                insert!(table, Neighbor(j, si.dist))
            end
        end
    else
        # General case: use triangle inequality with precomputed distances
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if j < first || j > last
                # Triangle inequality pruning
                lower_bound = abs(si.dist - neighbor.distance)
                if table.high_dist > lower_bound
                    # Actually compute distance
                    d = distance(tree.points, j, query_point)
                    distance_calcs += 1
                    insert!(table, Neighbor(j, d))
                end
            end
        end
    end

    return distance_calcs
end

"""
    _push_child_clusters!(tree, cluster, parent_si, query_point, pq)

Push child clusters onto MinHeap for k-NN search.

Returns the number of distance calculations performed (always 2 - one per child).
"""
@inline function _push_child_clusters!(tree::ATRIATree, c::Cluster, parent_si::SearchItem, query_point, pq::MinHeap{SearchItem})
    # Compute distances to child centers
    d_left = distance(tree.points, c.left.center, query_point)
    d_right = distance(tree.points, c.right.center, query_point)

    # Create search items for children (pass parent to accumulate bounds)
    si_left = SearchItem(c.left, d_left, d_right, parent_si)
    si_right = SearchItem(c.right, d_right, d_left, parent_si)

    # Push onto MinHeap (will be ordered by d_min)
    push!(pq, si_left)
    push!(pq, si_right)

    return 2  # Two distance calculations
end

"""
    range_search(tree::ATRIATree, query_point, radius::Float64; exclude_range::Tuple{Int,Int}=(-1,-1))

Search for all neighbors within distance `radius` using the ATRIA tree.

# Arguments
- `tree::ATRIATree`: The ATRIA tree to search
- `query_point`: The query point
- `radius::Float64`: Search radius
- `exclude_range::Tuple{Int,Int}`: Exclude points in range [first, last] from results

# Returns
- Vector of `Neighbor` objects within radius (unsorted)
"""
function range_search(tree::ATRIATree, query_point, radius::Float64; exclude_range::Tuple{Int,Int}=(-1,-1))
    first, last = exclude_range
    results = Neighbor[]

    # Use stack for depth-first search
    stack = SearchItem[]

    # Calculate distance to root center and push onto stack
    root_dist = distance(tree.points, tree.root.center, query_point)
    push!(stack, SearchItem(tree.root, root_dist))

    while !isempty(stack)
        si = pop!(stack)
        c = si.cluster

        # Only explore if cluster could contain points within radius
        if radius >= si.d_min
            # Test cluster center if within radius and not excluded
            if (c.center < first || c.center > last) && si.dist <= radius
                push!(results, Neighbor(c.center, si.dist))
            end

            if is_terminal(c)
                # Terminal node: test points
                _range_search_terminal_node!(tree, c, si, query_point, radius, first, last, results)
            else
                # Internal node: push children onto stack
                _push_child_clusters_stack!(tree, c, si, query_point, stack)
            end
        end
    end

    return results
end

"""
    _range_search_terminal_node!(tree, cluster, si, query_point, radius, first, last, results)

Range search within a terminal cluster node.
"""
@inline function _range_search_terminal_node!(tree::ATRIATree, c::Cluster, si::SearchItem, query_point, radius::Float64, first::Int, last::Int, results::Vector{Neighbor})
    section_start = c.start
    section_end = c.start + c.length - 1

    # Get cluster radius
    Rmax = abs(c.Rmax)

    if Rmax == 0.0
        # Special case: all points at same location as center
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if (j < first || j > last) && si.dist <= radius
                push!(results, Neighbor(j, si.dist))
            end
        end
    else
        # General case: use triangle inequality
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if j < first || j > last
                # Triangle inequality pruning
                lower_bound = abs(si.dist - neighbor.distance)
                if radius >= lower_bound
                    # Actually compute distance
                    d = distance(tree.points, j, query_point)
                    if d <= radius
                        push!(results, Neighbor(j, d))
                    end
                end
            end
        end
    end
end

"""
    _push_child_clusters_stack!(tree, cluster, parent_si, query_point, stack)

Push child clusters onto stack for range search.
"""
@inline function _push_child_clusters_stack!(tree::ATRIATree, c::Cluster, parent_si::SearchItem, query_point, stack::Vector{SearchItem})
    # Compute distances to child centers
    d_left = distance(tree.points, c.left.center, query_point)
    d_right = distance(tree.points, c.right.center, query_point)

    # Create search items for children (pass parent to accumulate bounds)
    si_left = SearchItem(c.left, d_left, d_right, parent_si)
    si_right = SearchItem(c.right, d_right, d_left, parent_si)

    # Push onto stack
    push!(stack, si_left)
    push!(stack, si_right)
end

"""
    count_range(tree::ATRIATree, query_point, radius::Float64; exclude_range::Tuple{Int,Int}=(-1,-1))

Count how many neighbors are within distance `radius` (correlation sum).

# Arguments
- `tree::ATRIATree`: The ATRIA tree to search
- `query_point`: The query point
- `radius::Float64`: Search radius
- `exclude_range::Tuple{Int,Int}`: Exclude points in range [first, last] from count

# Returns
- Integer count of neighbors within radius
"""
function count_range(tree::ATRIATree, query_point, radius::Float64; exclude_range::Tuple{Int,Int}=(-1,-1))
    first, last = exclude_range
    count = 0

    # Use stack for depth-first search
    stack = SearchItem[]

    # Calculate distance to root center and push onto stack
    root_dist = distance(tree.points, tree.root.center, query_point)
    push!(stack, SearchItem(tree.root, root_dist))

    while !isempty(stack)
        si = pop!(stack)
        c = si.cluster

        # Only explore if cluster could contain points within radius
        if radius >= si.d_min
            # Test cluster center if within radius and not excluded
            if (c.center < first || c.center > last) && si.dist <= radius
                count += 1
            end

            if is_terminal(c)
                # Terminal node: count points
                count += _count_terminal_node!(tree, c, si, query_point, radius, first, last)
            else
                # Internal node: push children onto stack
                _push_child_clusters_stack!(tree, c, si, query_point, stack)
            end
        end
    end

    return count
end

"""
    _count_terminal_node!(tree, cluster, si, query_point, radius, first, last)

Count points within radius in a terminal cluster node.
"""
@inline function _count_terminal_node!(tree::ATRIATree, c::Cluster, si::SearchItem, query_point, radius::Float64, first::Int, last::Int)
    count = 0
    section_start = c.start
    section_end = c.start + c.length - 1

    # Get cluster radius
    Rmax = abs(c.Rmax)

    if Rmax == 0.0
        # Special case: all points at same location as center
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if (j < first || j > last) && si.dist <= radius
                count += 1
            end
        end
    else
        # General case: use triangle inequality
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if j < first || j > last
                # Triangle inequality pruning
                lower_bound = abs(si.dist - neighbor.distance)
                if radius >= lower_bound
                    # Actually compute distance
                    d = distance(tree.points, j, query_point)
                    if d <= radius
                        count += 1
                    end
                end
            end
        end
    end

    return count
end

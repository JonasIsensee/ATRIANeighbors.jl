# ATRIA range search and count range algorithms
# (k-NN search is in search_optimized.jl)

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

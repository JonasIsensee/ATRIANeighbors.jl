# Allocation-optimized ATRIA search implementation

"""
    MutableSearchItem

Mutable version of SearchItem for object pooling.
"""
mutable struct MutableSearchItem
    cluster::Cluster
    dist::Float64
    dist_brother::Float64
    d_min::Float64
    d_max::Float64

    MutableSearchItem() = new()
end

# Priority queue ordering
Base.isless(a::MutableSearchItem, b::MutableSearchItem) = a.d_min < b.d_min

"""
Initialize MutableSearchItem for root.
"""
@inline function init_root!(item::MutableSearchItem, cluster::Cluster, dist::Float64)
    Rmax = abs(cluster.Rmax)
    item.cluster = cluster
    item.dist = dist
    item.dist_brother = 0.0
    item.d_min = max(0.0, dist - Rmax)
    item.d_max = dist + Rmax
    return item
end

"""
Initialize MutableSearchItem for child.
"""
@inline function init_child!(item::MutableSearchItem, cluster::Cluster,
                             dist::Float64, dist_brother::Float64,
                             parent::MutableSearchItem)
    Rmax = abs(cluster.Rmax)
    g_min = cluster.g_min

    d_min_local = max(0.0, 0.5 * (dist - dist_brother + g_min))
    d_min = max(d_min_local, max(dist - Rmax, parent.d_min))
    d_max = min(parent.d_max, dist + Rmax)

    item.cluster = cluster
    item.dist = dist
    item.dist_brother = dist_brother
    item.d_min = d_min
    item.d_max = d_max

    return item
end

"""
    SearchItemPool

Object pool for MutableSearchItems to avoid allocations.
"""
mutable struct SearchItemPool
    items::Vector{MutableSearchItem}
    next_free::Int

    function SearchItemPool(capacity::Int)
        items = [MutableSearchItem() for _ in 1:capacity]
        new(items, 1)
    end
end

@inline function reset_pool!(pool::SearchItemPool)
    pool.next_free = 1
end

@inline function allocate_item!(pool::SearchItemPool)
    if pool.next_free > length(pool.items)
        error("SearchItem pool exhausted")
    end
    item = pool.items[pool.next_free]
    pool.next_free += 1
    return item
end

"""
    PreAllocatedPriorityQueue{T}

Pre-allocated priority queue that avoids allocations during search.
Uses a fixed-size array and maintains heap invariant manually.
"""
mutable struct PreAllocatedPriorityQueue{T}
    items::Vector{T}
    size::Int
    capacity::Int

    function PreAllocatedPriorityQueue{T}(capacity::Int) where T
        items = Vector{T}(undef, capacity)
        new{T}(items, 0, capacity)
    end
end

@inline function Base.isempty(pq::PreAllocatedPriorityQueue)
    return pq.size == 0
end

@inline function Base.push!(pq::PreAllocatedPriorityQueue{T}, item::T) where T
    if pq.size >= pq.capacity
        error("Priority queue capacity exceeded")
    end

    pq.size += 1
    pq.items[pq.size] = item

    # Bubble up
    idx = pq.size
    @inbounds while idx > 1
        parent = idx ÷ 2
        if pq.items[idx] < pq.items[parent]
            pq.items[idx], pq.items[parent] = pq.items[parent], pq.items[idx]
            idx = parent
        else
            break
        end
    end

    return pq
end

@inline function Base.popfirst!(pq::PreAllocatedPriorityQueue)
    if pq.size == 0
        error("Priority queue is empty")
    end

    result = pq.items[1]
    pq.items[1] = pq.items[pq.size]
    pq.size -= 1

    # Bubble down
    idx = 1
    @inbounds while true
        left = 2 * idx
        right = 2 * idx + 1
        smallest = idx

        if left <= pq.size && pq.items[left] < pq.items[smallest]
            smallest = left
        end

        if right <= pq.size && pq.items[right] < pq.items[smallest]
            smallest = right
        end

        if smallest != idx
            pq.items[idx], pq.items[smallest] = pq.items[smallest], pq.items[idx]
            idx = smallest
        else
            break
        end
    end

    return result
end

"""
    SearchContext

Pre-allocated context for search operations to avoid allocations.
"""
mutable struct SearchContext
    # Object pool for SearchItems
    pool::SearchItemPool

    # Priority queue for search items
    pq::PreAllocatedPriorityQueue{MutableSearchItem}

    # Neighbor table (pre-allocated)
    neighbors::Vector{Neighbor}
    neighbor_count::Int
    k::Int
    high_dist::Float64

    # Statistics
    distance_calcs::Int

    function SearchContext(max_pq_size::Int=1000, max_k::Int=100)
        pool = SearchItemPool(max_pq_size)
        pq = PreAllocatedPriorityQueue{MutableSearchItem}(max_pq_size)
        neighbors = Vector{Neighbor}(undef, max_k)
        new(pool, pq, neighbors, 0, 0, Inf, 0)
    end
end

"""
    SearchContext(tree::ATRIATree, k::Int)

Create a SearchContext sized appropriately for the given tree.
Automatically determines the priority queue size based on tree structure.
"""
function SearchContext(tree::ATRIATree, k::Int)
    return SearchContext(tree.total_clusters * 2, k)
end

"""
Reset search context for a new query.
"""
@inline function reset!(ctx::SearchContext, k::Int)
    reset_pool!(ctx.pool)
    ctx.pq.size = 0
    ctx.neighbor_count = 0
    ctx.k = k
    ctx.high_dist = Inf
    ctx.distance_calcs = 0
    return ctx
end

"""
Insert a neighbor into the pre-allocated table.
"""
@inline function insert_neighbor!(ctx::SearchContext, neighbor::Neighbor)
    if ctx.neighbor_count < ctx.k
        # Still have room
        ctx.neighbor_count += 1
        ctx.neighbors[ctx.neighbor_count] = neighbor

        # Heapify up (max heap)
        idx = ctx.neighbor_count
        @inbounds while idx > 1
            parent = idx ÷ 2
            if ctx.neighbors[idx].distance > ctx.neighbors[parent].distance
                ctx.neighbors[idx], ctx.neighbors[parent] = ctx.neighbors[parent], ctx.neighbors[idx]
                idx = parent
            else
                break
            end
        end

        # Update high_dist if we now have k neighbors
        if ctx.neighbor_count == ctx.k
            ctx.high_dist = ctx.neighbors[1].distance
        end
    elseif neighbor.distance < ctx.high_dist
        # Replace the farthest neighbor
        ctx.neighbors[1] = neighbor

        # Heapify down
        idx = 1
        @inbounds while true
            left = 2 * idx
            right = 2 * idx + 1
            largest = idx

            if left <= ctx.neighbor_count && ctx.neighbors[left].distance > ctx.neighbors[largest].distance
                largest = left
            end

            if right <= ctx.neighbor_count && ctx.neighbors[right].distance > ctx.neighbors[largest].distance
                largest = right
            end

            if largest != idx
                ctx.neighbors[idx], ctx.neighbors[largest] = ctx.neighbors[largest], ctx.neighbors[idx]
                idx = largest
            else
                break
            end
        end

        ctx.high_dist = ctx.neighbors[1].distance
    end
end

"""
Extract final sorted neighbors (allocates one array for results).
"""
function extract_neighbors(ctx::SearchContext)
    # Create result array (this allocation is necessary for return value)
    result = Vector{Neighbor}(undef, ctx.neighbor_count)
    @inbounds for i in 1:ctx.neighbor_count
        result[i] = ctx.neighbors[i]
    end

    # Sort by distance
    sort!(result, by=n->n.distance)
    return result
end

"""
    knn(tree::ATRIATree, query_point; k::Int=1, epsilon::Float64=0.0,
        exclude_range::Tuple{Int,Int}=(-1,-1), track_stats::Bool=false,
        ctx::Union{Nothing,SearchContext}=nothing)

Search for k nearest neighbors using the ATRIA tree.

# Arguments
- `tree::ATRIATree`: The ATRIA tree to search
- `query_point`: The query point (vector or point from point set)
- `k::Int`: Number of nearest neighbors to find (default: 1)
- `epsilon::Float64`: Approximation parameter (0.0 = exact search, >0.0 = approximate)
- `exclude_range::Tuple{Int,Int}`: Exclude points in range [first, last] from results
- `track_stats::Bool`: If true, return (neighbors, stats) with distance calculation counts
- `ctx::Union{Nothing,SearchContext}`: Optional pre-allocated context for batch queries

# Returns
- If `track_stats=false`: Vector of `Neighbor` objects sorted by distance
- If `track_stats=true`: Tuple of (neighbors, stats) where stats contains distance_calcs and f_k

# Performance
For batch queries, reuse a SearchContext to avoid allocations:
```julia
ctx = SearchContext(tree, k)
for query in queries
    neighbors = knn(tree, query, k=k, ctx=ctx)
end
```
"""
function knn(tree::ATRIATree, query_point;
            k::Int=1,
            epsilon::Float64=0.0,
            exclude_range::Tuple{Int,Int}=(-1,-1),
            track_stats::Bool=false,
            ctx::Union{Nothing,SearchContext}=nothing)
    # Create or reuse context
    if ctx === nothing
        ctx = SearchContext(tree, k)
    end

    # Reset context for new query
    reset!(ctx, k)

    # Perform search
    _search_knn!(tree, query_point, ctx, epsilon, exclude_range)

    # Extract results
    neighbors = extract_neighbors(ctx)

    if track_stats
        N, _ = size(tree.points)
        f_k = ctx.distance_calcs / N
        stats = (distance_calcs=ctx.distance_calcs, f_k=f_k)
        return (neighbors, stats)
    else
        return neighbors
    end
end

"""
    knn_batch(tree::ATRIATree, queries; k::Int=1, epsilon::Float64=0.0,
              exclude_range::Tuple{Int,Int}=(-1,-1), track_stats::Bool=false)

Perform k-NN search on multiple query points with automatic context reuse.

# Arguments
- `tree::ATRIATree`: The ATRIA tree to search
- `queries`: Iterable of query points (e.g., Vector{Vector{Float64}} or Matrix where each row is a query)
- `k::Int`: Number of nearest neighbors to find (default: 1)
- `epsilon::Float64`: Approximation parameter (0.0 = exact search)
- `exclude_range::Tuple{Int,Int}`: Exclude points in range [first, last] from results
- `track_stats::Bool`: If true, return statistics for each query

# Returns
- If `track_stats=false`: Vector of neighbor lists (one per query)
- If `track_stats=true`: Tuple of (results, stats_list) where each stats contains distance_calcs and f_k

# Example
```julia
# Batch search on multiple queries
queries = [randn(D) for _ in 1:100]
results = knn_batch(tree, queries, k=10)

# With statistics
results, stats = knn_batch(tree, queries, k=10, track_stats=true)
mean_f_k = mean(s.f_k for s in stats)
```
"""
function knn_batch(tree::ATRIATree, queries;
                  k::Int=1,
                  epsilon::Float64=0.0,
                  exclude_range::Tuple{Int,Int}=(-1,-1),
                  track_stats::Bool=false)
    # Pre-allocate context once for all queries
    ctx = SearchContext(tree, k)

    # Process all queries
    results = Vector{Vector{Neighbor}}(undef, length(queries))

    if track_stats
        stats_list = Vector{NamedTuple{(:distance_calcs, :f_k), Tuple{Int, Float64}}}(undef, length(queries))
        for (i, query) in enumerate(queries)
            neighbors, stats = knn(tree, query, k=k, epsilon=epsilon,
                                  exclude_range=exclude_range, track_stats=true, ctx=ctx)
            results[i] = neighbors
            stats_list[i] = stats
        end
        return (results, stats_list)
    else
        for (i, query) in enumerate(queries)
            results[i] = knn(tree, query, k=k, epsilon=epsilon,
                           exclude_range=exclude_range, track_stats=false, ctx=ctx)
        end
        return results
    end
end

"""
Internal search function.
"""
function _search_knn!(tree::ATRIATree, query_point, ctx::SearchContext,
                     epsilon::Float64, exclude_range::Tuple{Int,Int})
    first, last = exclude_range

    # Calculate distance to root center
    root_dist = distance(tree.points, tree.root.center, query_point)
    ctx.distance_calcs += 1

    # Get pooled item and initialize for root
    root_si = allocate_item!(ctx.pool)
    init_root!(root_si, tree.root, root_dist)
    push!(ctx.pq, root_si)

    while !isempty(ctx.pq)
        si = popfirst!(ctx.pq)
        c = si.cluster

        # Test cluster center if not excluded
        if (c.center < first || c.center > last) && ctx.high_dist > si.dist
            insert_neighbor!(ctx, Neighbor(c.center, si.dist))
        end

        # Check if we need to explore this cluster further
        if ctx.high_dist >= si.d_min * (1.0 + epsilon)
            if is_terminal(c)
                # Terminal node: test points
                _search_terminal!(tree, c, si, query_point, ctx, first, last)
            else
                # Internal node: push children
                _push_children!(tree, c, si, query_point, ctx)
            end
        end
    end
end

"""
Terminal node search.
"""
@inline function _search_terminal!(tree::ATRIATree, c::Cluster, si::MutableSearchItem,
                                  query_point, ctx::SearchContext, first::Int, last::Int)
    section_start = c.start
    section_end = c.start + c.length - 1

    Rmax = abs(c.Rmax)

    if Rmax == 0.0
        # All points at same location
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if ctx.high_dist <= si.dist
                break
            end

            if j < first || j > last
                insert_neighbor!(ctx, Neighbor(j, si.dist))
            end
        end
    else
        # General case with triangle inequality
        @inbounds for i in section_start:section_end
            neighbor = tree.permutation_table[i]
            j = neighbor.index

            if j < first || j > last
                lower_bound = abs(si.dist - neighbor.distance)
                if ctx.high_dist > lower_bound
                    d = distance(tree.points, j, query_point)
                    ctx.distance_calcs += 1
                    insert_neighbor!(ctx, Neighbor(j, d))
                end
            end
        end
    end
end

"""
Child cluster pushing.
"""
@inline function _push_children!(tree::ATRIATree, c::Cluster,
                                parent_si::MutableSearchItem,
                                query_point, ctx::SearchContext)
    # Compute distances to children
    d_left = distance(tree.points, c.left.center, query_point)
    d_right = distance(tree.points, c.right.center, query_point)
    ctx.distance_calcs += 2

    # Get pooled items and initialize (NO ALLOCATIONS!)
    si_left = allocate_item!(ctx.pool)
    init_child!(si_left, c.left, d_left, d_right, parent_si)

    si_right = allocate_item!(ctx.pool)
    init_child!(si_right, c.right, d_right, d_left, parent_si)

    # Push onto queue
    push!(ctx.pq, si_left)
    push!(ctx.pq, si_right)
end

# Core data structures for ATRIA algorithm

"""
    Neighbor

Stores a neighbor point with its index and distance to the query point.

# Fields
- `index::Int`: Index of the neighbor in the point set
- `distance::Float64`: Distance to the query point
"""
struct Neighbor
    index::Int
    distance::Float64
end

# Comparison operators for Neighbor (for priority queue)
Base.isless(a::Neighbor, b::Neighbor) = a.distance < b.distance
Base.:(==)(a::Neighbor, b::Neighbor) = a.index == b.index && a.distance == b.distance

"""
    Cluster

Represents a node in the ATRIA tree structure.

# Fields
- `center::Int`: Index of the center point
- `Rmax::Float64`: Maximum radius from center to any point in cluster (negative for terminal nodes)
- `g_min::Float64`: Minimum gap to sibling cluster
- `start::Int`: Start index in permutation table (for terminal nodes)
- `length::Int`: Number of points in cluster (for terminal nodes)
- `left::Union{Cluster, Nothing}`: Left child cluster (for internal nodes)
- `right::Union{Cluster, Nothing}`: Right child cluster (for internal nodes)
"""
mutable struct Cluster
    center::Int
    Rmax::Float64
    g_min::Float64
    start::Int
    length::Int
    left::Union{Cluster, Nothing}
    right::Union{Cluster, Nothing}

    # Constructor for terminal node
    function Cluster(center::Int, Rmax::Float64, g_min::Float64, start::Int, length::Int)
        new(center, -abs(Rmax), g_min, start, length, nothing, nothing)
    end

    # Constructor for internal node
    function Cluster(center::Int, Rmax::Float64, g_min::Float64,
                     left::Cluster, right::Cluster)
        new(center, abs(Rmax), g_min, 0, 0, left, right)
    end

    # Constructor for root node (before subdivision)
    function Cluster(center::Int, Rmax::Float64)
        new(center, abs(Rmax), 0.0, 0, 0, nothing, nothing)
    end
end

"""
    is_terminal(cluster::Cluster) -> Bool

Check if a cluster is a terminal (leaf) node.

Terminal nodes have negative Rmax values as a marker.
Handles the special case of -0.0 using signbit.
"""
is_terminal(cluster::Cluster) = cluster.Rmax < 0 || (cluster.Rmax == 0 && signbit(cluster.Rmax))

"""
    SearchItem

Item for the priority queue during k-NN search.

# Fields
- `cluster::Cluster`: Pointer to the cluster
- `dist::Float64`: Distance from query to cluster center
- `dist_brother::Float64`: Distance from query to sibling cluster center
- `d_min::Float64`: Lower bound on distance to any point in cluster
- `d_max::Float64`: Upper bound on distance to any point in cluster
"""
struct SearchItem
    cluster::Cluster
    dist::Float64
    dist_brother::Float64
    d_min::Float64
    d_max::Float64

    # Constructor for root SearchItem
    function SearchItem(cluster::Cluster, dist::Float64)
        Rmax = abs(cluster.Rmax)
        d_min = max(0.0, dist - Rmax)
        d_max = dist + Rmax
        new(cluster, dist, 0.0, d_min, d_max)
    end

    # Constructor for child SearchItem (with parent bounds accumulation)
    function SearchItem(cluster::Cluster, dist::Float64, dist_brother::Float64, parent::SearchItem)
        Rmax = abs(cluster.Rmax)
        g_min = cluster.g_min

        # Calculate bounds using triangle inequality, matching C++ implementation:
        # dmin(max(max(0.0, 0.5*(D-Dbrother+c->g_min)), max(D - C->R_max(), parent.dmin)))
        # dmax(min(parent.dmax, D + C->R_max()))
        d_min_local = max(0.0, 0.5 * (dist - dist_brother + g_min))
        d_min = max(d_min_local, max(dist - Rmax, parent.d_min))
        d_max = min(parent.d_max, dist + Rmax)

        new(cluster, dist, dist_brother, d_min, d_max)
    end
end

# Priority queue ordering: process items with smallest d_min first
Base.isless(a::SearchItem, b::SearchItem) = a.d_min < b.d_min

"""
    SortedNeighborTable

Maintains a priority queue of the k nearest neighbors found so far.

# Fields
- `k::Int`: Number of neighbors to find
- `neighbors::Vector{Neighbor}`: Current k-nearest neighbors (max heap)
- `high_dist::Float64`: Distance to the k-th nearest neighbor (or Inf if < k found)
- `seen::BitSet`: Track which point indices have been inserted (for duplicate prevention)

NOTE: Unlike C++ ATRIA, we need duplicate checking because centers can be visited
multiple times through different paths in the tree. The BitSet provides O(1) lookup.
"""
mutable struct SortedNeighborTable
    k::Int
    neighbors::Vector{Neighbor}
    high_dist::Float64
    seen::BitSet

    function SortedNeighborTable(k::Int)
        new(k, Neighbor[], Inf, BitSet())
    end
end

"""
    init_search!(table::SortedNeighborTable, k::Int)

Initialize or reset the table for a new search with k neighbors.
"""
function init_search!(table::SortedNeighborTable, k::Int)
    table.k = k
    empty!(table.neighbors)
    empty!(table.seen)
    table.high_dist = Inf
    return table
end

"""
    insert!(table::SortedNeighborTable, neighbor::Neighbor)

Insert a neighbor into the table, maintaining only the k nearest.

Uses a max heap to efficiently track the k nearest neighbors.
Prevents duplicate point indices from being inserted using BitSet for O(1) lookup.
"""
@inline function Base.insert!(table::SortedNeighborTable, neighbor::Neighbor)
    idx = neighbor.index

    # Fast duplicate check with BitSet - O(1) instead of O(k)
    if idx in table.seen
        return table  # Already processed this point
    end

    # Mark as seen
    push!(table.seen, idx)

    if length(table.neighbors) < table.k
        # Still have room, just add it
        push!(table.neighbors, neighbor)
        # Heapify to maintain max heap property
        heapify_up!(table.neighbors, length(table.neighbors))

        # Update high_dist if we now have k neighbors
        if length(table.neighbors) == table.k
            table.high_dist = table.neighbors[1].distance
        end
    elseif neighbor.distance < table.high_dist
        # Replace the farthest neighbor (at root of max heap)
        # Remove old index from seen set
        old_idx = table.neighbors[1].index
        delete!(table.seen, old_idx)

        # Insert new neighbor
        table.neighbors[1] = neighbor
        heapify_down!(table.neighbors, 1)
        table.high_dist = table.neighbors[1].distance
    else
        # Point is farther than k-th nearest, but we marked it as seen
        # Remove from seen since we didn't actually add it
        delete!(table.seen, idx)
    end
    return table
end

"""
    finish_search(table::SortedNeighborTable) -> Vector{Neighbor}

Extract the final sorted list of neighbors (closest first).
"""
function finish_search(table::SortedNeighborTable)
    # Extract from heap and sort
    neighbors = copy(table.neighbors)
    sort!(neighbors, by=n->n.distance)
    return neighbors
end

# Helper functions for max heap operations
function heapify_up!(heap::Vector{Neighbor}, idx::Int)
    while idx > 1
        parent = idx ÷ 2
        if heap[idx].distance > heap[parent].distance
            heap[idx], heap[parent] = heap[parent], heap[idx]
            idx = parent
        else
            break
        end
    end
end

function heapify_down!(heap::Vector{Neighbor}, idx::Int)
    n = length(heap)
    while true
        largest = idx
        left = 2 * idx
        right = 2 * idx + 1

        if left <= n && heap[left].distance > heap[largest].distance
            largest = left
        end
        if right <= n && heap[right].distance > heap[largest].distance
            largest = right
        end

        if largest != idx
            heap[idx], heap[largest] = heap[largest], heap[idx]
            idx = largest
        else
            break
        end
    end
end

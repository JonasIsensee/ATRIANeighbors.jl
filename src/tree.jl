# ATRIA tree construction

using Random

"""
    ATRIATree{T,D,M}

ATRIA tree structure for efficient nearest neighbor search.

The tree is constructed by recursively partitioning the data using a binary
tree structure. Each node (cluster) contains a center point and radius information.
Terminal (leaf) nodes contain references to a section of the permutation table.

# Fields
- `root::Cluster`: Root of the tree
- `permutation_table::Vector{Neighbor}`: Permutation of points with distances to cluster centers
- `points::AbstractPointSet{T,D,M}`: The point set being indexed
- `min_points::Int`: Minimum points in a cluster before subdivision stops
- `total_clusters::Int`: Total number of clusters in the tree
- `terminal_nodes::Int`: Number of terminal (leaf) nodes

# Algorithm

The ATRIA algorithm constructs a binary tree by recursively partitioning points:

1. **Select root center**: Choose a random point as the initial center
2. **For each cluster with > min_points**:
   - Find two new centers (right = farthest from current, left = farthest from right)
   - Partition points to nearest center (like quicksort)
   - Calculate Rmax (max distance to center) and g_min (min gap between clusters)
   - Create two child clusters
3. **Terminal nodes**: Clusters with ≤ min_points are marked terminal

The key innovation is storing distances to cluster centers in the permutation table,
which enables triangle inequality pruning during search.
"""
struct ATRIATree{T,D,M<:Metric}
    root::Cluster
    permutation_table::Vector{Neighbor}
    points::AbstractPointSet{T,D,M}
    min_points::Int
    total_clusters::Int
    terminal_nodes::Int
end

"""
    create_root_cluster(points::AbstractPointSet, rng::AbstractRNG) -> (Cluster, Vector{Neighbor})

Create the initial root cluster and permutation table.

Selects a random center point and computes distances to all other points.

Returns:
- Root cluster with computed Rmax
- Initial permutation table with all points and their distances to center
"""
function create_root_cluster(points::AbstractPointSet, rng::AbstractRNG=Random.GLOBAL_RNG)
    N, D = size(points)

    if N == 0
        throw(ArgumentError("Cannot create tree from empty point set"))
    end

    # Select random center
    center_idx = rand(rng, 1:N)

    # Initialize permutation table with all points
    permutation = Vector{Neighbor}(undef, N)
    Rmax = 0.0

    # Compute distances to center
    center_point = getpoint(points, center_idx)
    for i in 1:N
        if i == center_idx
            dist = 0.0
        else
            dist = distance(points, i, center_point)
        end
        permutation[i] = Neighbor(i, dist)
        Rmax = max(Rmax, dist)
    end

    # Create root cluster (not yet subdivided, so not terminal)
    root = Cluster(center_idx, Rmax)

    return root, permutation
end

"""
    find_child_cluster_centers!(
        points::AbstractPointSet,
        permutation::AbstractVector{Neighbor},
        start_idx::Int,
        length::Int,
        current_center::Int
    ) -> (Int, Int, Float64)

Find the centers for left and right child clusters.

Algorithm:
1. Right center: Point farthest from current center
2. Left center: Point farthest from right center

Returns:
- `left_center_idx`: Index of left cluster center
- `right_center_idx`: Index of right cluster center
- `center_distance`: Distance between the two new centers

Handles degenerate cases where all points are identical.
"""
function find_child_cluster_centers!(
    points::AbstractPointSet,
    permutation::AbstractVector{Neighbor},
    start_idx::Int,
    length::Int,
    current_center::Int
)
    if length <= 1
        throw(ArgumentError("Cannot find centers for cluster with $length points"))
    end

    # Find right center: farthest from current center
    max_dist = -1.0
    right_center_idx = -1
    right_center_pos = -1

    for i in start_idx:(start_idx + length - 1)
        if permutation[i].distance > max_dist
            max_dist = permutation[i].distance
            right_center_idx = permutation[i].index
            right_center_pos = i
        end
    end

    # Handle degenerate case: all points identical to center
    if max_dist <= 0.0
        # Just split arbitrarily
        left_center_idx = permutation[start_idx].index
        right_center_idx = permutation[min(start_idx + 1, start_idx + length - 1)].index
        return left_center_idx, right_center_idx, 0.0
    end

    # Find left center: farthest from right center
    right_center_point = getpoint(points, right_center_idx)
    max_dist = -1.0
    left_center_idx = -1

    for i in start_idx:(start_idx + length - 1)
        point_idx = permutation[i].index
        dist = distance(points, point_idx, right_center_point)
        if dist > max_dist
            max_dist = dist
            left_center_idx = point_idx
        end
    end

    # Calculate distance between centers
    left_center_point = getpoint(points, left_center_idx)
    center_distance = distance(points, right_center_idx, left_center_point)

    return left_center_idx, right_center_idx, center_distance
end

"""
    assign_points_to_centers!(
        points::AbstractPointSet,
        permutation::AbstractVector{Neighbor},
        start_idx::Int,
        length::Int,
        left_center_idx::Int,
        right_center_idx::Int
    ) -> (Int, Float64, Float64, Float64)

Partition points between left and right clusters.

Uses a quicksort-like partitioning: assigns each point to the nearest center
and rearranges the permutation table so left cluster points come first.

Returns:
- `split_pos`: Position where partition splits (left: [start, split), right: [split, end])
- `left_Rmax`: Maximum radius of left cluster
- `right_Rmax`: Maximum radius of right cluster
- `g_min`: Minimum gap between clusters (for pruning)

The g_min is computed as: min over all points of |dist_to_left - dist_to_right|
"""
function assign_points_to_centers!(
    points::AbstractPointSet,
    permutation::AbstractVector{Neighbor},
    start_idx::Int,
    length::Int,
    left_center_idx::Int,
    right_center_idx::Int
)
    left_center = getpoint(points, left_center_idx)
    right_center = getpoint(points, right_center_idx)

    # Partition points
    left_ptr = start_idx
    right_ptr = start_idx + length - 1

    left_Rmax = 0.0
    right_Rmax = 0.0
    g_min = Inf

    while left_ptr <= right_ptr
        point_idx = permutation[left_ptr].index

        # Calculate distances to both centers
        dist_left = distance(points, point_idx, left_center)
        dist_right = distance(points, point_idx, right_center)

        # Update g_min
        gap = abs(dist_left - dist_right)
        g_min = min(g_min, gap)

        # Assign to nearest center
        if dist_left <= dist_right
            # Belongs to left cluster
            permutation[left_ptr] = Neighbor(point_idx, dist_left)
            left_Rmax = max(left_Rmax, dist_left)
            left_ptr += 1
        else
            # Belongs to right cluster - swap with right_ptr
            permutation[left_ptr] = Neighbor(permutation[right_ptr].index,
                                            permutation[right_ptr].distance)

            # Update the swapped position with right cluster info
            permutation[right_ptr] = Neighbor(point_idx, dist_right)
            right_Rmax = max(right_Rmax, dist_right)
            right_ptr -= 1

            # Don't increment left_ptr, we need to process the swapped element
        end
    end

    split_pos = left_ptr
    left_length = split_pos - start_idx
    right_length = length - left_length

    # Recalculate distances and Rmax for both clusters after partitioning
    # (the swap operation may have messed up some distances)
    left_Rmax = 0.0
    for i in start_idx:(split_pos - 1)
        point_idx = permutation[i].index
        dist = distance(points, point_idx, left_center)
        permutation[i] = Neighbor(point_idx, dist)
        left_Rmax = max(left_Rmax, dist)
    end

    right_Rmax = 0.0
    for i in split_pos:(start_idx + length - 1)
        point_idx = permutation[i].index
        dist = distance(points, point_idx, right_center)
        permutation[i] = Neighbor(point_idx, dist)
        right_Rmax = max(right_Rmax, dist)
    end

    return split_pos, left_Rmax, right_Rmax, g_min
end

"""
    build_tree!(
        points::AbstractPointSet,
        permutation::Vector{Neighbor},
        root::Cluster,
        min_points::Int
    ) -> (Int, Int)

Recursively build the ATRIA tree starting from root.

Uses stack-based iteration (not recursion) to avoid stack overflow on deep trees.

Returns:
- `total_clusters`: Total number of clusters created
- `terminal_nodes`: Number of terminal (leaf) nodes

# Algorithm

1. Push root onto stack with its section of permutation table
2. While stack not empty:
   - Pop cluster and section info
   - If section has ≤ min_points: mark as terminal
   - Else:
     - Find left and right centers
     - Partition points
     - Create left and right child clusters
     - Push children onto stack
"""
function build_tree!(
    points::AbstractPointSet,
    permutation::Vector{Neighbor},
    root::Cluster,
    min_points::Int
)
    N = size(points)[1]

    # Stack entries: (cluster, start_idx, length)
    stack = Vector{Tuple{Cluster, Int, Int}}()
    push!(stack, (root, 1, N))

    total_clusters = 1
    terminal_nodes = 0

    while !isempty(stack)
        cluster, start_idx, length = pop!(stack)

        # Check if this should be a terminal node
        if length <= min_points
            # Mark as terminal (negate Rmax)
            cluster.Rmax = -abs(cluster.Rmax)
            cluster.start = start_idx
            cluster.length = length
            terminal_nodes += 1
            continue
        end

        # Find centers for subdivision
        try
            left_center, right_center, center_dist = find_child_cluster_centers!(
                points, permutation, start_idx, length, cluster.center
            )

            # Partition points
            split_pos, left_Rmax, right_Rmax, g_min = assign_points_to_centers!(
                points, permutation, start_idx, length,
                left_center, right_center
            )

            left_length = split_pos - start_idx
            right_length = length - left_length

            # Handle edge case: partition failed (all points went to one side)
            if left_length == 0 || right_length == 0
                # Make this a terminal node
                cluster.Rmax = -abs(cluster.Rmax)
                cluster.start = start_idx
                cluster.length = length
                terminal_nodes += 1
                continue
            end

            # Create child clusters
            left_child = Cluster(left_center, left_Rmax)
            right_child = Cluster(right_center, right_Rmax)

            # Store g_min (will be same for both children)
            left_child.g_min = g_min
            right_child.g_min = g_min

            # Link children to parent
            cluster.left = left_child
            cluster.right = right_child

            # Push children onto stack for processing
            push!(stack, (right_child, split_pos, right_length))
            push!(stack, (left_child, start_idx, left_length))

            total_clusters += 2

        catch e
            # If subdivision fails, make this a terminal node
            cluster.Rmax = -abs(cluster.Rmax)
            cluster.start = start_idx
            cluster.length = length
            terminal_nodes += 1
        end
    end

    return total_clusters, terminal_nodes
end

"""
    ATRIA(points::AbstractPointSet; min_points::Int=64, rng::AbstractRNG=Random.GLOBAL_RNG) -> ATRIATree

Construct an ATRIA tree for efficient nearest neighbor search.

# Arguments
- `points`: Point set to index (PointSet or EmbeddedTimeSeries)
- `min_points`: Minimum points per cluster before subdivision stops (default: 64)
- `rng`: Random number generator for center selection (default: global RNG)

# Returns
- `ATRIATree`: Constructed tree ready for search queries

# Example
```julia
data = randn(1000, 10)  # 1000 points in 10D
ps = PointSet(data)
tree = ATRIA(ps, min_points=32)
```
"""
function ATRIA(points::AbstractPointSet;
               min_points::Int=64,
               rng::AbstractRNG=Random.GLOBAL_RNG)

    if min_points < 1
        throw(ArgumentError("min_points must be >= 1, got $min_points"))
    end

    N, D = size(points)

    if N < 1
        throw(ArgumentError("Cannot create tree from empty point set"))
    end

    # Create root and permutation table
    root, permutation = create_root_cluster(points, rng)

    # Build the tree
    total_clusters, terminal_nodes = build_tree!(points, permutation, root, min_points)

    return ATRIATree(root, permutation, points, min_points,
                     total_clusters, terminal_nodes)
end

# Tree inspection utilities

"""
    tree_depth(tree::ATRIATree) -> Int
    tree_depth(cluster::Cluster) -> Int

Compute the maximum depth of the tree.
"""
function tree_depth(tree::ATRIATree)
    return tree_depth(tree.root)
end

function tree_depth(cluster::Cluster)
    if is_terminal(cluster)
        return 0
    else
        left_depth = cluster.left === nothing ? 0 : tree_depth(cluster.left)
        right_depth = cluster.right === nothing ? 0 : tree_depth(cluster.right)
        return 1 + max(left_depth, right_depth)
    end
end

"""
    count_nodes(tree::ATRIATree) -> Int

Count total number of nodes in the tree (same as tree.total_clusters).
"""
count_nodes(tree::ATRIATree) = tree.total_clusters

"""
    average_terminal_size(tree::ATRIATree) -> Float64

Compute average number of points in terminal nodes.
"""
function average_terminal_size(tree::ATRIATree)
    if tree.terminal_nodes == 0
        return 0.0
    end

    total_points = sum_terminal_sizes(tree.root)
    return total_points / tree.terminal_nodes
end

function sum_terminal_sizes(cluster::Cluster)
    if is_terminal(cluster)
        return Float64(cluster.length)
    else
        left_sum = cluster.left === nothing ? 0.0 : sum_terminal_sizes(cluster.left)
        right_sum = cluster.right === nothing ? 0.0 : sum_terminal_sizes(cluster.right)
        return left_sum + right_sum
    end
end

"""
    print_tree_stats(tree::ATRIATree)

Print statistics about the tree structure.
"""
function print_tree_stats(tree::ATRIATree)
    N, D = size(tree.points)
    println("ATRIA Tree Statistics:")
    println("  Points: $N")
    println("  Dimensions: $D")
    println("  Min points per cluster: $(tree.min_points)")
    println("  Total clusters: $(tree.total_clusters)")
    println("  Terminal nodes: $(tree.terminal_nodes)")
    println("  Tree depth: $(tree_depth(tree))")
    println("  Average terminal size: $(round(average_terminal_size(tree), digits=2))")
end

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

**CRITICAL**: To match C++ ATRIA behavior, the root center is placed at position 1,
and all other points follow. This ensures the root center is never included in
child cluster sections, eliminating the need for duplicate checking during search.

Returns:
- Root cluster with computed Rmax
- Initial permutation table with root center at position 1, others at positions 2..N
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

    # CRITICAL: Place root center at position 1 (matching C++ behavior)
    # This ensures it's never included in child cluster sections
    permutation[1] = Neighbor(center_idx, 0.0)

    # Compute distances to center and place other points at positions 2..N
    center_point = getpoint(points, center_idx)
    write_pos = 2
    for i in 1:N
        if i != center_idx
            dist = distance(points, i, center_point)
            permutation[write_pos] = Neighbor(i, dist)
            Rmax = max(Rmax, dist)
            write_pos += 1
        end
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

    # Move right center to last position (matching C++ behavior)
    # swap(Section, index, length-1) in C++
    right_pos_new = start_idx + length - 1
    if right_center_pos != right_pos_new
        permutation[right_center_pos], permutation[right_pos_new] =
            permutation[right_pos_new], permutation[right_center_pos]
    end

    # Find left center: farthest from right center
    # **CRITICAL**: Update permutation table with distances to right center as we go
    # This is the key optimization that allows assign_points_to_centers! to reuse these distances
    right_center_point = getpoint(points, right_center_idx)
    max_dist = -1.0
    left_center_idx = -1
    left_center_pos = -1

    # Note: loop to length-2 because length-1 is the right center
    for i in start_idx:(start_idx + length - 2)
        point_idx = permutation[i].index
        dist = distance(points, point_idx, right_center_point)

        # ⭐ CRITICAL OPTIMIZATION: Store distance to right center in permutation table
        # This allows the partition algorithm to reuse these distances instead of recalculating
        permutation[i] = Neighbor(point_idx, dist)

        if dist > max_dist
            max_dist = dist
            left_center_idx = point_idx
            left_center_pos = i
        end
    end

    # Move left center to first position (matching C++ behavior)
    # swap(Section, index, 0) in C++
    if left_center_pos != start_idx
        permutation[left_center_pos], permutation[start_idx] =
            permutation[start_idx], permutation[left_center_pos]
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

Partition points between left and right clusters using C++ ATRIA's optimized algorithm.

**CRITICAL OPTIMIZATION**: This function reuses precomputed distances to the right center
that were stored in the permutation table by find_child_cluster_centers!. Only distances
to the left center need to be computed, cutting distance calculations by ~2.5x.

Algorithm (matching C++ implementation):
1. Dual-pointer quicksort-like partition
2. Walk from left: reuse permutation[i].distance (dist to right center), compute dist to left
3. Walk from right: reuse permutation[j].distance (dist to right center), compute dist to left
4. Swap points that belong on opposite sides
5. Update permutation table with correct distance as we go (no recalculation pass needed)
6. Compute g_min during partition (no separate pass needed)

Returns:
- `split_pos`: Position where partition splits (left: [start, split), right: [split, end])
- `left_Rmax`: Maximum radius of left cluster
- `right_Rmax`: Maximum radius of right cluster
- `g_min`: Minimum gap between clusters (for pruning)
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

    # Dual-pointer partition (matching C++ algorithm)
    # IMPORTANT: Centers are at positions start_idx (left) and start_idx+length-1 (right)
    # So we partition indices start_idx+1 to start_idx+length-2
    i = start_idx
    j = start_idx + length - 1

    left_Rmax = 0.0
    right_Rmax = 0.0
    g_min_left = Inf
    g_min_right = Inf

    @inbounds while true
        i_belongs_to_left = true
        j_belongs_to_right = true

        # Walk from left: find point belonging to right cluster
        while i + 1 < j
            i += 1
            point_idx = permutation[i].index

            # ⭐ KEY OPTIMIZATION: Reuse precomputed distance to right center
            dist_right = permutation[i].distance
            # Only need to compute distance to left center
            dist_left = distance(points, point_idx, left_center)

            if dist_left > dist_right
                # Point belongs to right cluster
                diff = dist_left - dist_right
                # Store distance to right center (already have it, but for clarity)
                permutation[i] = Neighbor(point_idx, dist_right)
                i_belongs_to_left = false

                g_min_right = min(g_min_right, diff)
                right_Rmax = max(right_Rmax, dist_right)
                break
            else
                # Point belongs to left cluster
                diff = dist_right - dist_left
                # Store distance to left center
                permutation[i] = Neighbor(point_idx, dist_left)

                g_min_left = min(g_min_left, diff)
                left_Rmax = max(left_Rmax, dist_left)
            end
        end

        # Walk from right: find point belonging to left cluster
        while j - 1 > i
            j -= 1
            point_idx = permutation[j].index

            # ⭐ KEY OPTIMIZATION: Reuse precomputed distance to right center
            dist_right = permutation[j].distance
            # Only need to compute distance to left center
            dist_left = distance(points, point_idx, left_center)

            if dist_right >= dist_left
                # Point belongs to left cluster
                diff = dist_right - dist_left
                # Store distance to left center
                permutation[j] = Neighbor(point_idx, dist_left)
                j_belongs_to_right = false

                g_min_left = min(g_min_left, diff)
                left_Rmax = max(left_Rmax, dist_left)
                break
            else
                # Point belongs to right cluster
                diff = dist_left - dist_right
                # Store distance to right center
                permutation[j] = Neighbor(point_idx, dist_right)

                g_min_right = min(g_min_right, diff)
                right_Rmax = max(right_Rmax, dist_right)
            end
        end

        # Check if we're done
        if i == j - 1
            # Final adjustment based on what the last two pointers found
            if !i_belongs_to_left && !j_belongs_to_right
                # Both belong on opposite sides, swap them
                permutation[i], permutation[j] = permutation[j], permutation[i]
            elseif !i_belongs_to_left
                # i belongs right, j belongs right -> move both back
                i -= 1
                j -= 1
            elseif !j_belongs_to_right
                # i belongs left, j belongs left -> move both forward
                i += 1
                j += 1
            end
            # else: i belongs left, j belongs right -> they're in correct positions
            break
        else
            # Swap elements at i and j
            permutation[i], permutation[j] = permutation[j], permutation[i]
        end
    end

    # Split position is j (all elements before j belong to left, j and after belong to right)
    split_pos = j

    # g_min is the minimum of the two g_mins computed
    g_min = min(g_min_left, g_min_right)

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
    # CRITICAL: Start at position 2, length N-1 (position 1 is root center, excluded from section)
    # This matches C++ behavior: root.start = 1, root.length = Nused-1 (0-indexed vs 1-indexed)
    push!(stack, (root, 2, N-1))

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

            # Calculate child cluster ranges, EXCLUDING centers (matching C++ implementation)
            # Left center is at position start_idx, right center is at start_idx+length-1
            # C++: left->start = c_start+1, left->length = j-1
            #      right->start = c_start+j, right->length = c_length-j-1
            left_start = start_idx + 1  # Skip left center at start_idx
            left_length = split_pos - start_idx - 1
            right_start = split_pos
            right_length = start_idx + length - split_pos - 1  # Up to but not including right center

            # Handle edge case: partition failed (all points went to one side)
            if left_length <= 0 || right_length <= 0
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
            push!(stack, (right_child, right_start, right_length))
            push!(stack, (left_child, left_start, left_length))

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
    ATRIATree(points::AbstractPointSet; min_points::Int=64, rng::AbstractRNG=Random.GLOBAL_RNG) -> ATRIATree

Construct an ATRIA tree for efficient nearest neighbor search from a point set.

# Arguments
- `points`: Point set to index (PointSet or EmbeddedTimeSeries)
- `min_points`: Minimum points per cluster before subdivision stops (default: 64)
- `rng`: Random number generator for center selection (default: global RNG)

# Returns
- `ATRIATree`: Constructed tree ready for search queries

# Example
```julia
# Direct construction from matrix
data = randn(1000, 10)
tree = ATRIATree(data)

# Advanced: custom point set with time-delay embedding
signal = randn(5000)
ps = EmbeddedTimeSeries(signal, dim=3, delay=5)
tree = ATRIATree(ps, min_points=32)
```
"""
function ATRIATree(points::AbstractPointSet;
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

"""
    ATRIATree(data::Matrix; metric::Metric=EuclideanMetric(), min_points::Int=64, rng::AbstractRNG=Random.GLOBAL_RNG) -> ATRIATree

Construct an ATRIA tree directly from a data matrix (convenience constructor).

Creates a PointSet internally and builds the tree. For advanced use cases like
time-delay embeddings, construct an EmbeddedTimeSeries first and use the
AbstractPointSet constructor.

# Arguments
- `data`: N × D matrix where each row is a point
- `metric`: Distance metric to use (default: Euclidean)
- `min_points`: Minimum points per cluster before subdivision stops (default: 64)
- `rng`: Random number generator for center selection (default: global RNG)

# Returns
- `ATRIATree`: Constructed tree ready for search queries

# Example
```julia
# Simple: construct with default Euclidean metric
data = randn(1000, 10)
tree = ATRIATree(data)

# With custom metric and parameters
tree = ATRIATree(data, metric=MaximumMetric(), min_points=32)
```
"""
function ATRIATree(data::Matrix{T};
                   metric::Metric=EuclideanMetric(),
                   min_points::Int=64,
                   rng::AbstractRNG=Random.GLOBAL_RNG) where T
    ps = PointSet(data, metric)
    return ATRIATree(ps, min_points=min_points, rng=rng)
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
Includes both the cluster center and points in its section.
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
        # Count center (1) plus points in section (cluster.length)
        return Float64(cluster.length + 1)
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
function print_tree_stats(io::IO, tree::ATRIATree)
    N, D = size(tree.points)
    println(io, "ATRIA Tree Statistics:")
    println(io, "  Points: $N")
    println(io, "  Dimensions: $D")
    println(io, "  Min points per cluster: $(tree.min_points)")
    println(io, "  Total clusters: $(tree.total_clusters)")
    println(io, "  Terminal nodes: $(tree.terminal_nodes)")
    println(io, "  Tree depth: $(tree_depth(tree))")
    println(io, "  Average terminal size: $(round(average_terminal_size(tree), digits=2))")
end

# Convenience method that prints to stdout
print_tree_stats(tree::ATRIATree) = print_tree_stats(stdout, tree)

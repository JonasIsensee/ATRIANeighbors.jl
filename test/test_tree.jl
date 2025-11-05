using Test
using ATRIANeighbors
using ATRIANeighbors: create_root_cluster, find_child_cluster_centers!
using ATRIANeighbors: assign_points_to_centers!, build_tree!
using ATRIANeighbors: tree_depth, count_nodes, average_terminal_size
using Random

@testset "Tree Construction" begin
    @testset "create_root_cluster" begin
        # Simple 2D point set
        data = Float64[0 0; 3 4; 1 1; 2 2]
        ps = PointSet(data)

        rng = MersenneTwister(42)
        root, permutation = create_root_cluster(ps, rng)

        @test !is_terminal(root)
        @test root.Rmax >= 0.0
        @test length(permutation) == 4

        # All points should be in permutation
        indices = sort([p.index for p in permutation])
        @test indices == [1, 2, 3, 4]

        # Center point should have distance 0
        center_idx = root.center
        center_neighbor = findfirst(n -> n.index == center_idx, permutation)
        @test permutation[center_neighbor].distance == 0.0

        # Rmax should be max distance
        max_dist = maximum(p.distance for p in permutation)
        @test root.Rmax ≈ max_dist
    end

    @testset "create_root_cluster - edge cases" begin
        # Single point
        data = Float64[1 2 3]
        ps = PointSet(data)
        root, permutation = create_root_cluster(ps)

        @test length(permutation) == 1
        @test permutation[1].distance == 0.0
        @test root.Rmax == 0.0

        # Two points
        data = Float64[0 0; 1 1]
        ps = PointSet(data)
        root, permutation = create_root_cluster(ps)

        @test length(permutation) == 2
        @test root.Rmax ≈ sqrt(2)
    end

    @testset "find_child_cluster_centers!" begin
        data = Float64[0 0; 5 0; 0 5; 5 5]
        ps = PointSet(data)

        root, permutation = create_root_cluster(ps, MersenneTwister(1))

        left_idx, right_idx, center_dist = find_child_cluster_centers!(
            ps, permutation, 1, 4, root.center
        )

        @test left_idx != right_idx
        @test left_idx >= 1 && left_idx <= 4
        @test right_idx >= 1 && right_idx <= 4
        @test center_dist >= 0.0
    end

    @testset "find_child_cluster_centers! - degenerate case" begin
        # All points identical
        data = Float64[1 1; 1 1; 1 1]
        ps = PointSet(data)

        root, permutation = create_root_cluster(ps)

        left_idx, right_idx, center_dist = find_child_cluster_centers!(
            ps, permutation, 1, 3, root.center
        )

        # Should handle gracefully
        @test left_idx != right_idx
        @test center_dist == 0.0
    end

    @testset "assign_points_to_centers!" begin
        # Four points in corners of square
        data = Float64[0 0; 10 0; 0 10; 10 10]
        ps = PointSet(data)

        # Use opposite corners as centers
        left_center = 1   # [0, 0]
        right_center = 4  # [10, 10]

        root, permutation = create_root_cluster(ps, MersenneTwister(1))

        split_pos, left_Rmax, right_Rmax, g_min = assign_points_to_centers!(
            ps, permutation, 1, 4, left_center, right_center
        )

        # Should split into two groups
        @test split_pos > 1
        @test split_pos <= 4

        # Check that left points are closer to left center
        for i in 1:(split_pos-1)
            point_idx = permutation[i].index
            dist_left = distance(ps, point_idx, getpoint(ps, left_center))
            dist_right = distance(ps, point_idx, getpoint(ps, right_center))
            @test dist_left <= dist_right
        end

        # Check that right points are closer to right center
        for i in split_pos:4
            point_idx = permutation[i].index
            dist_left = distance(ps, point_idx, getpoint(ps, left_center))
            dist_right = distance(ps, point_idx, getpoint(ps, right_center))
            @test dist_right <= dist_left
        end

        # Rmax should be non-negative
        @test left_Rmax >= 0.0
        @test right_Rmax >= 0.0

        # g_min should be non-negative
        @test g_min >= 0.0
    end

    @testset "ATRIA construction - small dataset" begin
        # 10 points in 2D
        data = randn(MersenneTwister(42), 10, 2)
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=3)

        @test tree.root isa Cluster
        @test length(tree.permutation_table) == 10
        @test tree.min_points == 3
        @test tree.total_clusters > 0
        @test tree.terminal_nodes > 0
    end

    @testset "ATRIA construction - verify permutation" begin
        data = Float64[1 1; 2 2; 3 3; 4 4; 5 5]
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=2)

        # All original indices should be in permutation
        indices = sort([n.index for n in tree.permutation_table])
        @test indices == [1, 2, 3, 4, 5]

        # Each index should appear exactly once
        @test length(unique(indices)) == 5
    end

    @testset "ATRIA construction - min_points effect" begin
        data = randn(MersenneTwister(123), 100, 3)
        ps = PointSet(data)

        tree_large_min = ATRIA(ps, min_points=50)
        tree_small_min = ATRIA(ps, min_points=10)

        # Smaller min_points should create more splits
        @test tree_small_min.total_clusters > tree_large_min.total_clusters
        @test tree_small_min.terminal_nodes > tree_large_min.terminal_nodes

        # Average terminal size should be related to min_points
        @test average_terminal_size(tree_large_min) > average_terminal_size(tree_small_min)
    end

    @testset "ATRIA construction - different dimensions" begin
        for D in [1, 2, 5, 10, 20]
            data = randn(MersenneTwister(42), 100, D)
            ps = PointSet(data)

            tree = ATRIA(ps, min_points=10)

            @test size(tree.points) == (100, D)
            @test tree.total_clusters > 0
            @test tree.terminal_nodes > 0
        end
    end

    @testset "ATRIA construction - single point" begin
        data = Float64[1 2 3]
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=10)

        @test tree.total_clusters == 1
        @test tree.terminal_nodes == 1
        @test is_terminal(tree.root)
        @test tree.root.length == 1
    end

    @testset "ATRIA construction - few points" begin
        # Fewer points than min_points
        data = Float64[1 1; 2 2; 3 3]
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=10)

        @test tree.terminal_nodes == 1
        @test is_terminal(tree.root)
        @test tree.root.length == 3
    end

    @testset "ATRIA construction - validation" begin
        data = randn(10, 3)
        ps = PointSet(data)

        # Invalid min_points
        @test_throws ArgumentError ATRIA(ps, min_points=0)
        @test_throws ArgumentError ATRIA(ps, min_points=-1)

        # Valid construction
        tree = ATRIA(ps, min_points=1)
        @test tree isa ATRIATree
    end

    @testset "Tree invariants" begin
        data = randn(MersenneTwister(42), 50, 3)
        ps = PointSet(data)
        tree = ATRIA(ps, min_points=5)

        # Verify tree structure recursively
        function verify_cluster(cluster::Cluster, perm::Vector{Neighbor})
            if is_terminal(cluster)
                # Terminal node checks
                @test cluster.start >= 1
                @test cluster.start + cluster.length - 1 <= length(perm)
                @test cluster.length > 0
                @test cluster.left === nothing
                @test cluster.right === nothing
                return cluster.length
            else
                # Internal node checks
                @test cluster.left !== nothing
                @test cluster.right !== nothing
                @test !is_terminal(cluster.left) || cluster.left.length > 0
                @test !is_terminal(cluster.right) || cluster.right.length > 0

                left_count = verify_cluster(cluster.left, perm)
                right_count = verify_cluster(cluster.right, perm)
                return left_count + right_count
            end
        end

        total_in_terminals = verify_cluster(tree.root, tree.permutation_table)

        # Note: In the C++ ATRIA algorithm, cluster centers are excluded from child clusters
        # They're stored at boundaries but not counted in terminal node lengths
        # Centers are still searchable (tested separately during search)
        # So total_in_terminals < N is expected
        @test total_in_terminals > 0  # At least some points in terminals
        @test total_in_terminals <= 50  # Not more than total points
    end

    @testset "tree_depth" begin
        # Shallow tree (large min_points)
        data = randn(MersenneTwister(42), 100, 3)
        ps = PointSet(data)

        tree_shallow = ATRIA(ps, min_points=50)
        tree_deep = ATRIA(ps, min_points=5)

        depth_shallow = tree_depth(tree_shallow)
        depth_deep = tree_depth(tree_deep)

        @test depth_shallow >= 0
        @test depth_deep >= depth_shallow  # Deeper tree with smaller min_points

        # Single point has depth 0
        data_single = Float64[1 2]
        ps_single = PointSet(data_single)
        tree_single = ATRIA(ps_single)
        @test tree_depth(tree_single) == 0
    end

    @testset "count_nodes" begin
        data = randn(MersenneTwister(42), 50, 3)
        ps = PointSet(data)
        tree = ATRIA(ps, min_points=10)

        @test count_nodes(tree) == tree.total_clusters
        @test count_nodes(tree) >= tree.terminal_nodes
    end

    @testset "average_terminal_size" begin
        data = randn(MersenneTwister(42), 100, 3)
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=10)
        avg_size = average_terminal_size(tree)

        @test avg_size > 0.0
        @test avg_size <= tree.min_points  # Should be at most min_points

        # Single terminal node
        data_small = Float64[1 1; 2 2; 3 3]
        ps_small = PointSet(data_small)
        tree_small = ATRIA(ps_small, min_points=10)
        @test average_terminal_size(tree_small) == 3.0
    end

    @testset "print_tree_stats" begin
        data = randn(MersenneTwister(42), 50, 5)
        ps = PointSet(data)
        tree = ATRIA(ps, min_points=8)

        # Should not error
        io = IOBuffer()
        print_tree_stats(io, tree)
        output = String(take!(io))

        @test occursin("ATRIA Tree Statistics", output)
        @test occursin("Points: 50", output)
        @test occursin("Dimensions: 5", output)
    end

    @testset "ATRIA with EmbeddedTimeSeries" begin
        # Test tree construction with embedded time series
        data = sin.(0.1 * (1:100)) + 0.1 * randn(MersenneTwister(42), 100)
        ps = EmbeddedTimeSeries(data, 5, 2)

        tree = ATRIA(ps, min_points=10)

        n_embedded, dim = size(ps)
        @test size(tree.points) == (n_embedded, dim)
        @test tree.total_clusters > 0
        @test tree.terminal_nodes > 0
        @test length(tree.permutation_table) == n_embedded
    end

    @testset "Reproducibility with RNG" begin
        data = randn(100, 3)
        ps = PointSet(data)

        # Same seed should give same tree
        tree1 = ATRIA(ps, min_points=10, rng=MersenneTwister(42))
        tree2 = ATRIA(ps, min_points=10, rng=MersenneTwister(42))

        @test tree1.root.center == tree2.root.center
        @test tree1.total_clusters == tree2.total_clusters
        @test tree1.terminal_nodes == tree2.terminal_nodes

        # Different seed should (likely) give different tree
        tree3 = ATRIA(ps, min_points=10, rng=MersenneTwister(123))
        @test tree1.root.center != tree3.root.center || tree1.total_clusters != tree3.total_clusters
    end

    @testset "Large dataset" begin
        # Test with larger dataset
        data = randn(MersenneTwister(42), 1000, 10)
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=32)

        @test tree.total_clusters > 10
        @test tree.terminal_nodes > 5
        @test tree_depth(tree) > 2

        # Verify all points are in permutation
        indices = sort([n.index for n in tree.permutation_table])
        @test indices == collect(1:1000)
    end

    @testset "Cluster subdivision correctness" begin
        # Verify that subdivision actually separates points in space
        data = Float64[
            0 0;
            0 1;
            0 2;
            10 0;
            10 1;
            10 2
        ]
        ps = PointSet(data)

        tree = ATRIA(ps, min_points=2)

        # With well-separated clusters, tree should create meaningful divisions
        @test tree.total_clusters > 1
        @test tree.terminal_nodes >= 2

        # Each terminal should have reasonable size
        function check_terminal_sizes(cluster::Cluster)
            if is_terminal(cluster)
                @test cluster.length <= tree.min_points
                @test cluster.length > 0
            else
                check_terminal_sizes(cluster.left)
                check_terminal_sizes(cluster.right)
            end
        end

        check_terminal_sizes(tree.root)
    end
end

using Test
using ATRIANeighbors
using StableRNGs
using NearestNeighbors
import NearestNeighbors as NN

# Resolve name conflicts: explicitly use ATRIANeighbors functions
using ATRIANeighbors: knn, knn_batch, range_search, count_range, brute_knn, brute_range_search, brute_count_range

"""
Comprehensive correctness tests validating ATRIA against both:
1. Internal brute force implementation
2. NearestNeighbors.jl (KDTree, BallTree)

Uses StableRNGs for reproducible tests across Julia versions.
"""

@testset "Correctness Validation" begin

@testset "Systematic (N, D, k) Coverage" begin
    # Test across a range of dataset sizes, dimensions, and k values
    # to ensure ATRIA works correctly in all scenarios

    test_configs = [
        # (N, D, k, min_points, description)
        (10, 2, 1, 3, "Very small dataset"),
        (50, 3, 5, 10, "Small 3D dataset"),
        (100, 5, 10, 15, "Medium 5D dataset"),
        (200, 10, 20, 20, "Medium 10D dataset"),
        (500, 15, 30, 30, "Large 15D dataset"),
        (1000, 20, 50, 40, "Large 20D dataset"),
        (100, 50, 10, 25, "High-D dataset (curse of dimensionality)"),
    ]

    for (N, D, k, min_points, desc) in test_configs
        @testset "$desc (N=$N, D=$D, k=$k)" begin
            rng = StableRNG(42)

            # Generate data
            data = randn(rng, D, N)
            ps = PointSet(data, EuclideanMetric())
            tree = ATRIATree(ps, min_points=min_points, rng=rng)

            # Generate stable query
            query = randn(StableRNG(123), D)

            # ATRIA results
            atria_results = knn(tree, query, k=k)

            # Validate against brute force
            brute_results = brute_knn(ps, query, k)

            @test length(atria_results) == k
            @test length(brute_results) == k

            # Check for duplicates
            indices = [n.index for n in atria_results]
            @test length(indices) == length(unique(indices))

            # Verify exact match
            for i in 1:k
                @test atria_results[i].index == brute_results[i].index
                @test atria_results[i].distance ≈ brute_results[i].distance atol=1e-12
            end

            # Cross-validate against NearestNeighbors.jl KDTree
            kdtree = NN.KDTree(data)
            nn_indices, nn_distances = NN.knn(kdtree, query, k, true)

            # Sort both by distance (KDTree might return in different order)
            atria_sorted = sort(atria_results, by=n->n.distance)
            nn_sorted_pairs = sort(collect(zip(nn_indices, nn_distances)), by=p->p[2])

            # Distances should match (indices might differ if ties exist)
            for i in 1:k
                @test atria_sorted[i].distance ≈ nn_sorted_pairs[i][2] rtol=1e-10
            end
        end
    end
end

@testset "Edge Cases" begin
    @testset "k = 1 (single nearest neighbor)" begin
        rng = StableRNG(100)
        data = randn(rng, 3, 50)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10, rng=rng)
        query = randn(StableRNG(101), 3)

        atria_results = knn(tree, query, k=1)
        brute_results = brute_knn(ps, query, 1)

        @test length(atria_results) == 1
        @test atria_results[1].index == brute_results[1].index
        @test atria_results[1].distance ≈ brute_results[1].distance
    end

    @testset "k = N (all points)" begin
        rng = StableRNG(102)
        N = 30
        data = randn(rng, 3, N)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=5, rng=rng)
        query = randn(StableRNG(103), 3)

        atria_results = knn(tree, query, k=N)
        brute_results = brute_knn(ps, query, N)

        @test length(atria_results) == N

        # All points should be returned, sorted by distance
        for i in 1:N
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end

    @testset "k > N (request more than available)" begin
        rng = StableRNG(104)
        N = 20
        data = randn(rng, 3, N)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=5, rng=rng)
        query = randn(StableRNG(105), 3)

        # Should return all N points, not crash
        atria_results = knn(tree, query, k=100)

        @test length(atria_results) == N

        # Verify against brute force
        brute_results = brute_knn(ps, query, 100)
        @test length(brute_results) == N

        for i in 1:N
            @test atria_results[i].index == brute_results[i].index
        end
    end

    @testset "N < min_points (single terminal node)" begin
        rng = StableRNG(106)
        data = randn(rng, 3, 5)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10, rng=rng)

        # Tree should have single terminal node
        @test tree.terminal_nodes == 1

        query = randn(StableRNG(107), 3)
        atria_results = knn(tree, query, k=3)
        brute_results = brute_knn(ps, query, 3)

        @test length(atria_results) == 3
        for i in 1:3
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end

    @testset "Degenerate data: all points identical" begin
        # All points at origin
        data = zeros(3, 20)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=5)

        query = zeros(3)
        results = knn(tree, query, k=5)

        # All distances should be zero
        @test length(results) == 5
        for n in results
            @test n.distance == 0.0
        end
    end

    @testset "Degenerate data: collinear points" begin
        rng = StableRNG(108)
        # Points along x-axis
        data = zeros(3, 30)
        data[1, :] = randn(rng, 30)  # Only x varies

        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=5, rng=rng)

        query = [0.5, 0.0, 0.0]
        atria_results = knn(tree, query, k=5)
        brute_results = brute_knn(ps, query, 5)

        @test length(atria_results) == 5
        for i in 1:5
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end

    @testset "Very high dimension (D > 100)" begin
        rng = StableRNG(109)
        D = 150
        N = 200
        data = randn(rng, D, N)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=20, rng=rng)

        query = randn(StableRNG(110), D)
        atria_results = knn(tree, query, k=10)
        brute_results = brute_knn(ps, query, 10)

        @test length(atria_results) == 10
        for i in 1:10
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance rtol=1e-10
        end
    end
end

@testset "Cross-Validation Against NearestNeighbors.jl" begin
    @testset "KDTree comparison" begin
        rng = StableRNG(200)
        N, D, k = 500, 10, 20
        data = randn(rng, D, N)

        # Build both trees
        ps = PointSet(data, EuclideanMetric())
        atria_tree = ATRIATree(ps, min_points=30, rng=rng)
        kdtree = NN.KDTree(data)

        # Test multiple queries
        for trial in 1:10
            query = randn(StableRNG(200 + trial), D)

            # ATRIA results
            atria_results = knn(atria_tree, query, k=k)

            # KDTree results
            nn_indices, nn_distances = NN.knn(kdtree, query, k, true)

            # Sort both by distance for comparison
            atria_sorted = sort(atria_results, by=n->n.distance)
            nn_sorted_pairs = sort(collect(zip(nn_indices, nn_distances)), by=p->p[2])

            # Distances should match
            for i in 1:k
                @test atria_sorted[i].distance ≈ nn_sorted_pairs[i][2] rtol=1e-10
            end
        end
    end

    @testset "BallTree comparison" begin
        rng = StableRNG(300)
        N, D, k = 300, 15, 15
        data = randn(rng, D, N)

        # Build both trees
        ps = PointSet(data, EuclideanMetric())
        atria_tree = ATRIATree(ps, min_points=25, rng=rng)
        balltree = NN.BallTree(data)

        # Test multiple queries
        for trial in 1:10
            query = randn(StableRNG(300 + trial), D)

            # ATRIA results
            atria_results = knn(atria_tree, query, k=k)

            # BallTree results
            nn_indices, nn_distances = NN.knn(balltree, query, k, true)

            # Sort both by distance
            atria_sorted = sort(atria_results, by=n->n.distance)
            nn_sorted_pairs = sort(collect(zip(nn_indices, nn_distances)), by=p->p[2])

            # Distances should match
            for i in 1:k
                @test atria_sorted[i].distance ≈ nn_sorted_pairs[i][2] rtol=1e-10
            end
        end
    end

    @testset "Batch query consistency" begin
        rng = StableRNG(400)
        N, D, k = 200, 8, 10
        data = randn(rng, D, N)

        ps = PointSet(data, EuclideanMetric())
        atria_tree = ATRIATree(ps, min_points=20, rng=rng)
        kdtree = NN.KDTree(data)

        # Generate batch of queries
        n_queries = 50
        queries = randn(StableRNG(401), D, n_queries)

        # ATRIA batch results
        atria_batch = knn_batch(atria_tree, queries, k=k)

        # KDTree batch results
        nn_indices, nn_distances = NN.knn(kdtree, queries, k, true)

        @test length(atria_batch) == n_queries

        # Validate each query
        for i in 1:n_queries
            atria_sorted = sort(atria_batch[i], by=n->n.distance)
            nn_sorted_pairs = sort(collect(zip(nn_indices[i], nn_distances[i])), by=p->p[2])

            for j in 1:k
                @test atria_sorted[j].distance ≈ nn_sorted_pairs[j][2] rtol=1e-10
            end
        end
    end
end

@testset "Different Metrics Validation" begin
    @testset "MaximumMetric correctness" begin
        rng = StableRNG(500)
        N, D, k = 100, 5, 10
        data = randn(rng, D, N)

        ps = PointSet(data, MaximumMetric())
        tree = ATRIATree(ps, min_points=15, rng=rng)

        query = randn(StableRNG(501), D)

        atria_results = knn(tree, query, k=k)
        brute_results = brute_knn(ps, query, k)

        @test length(atria_results) == k
        for i in 1:k
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end

        # Cross-validate against NearestNeighbors.jl with Chebyshev metric
        kdtree = NN.KDTree(data, NN.Chebyshev())
        nn_indices, nn_distances = NN.knn(kdtree, query, k, true)

        atria_sorted = sort(atria_results, by=n->n.distance)
        nn_sorted_pairs = sort(collect(zip(nn_indices, nn_distances)), by=p->p[2])

        for i in 1:k
            @test atria_sorted[i].distance ≈ nn_sorted_pairs[i][2] rtol=1e-10
        end
    end

    @testset "ExponentiallyWeightedEuclidean correctness" begin
        rng = StableRNG(600)
        N, D, k = 80, 6, 8
        data = randn(rng, D, N)

        lambda = 0.9
        ps = PointSet(data, ExponentiallyWeightedEuclidean(lambda))
        tree = ATRIATree(ps, min_points=12, rng=rng)

        query = randn(StableRNG(601), D)

        atria_results = knn(tree, query, k=k)
        brute_results = brute_knn(ps, query, k)

        @test length(atria_results) == k
        for i in 1:k
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance rtol=1e-10
        end
    end
end

@testset "Embedded Time Series Validation" begin
    @testset "Basic embedding correctness" begin
        rng = StableRNG(700)
        ts_length = 300
        ts = randn(rng, ts_length)

        m, tau, k = 7, 2, 10

        ps = EmbeddedTimeSeries(ts, m, tau, EuclideanMetric())
        tree = ATRIATree(ps, min_points=20, rng=StableRNG(701))

        query = randn(StableRNG(702), m)

        atria_results = knn(tree, query, k=k)
        brute_results = brute_knn(ps, query, k)

        @test length(atria_results) == k
        for i in 1:k
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end

    @testset "Various embedding parameters" begin
        rng = StableRNG(800)
        ts = randn(rng, 500)

        # Test different (dim, delay) combinations
        configs = [(3, 1), (5, 2), (7, 3), (10, 5)]

        for (m, tau) in configs
            ps = EmbeddedTimeSeries(ts, m, tau, EuclideanMetric())
            tree = ATRIATree(ps, min_points=15, rng=StableRNG(801))

            query = randn(StableRNG(802), m)
            k = 5

            atria_results = knn(tree, query, k=k)
            brute_results = brute_knn(ps, query, k)

            @test length(atria_results) == k
            for i in 1:k
                @test atria_results[i].index == brute_results[i].index
                @test atria_results[i].distance ≈ brute_results[i].distance
            end
        end
    end
end

@testset "Range Search Validation" begin
    @testset "Range search vs NearestNeighbors.jl" begin
        rng = StableRNG(900)
        N, D = 200, 8
        data = randn(rng, D, N)

        ps = PointSet(data, EuclideanMetric())
        atria_tree = ATRIATree(ps, min_points=20, rng=rng)
        kdtree = NN.KDTree(data)

        query = randn(StableRNG(901), D)
        radius = 0.5

        # ATRIA range search
        atria_results = range_search(atria_tree, query, radius=radius)

        # NearestNeighbors.jl inrange
        nn_indices = NN.inrange(kdtree, query, radius, true)

        # Should find same number of points
        @test length(atria_results) == length(nn_indices)

        # Validate against brute force
        brute_results = brute_range_search(ps, query, radius)
        @test length(atria_results) == length(brute_results)

        # Check all points are within radius
        for n in atria_results
            @test n.distance <= radius
        end
    end

    @testset "Count range validation" begin
        rng = StableRNG(1000)
        N, D = 150, 6
        data = randn(rng, D, N)

        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=15, rng=rng)

        query = randn(StableRNG(1001), D)
        radius = 0.8

        atria_count = count_range(tree, query, radius=radius)
        brute_count = brute_count_range(ps, query, radius)

        @test atria_count == brute_count

        # Also verify against range_search length
        range_results = range_search(tree, query, radius=radius)
        @test atria_count == length(range_results)
    end
end

@testset "Numerical Stability" begin
    @testset "Very small distances" begin
        rng = StableRNG(1100)
        data = randn(rng, 3, 50) .* 1e-10  # Tiny scale
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10, rng=rng)

        query = randn(StableRNG(1101), 3) * 1e-10
        k = 5

        atria_results = knn(tree, query, k=k)
        brute_results = brute_knn(ps, query, k)

        @test length(atria_results) == k
        for i in 1:k
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance rtol=1e-6
        end
    end

    @testset "Very large distances" begin
        rng = StableRNG(1200)
        data = randn(rng, 3, 50) .* 1e10  # Huge scale
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10, rng=rng)

        query = randn(StableRNG(1201), 3) * 1e10
        k = 5

        atria_results = knn(tree, query, k=k)
        brute_results = brute_knn(ps, query, k)

        @test length(atria_results) == k
        for i in 1:k
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance rtol=1e-6
        end
    end
end

end # Correctness Validation testset

using Test
using ATRIANeighbors
using ATRIANeighbors: EuclideanMetric, MaximumMetric
using ATRIANeighbors: brute_knn, brute_range_search, brute_count_range
using ATRIANeighbors: knn_batch
using Random

@testset "Search Algorithms" begin

@testset "k-NN Search Correctness" begin
    # Test against brute force to verify correctness

    @testset "Small 2D dataset" begin
        Random.seed!(42)
        data = rand(2, 100)  # D×N: 2 dimensions, 100 points
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        # Test k=1
        query = rand(2)
        atria_results = knn(tree, query, k=1)
        brute_results = brute_knn(ps, query, 1)

        @test length(atria_results) == 1
        @test length(brute_results) == 1
        @test atria_results[1].index == brute_results[1].index
        @test atria_results[1].distance ≈ brute_results[1].distance

        # Check for duplicates
        indices = [n.index for n in atria_results]
        unique_count = length(unique(indices))
        @test length(indices) == unique_count
    end

    @testset "k=5 search" begin
        Random.seed!(43)
        data = rand(3, 50)  # D×N: 3 dimensions, 50 points
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=8)

        query = rand(3)
        atria_results = knn(tree, query, k=5)
        brute_results = brute_knn(ps, query, 5)

        @test length(atria_results) == 5
        @test length(brute_results) == 5

        # Check for duplicates
        indices = [n.index for n in atria_results]
        @test length(indices) == length(unique(indices))

        # Verify results match brute force
        for i in 1:5
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end

    @testset "k=10 search with various queries" begin
        Random.seed!(44)
        data = rand(4, 200)  # D×N: 4 dimensions, 200 points
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=15)

        for trial in 1:10
            query = rand(4)
            atria_results = knn(tree, query, k=10)
            brute_results = brute_knn(ps, query, 10)

            @test length(atria_results) == 10

            # Check for duplicates
            indices = [n.index for n in atria_results]
            @test length(indices) == length(unique(indices))

            # Verify results match brute force
            for i in 1:10
                @test atria_results[i].index == brute_results[i].index
                @test atria_results[i].distance ≈ brute_results[i].distance
            end
        end
    end

    @testset "Large k (k=50)" begin
        Random.seed!(45)
        data = rand(5, 500)  # D×N: 5 dimensions, 500 points
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=30)

        query = rand(5)
        atria_results = knn(tree, query, k=50)
        brute_results = brute_knn(ps, query, 50)

        @test length(atria_results) == 50

        # Check for duplicates
        indices = [n.index for n in atria_results]
        @test length(indices) == length(unique(indices))

        # Verify results match brute force
        for i in 1:50
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance atol=1e-10
        end
    end
end

@testset "k-NN with Exclusion Zones" begin
    Random.seed!(46)
    data = rand(2, 100)  # D×N
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIATree(ps, min_points=10)

    query = rand(2)

    # Exclude points 10-20
    results = knn(tree, query, k=5, exclude_range=(10, 20))

    @test length(results) == 5

    # Check no excluded points appear
    for n in results
        @test n.index < 10 || n.index > 20
    end

    # Check for duplicates
    indices = [n.index for n in results]
    @test length(indices) == length(unique(indices))
end

@testset "Range Search Correctness" begin
    @testset "Basic range search" begin
        Random.seed!(47)
        data = rand(2, 100)  # D×N
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        query = rand(2)
        radius = 0.3

        atria_results = range_search(tree, query, radius=radius)
        brute_results = brute_range_search(ps, query, radius)

        @test length(atria_results) == length(brute_results)

        # Check for duplicates
        indices = [n.index for n in atria_results]
        @test length(indices) == length(unique(indices))

        # Sort both for comparison
        sort!(atria_results, by=n->n.index)
        sort!(brute_results, by=n->n.index)

        for i in 1:length(atria_results)
            @test atria_results[i].index == brute_results[i].index
            @test atria_results[i].distance ≈ brute_results[i].distance
        end
    end
end

@testset "Count Range Correctness" begin
    Random.seed!(48)
    data = rand(3, 100)  # D×N
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIATree(ps, min_points=10)

    query = rand(3)
    radius = 0.5

    atria_count = count_range(tree, query, radius=radius)
    brute_count = brute_count_range(ps, query, radius)

    @test atria_count == brute_count
end

@testset "High Dimensional Search" begin
    Random.seed!(49)
    data = rand(20, 200)  # D×N: 20 dimensions, 200 points
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIATree(ps, min_points=20)

    query = rand(20)
    atria_results = knn(tree, query, k=10)
    brute_results = brute_knn(ps, query, 10)

    @test length(atria_results) == 10

    # Check for duplicates
    indices = [n.index for n in atria_results]
    @test length(indices) == length(unique(indices))

    for i in 1:10
        @test atria_results[i].index == brute_results[i].index
        @test atria_results[i].distance ≈ brute_results[i].distance
    end
end

@testset "Maximum Metric" begin
    Random.seed!(50)
    data = rand(3, 100)  # D×N
    ps = PointSet(data, MaximumMetric())
    tree = ATRIATree(ps, min_points=10)

    query = rand(3)
    atria_results = knn(tree, query, k=5)
    brute_results = brute_knn(ps, query, 5)

    @test length(atria_results) == 5

    # Check for duplicates
    indices = [n.index for n in atria_results]
    @test length(indices) == length(unique(indices))

    for i in 1:5
        @test atria_results[i].index == brute_results[i].index
        @test atria_results[i].distance ≈ brute_results[i].distance
    end
end

@testset "Embedded Time Series" begin
    Random.seed!(51)
    ts = rand(200)
    m = 5  # embedding dimension
    tau = 1  # embedding delay

    ps = EmbeddedTimeSeries(ts, m, tau, EuclideanMetric())
    tree = ATRIATree(ps, min_points=15)

    query = rand(m)
    atria_results = knn(tree, query, k=10)
    brute_results = brute_knn(ps, query, 10)

    @test length(atria_results) == 10

    # Check for duplicates
    indices = [n.index for n in atria_results]
    @test length(indices) == length(unique(indices))

    for i in 1:10
        @test atria_results[i].index == brute_results[i].index
        @test atria_results[i].distance ≈ brute_results[i].distance
    end
end

@testset "Batch k-NN Search" begin
    @testset "knn_batch with vector of queries" begin
        Random.seed!(52)
        data = rand(3, 100)  # D×N
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        queries = [rand(3) for _ in 1:20]
        batch_results = knn_batch(tree, queries, k=5)

        @test length(batch_results) == 20

        # Verify each result matches individual knn call
        for (i, query) in enumerate(queries)
            single_result = knn(tree, query, k=5)
            @test length(batch_results[i]) == length(single_result)
            for j in 1:5
                @test batch_results[i][j].index == single_result[j].index
                @test batch_results[i][j].distance ≈ single_result[j].distance
            end
        end
    end

    @testset "knn_batch with matrix input" begin
        Random.seed!(53)
        data = rand(4, 100)  # D×N: 4 dimensions, 100 points
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        # Matrix input: D×N_queries (each column is a query point)
        query_matrix = rand(4, 15)  # 15 query points in 4D
        batch_results = knn_batch(tree, query_matrix, k=5)

        @test length(batch_results) == 15

        # Verify against brute force
        for i in 1:15
            query = @view query_matrix[:, i]
            brute_results = brute_knn(ps, query, 5)
            @test length(batch_results[i]) == 5
            for j in 1:5
                @test batch_results[i][j].index == brute_results[j].index
                @test batch_results[i][j].distance ≈ brute_results[j].distance
            end
        end
    end

    @testset "knn with matrix input (convenience method)" begin
        Random.seed!(54)
        data = rand(3, 100)  # D×N
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        # Using knn directly with matrix should dispatch to knn_batch
        query_matrix = rand(3, 10)  # 10 queries in 3D
        results = knn(tree, query_matrix, k=3)

        @test length(results) == 10

        # Verify results
        for i in 1:10
            query = @view query_matrix[:, i]
            single_result = knn(tree, query, k=3)
            @test length(results[i]) == 3
            for j in 1:3
                @test results[i][j].index == single_result[j].index
                @test results[i][j].distance ≈ single_result[j].distance
            end
        end
    end

    @testset "knn with parallel=true (matrix input)" begin
        Random.seed!(55)
        data = rand(3, 100)  # D×N
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        query_matrix = rand(3, 25)  # 25 queries in 3D
        parallel_results = knn(tree, query_matrix, k=5, parallel=true)
        serial_results = knn(tree, query_matrix, k=5)

        @test length(parallel_results) == 25

        # Parallel results should match serial results
        for i in 1:25
            @test length(parallel_results[i]) == length(serial_results[i])
            for j in 1:5
                @test parallel_results[i][j].index == serial_results[i][j].index
                @test parallel_results[i][j].distance ≈ serial_results[i][j].distance
            end
        end
    end

    @testset "knn batch with track_stats" begin
        Random.seed!(56)
        data = rand(3, 100)  # D×N
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIATree(ps, min_points=10)

        query_matrix = rand(3, 5)  # 5 queries in 3D
        results, stats = knn(tree, query_matrix, k=5, track_stats=true)

        @test length(results) == 5
        @test length(stats) == 5

        for s in stats
            @test s.distance_calcs > 0
            @test s.f_k > 0.0
            @test s.f_k <= 1.0
        end
    end
end

end # Search Algorithms testset

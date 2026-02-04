using Test
using ATRIANeighbors: PointSet, EmbeddedTimeSeries, getpoint, distance
using ATRIANeighbors: EuclideanMetric, MaximumMetric

@testset "PointSet" begin
    @testset "Construction and size" begin
        # D×N layout: columns are points
        data = Float64[0 3 1;    # x coordinates
                       0 4 1]    # y coordinates  -> 3 points in 2D
        ps = PointSet(data, EuclideanMetric())

        @test size(ps) == (3, 2)
        @test size(ps)[1] == 3  # N points
        @test size(ps)[2] == 2  # D dimensions
    end

    @testset "Default metric constructor" begin
        data = Float64[0 1;
                       0 1]  # 2 points in 2D
        ps = PointSet(data)

        @test size(ps) == (2, 2)
        @test ps.metric isa EuclideanMetric
    end

    @testset "getpoint" begin
        # 3 points: [1,2], [3,4], [5,6]
        data = Float64[1 3 5;
                       2 4 6]
        ps = PointSet(data)

        p1 = getpoint(ps, 1)
        @test p1 == [1.0, 2.0]

        p2 = getpoint(ps, 2)
        @test p2 == [3.0, 4.0]

        p3 = getpoint(ps, 3)
        @test p3 == [5.0, 6.0]
    end

    @testset "distance between points in set" begin
        # 3 points: [0,0], [3,4], [0,0]
        data = Float64[0 3 0;
                       0 4 0]
        ps = PointSet(data, EuclideanMetric())

        # Distance from point 1 to point 2: sqrt(3^2 + 4^2) = 5
        @test distance(ps, 1, 2) ≈ 5.0

        # Distance from point 1 to point 3: both are [0, 0]
        @test distance(ps, 1, 3) ≈ 0.0

        # Symmetry
        @test distance(ps, 1, 2) ≈ distance(ps, 2, 1)
    end

    @testset "distance to external query point" begin
        # 2 points: [0,0], [1,1]
        data = Float64[0 1;
                       0 1]
        ps = PointSet(data, EuclideanMetric())

        query = [3.0, 4.0]

        # Distance from point 1 [0, 0] to query [3, 4]
        @test distance(ps, 1, query) ≈ 5.0

        # Distance from point 2 [1, 1] to query [3, 4]
        @test distance(ps, 2, query) ≈ sqrt(2^2 + 3^2)
    end

    @testset "distance with threshold" begin
        # 2 points: [0,0], [3,4]
        data = Float64[0 3;
                       0 4]
        ps = PointSet(data, EuclideanMetric())

        query = [0.0, 0.0]

        # Distance from point 2 to query is 5.0
        # With high threshold, should get exact distance
        @test distance(ps, 2, query, 10.0) ≈ 5.0

        # With low threshold, should exceed threshold
        @test distance(ps, 2, query, 3.0) > 3.0
    end

    @testset "Different metrics" begin
        # 2 points: [0,0], [3,4]
        data = Float64[0 3;
                       0 4]

        ps_euclidean = PointSet(data, EuclideanMetric())
        ps_maximum = PointSet(data, MaximumMetric())

        @test distance(ps_euclidean, 1, 2) ≈ 5.0
        @test distance(ps_maximum, 1, 2) ≈ 4.0  # max(3, 4)
    end

    @testset "Higher dimensions" begin
        # 4 points in 5D (D×N = 5×4)
        data = Float64[
            1 2 0 1;
            2 3 0 1;
            3 4 0 1;
            4 5 0 1;
            5 6 0 1
        ]
        ps = PointSet(data)

        @test size(ps) == (4, 5)

        # Distance from point 3 to point 4
        # sqrt(1^2 * 5) = sqrt(5)
        @test distance(ps, 3, 4) ≈ sqrt(5)
    end

    @testset "Single point" begin
        data = Float64[1; 2; 3;;]  # 1 point in 3D (3×1 matrix)
        ps = PointSet(data)

        @test size(ps) == (1, 3)
        @test distance(ps, 1, 1) ≈ 0.0
    end

    @testset "Many points" begin
        n = 1000
        d = 10
        data = randn(d, n)  # D×N layout
        ps = PointSet(data)

        @test size(ps) == (n, d)

        # Distance to itself is zero
        @test distance(ps, 1, 1) ≈ 0.0
        @test distance(ps, 500, 500) ≈ 0.0

        # Symmetry
        @test distance(ps, 1, 2) ≈ distance(ps, 2, 1)
        @test distance(ps, 100, 200) ≈ distance(ps, 200, 100)
    end
end

@testset "EmbeddedTimeSeries" begin
    @testset "Construction and size" begin
        # Time series: [1, 2, 3, 4, 5]
        # Embedding dim=3, delay=1
        # Points: [1,2,3], [2,3,4], [3,4,5] -> 3 points
        data = Float64[1, 2, 3, 4, 5]
        ps = EmbeddedTimeSeries(data, 3, 1, EuclideanMetric())

        @test size(ps) == (3, 3)
    end

    @testset "Default metric and delay" begin
        data = Float64[1, 2, 3, 4, 5]
        ps = EmbeddedTimeSeries(data, 3)  # Default delay=1, metric=Euclidean

        @test size(ps) == (3, 3)
        @test ps.metric isa EuclideanMetric
        @test ps.delay == 1
    end

    @testset "getpoint" begin
        data = Float64[1, 2, 3, 4, 5]
        ps = EmbeddedTimeSeries(data, 3, 1)

        p1 = getpoint(ps, 1)
        @test p1 == [1.0, 2.0, 3.0]

        p2 = getpoint(ps, 2)
        @test p2 == [2.0, 3.0, 4.0]

        p3 = getpoint(ps, 3)
        @test p3 == [3.0, 4.0, 5.0]
    end

    @testset "Different delay values" begin
        data = Float64[1, 2, 3, 4, 5, 6, 7]

        # delay = 1: [1,2,3], [2,3,4], [3,4,5], [4,5,6], [5,6,7]
        ps1 = EmbeddedTimeSeries(data, 3, 1)
        @test size(ps1) == (5, 3)
        @test getpoint(ps1, 1) == [1.0, 2.0, 3.0]

        # delay = 2: [1,3,5], [2,4,6], [3,5,7]
        ps2 = EmbeddedTimeSeries(data, 3, 2)
        @test size(ps2) == (3, 3)
        @test getpoint(ps2, 1) == [1.0, 3.0, 5.0]
        @test getpoint(ps2, 2) == [2.0, 4.0, 6.0]
        @test getpoint(ps2, 3) == [3.0, 5.0, 7.0]
    end

    @testset "Number of embedded points" begin
        # Formula: N = length(data) - (dim - 1) * delay

        data = Float64[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        ps1 = EmbeddedTimeSeries(data, 2, 1)  # 10 - 1 = 9 points
        @test size(ps1)[1] == 9

        ps2 = EmbeddedTimeSeries(data, 3, 1)  # 10 - 2 = 8 points
        @test size(ps2)[1] == 8

        ps3 = EmbeddedTimeSeries(data, 5, 2)  # 10 - 8 = 2 points
        @test size(ps3)[1] == 2

        ps4 = EmbeddedTimeSeries(data, 10, 1)  # 10 - 9 = 1 point
        @test size(ps4)[1] == 1
    end

    @testset "distance between embedded points" begin
        data = Float64[0, 1, 2, 3, 4]
        ps = EmbeddedTimeSeries(data, 2, 1)
        # Points: [0,1], [1,2], [2,3], [3,4]

        # Distance from [0,1] to [1,2]: sqrt((1-0)^2 + (2-1)^2) = sqrt(2)
        @test distance(ps, 1, 2) ≈ sqrt(2)

        # Distance from [0,1] to [3,4]: sqrt(9 + 9) = sqrt(18)
        @test distance(ps, 1, 4) ≈ sqrt(18)

        # Distance to itself
        @test distance(ps, 1, 1) ≈ 0.0
    end

    @testset "distance to external query" begin
        data = Float64[1, 2, 3, 4]
        ps = EmbeddedTimeSeries(data, 2, 1)
        # Points: [1,2], [2,3], [3,4]

        query = [0.0, 0.0]

        # Distance from [1,2] to [0,0]: sqrt(1 + 4) = sqrt(5)
        @test distance(ps, 1, query) ≈ sqrt(5)

        # Distance from [3,4] to [0,0]: sqrt(9 + 16) = 5
        @test distance(ps, 3, query) ≈ 5.0
    end

    @testset "distance with threshold" begin
        data = Float64[0, 1, 2, 3]
        ps = EmbeddedTimeSeries(data, 2, 1)
        # Points: [0,1], [1,2], [2,3]

        query = [0.0, 0.0]

        # Distance from [2,3] to [0,0]: sqrt(4 + 9) = sqrt(13) ≈ 3.6
        # With high threshold
        @test distance(ps, 3, query, 10.0) ≈ sqrt(13)

        # With low threshold
        @test distance(ps, 3, query, 2.0) > 2.0
    end

    @testset "Input validation" begin
        # dim < 1
        @test_throws ArgumentError EmbeddedTimeSeries(Float64[1, 2, 3], 0, 1)

        # delay < 1
        @test_throws ArgumentError EmbeddedTimeSeries(Float64[1, 2, 3], 2, 0)

        # Not enough data
        @test_throws ArgumentError EmbeddedTimeSeries(Float64[1, 2], 5, 1)
        @test_throws ArgumentError EmbeddedTimeSeries(Float64[1, 2, 3], 2, 3)
    end

    @testset "Edge cases" begin
        # Minimum embedding
        data = Float64[1, 2]
        ps = EmbeddedTimeSeries(data, 2, 1)
        @test size(ps) == (1, 2)
        @test getpoint(ps, 1) == [1.0, 2.0]

        # dim = 1 (no real embedding)
        data = Float64[1, 2, 3, 4]
        ps = EmbeddedTimeSeries(data, 1, 1)
        @test size(ps) == (4, 1)
        @test getpoint(ps, 1) == [1.0]
        @test getpoint(ps, 2) == [2.0]
    end

    @testset "Consistency with PointSet" begin
        # Create embedded time series
        data = Float64[1, 2, 3, 4, 5]
        ps_embedded = EmbeddedTimeSeries(data, 3, 1)

        # Create equivalent PointSet manually (D×N layout: 3×3)
        matrix_data = Float64[
            1 2 3;   # dim 1
            2 3 4;   # dim 2
            3 4 5    # dim 3
        ]
        ps_matrix = PointSet(matrix_data)

        # Sizes should match
        @test size(ps_embedded) == size(ps_matrix)

        # Points should match
        for i in 1:3
            @test getpoint(ps_embedded, i) == getpoint(ps_matrix, i)
        end

        # Distances should match
        for i in 1:3
            for j in 1:3
                @test distance(ps_embedded, i, j) ≈ distance(ps_matrix, i, j)
            end
        end
    end

    @testset "Large time series" begin
        # Generate synthetic time series
        n = 10000
        data = sin.(0.1 * (1:n)) + 0.1 * randn(n)

        dim = 10
        delay = 3
        ps = EmbeddedTimeSeries(data, dim, delay)

        expected_points = n - (dim - 1) * delay
        @test size(ps)[1] == expected_points
        @test size(ps)[2] == dim

        # Test a few distances
        @test distance(ps, 1, 1) ≈ 0.0
        @test distance(ps, 1, 2) >= 0.0
        @test distance(ps, 100, 200) ≈ distance(ps, 200, 100)
    end
end

@testset "PointSet vs EmbeddedTimeSeries equivalence" begin
    # This test verifies that EmbeddedTimeSeries gives same results
    # as manually creating a PointSet with embedded vectors

    data = Float64[1, 4, 2, 8, 5, 7, 1, 3]
    dim = 3
    delay = 2

    ps_embedded = EmbeddedTimeSeries(data, dim, delay)

    # Manually create embedded vectors (D×N layout)
    n_points = length(data) - (dim - 1) * delay
    matrix = zeros(dim, n_points)
    for i in 1:n_points
        for d in 1:dim
            matrix[d, i] = data[i + (d - 1) * delay]
        end
    end
    ps_matrix = PointSet(matrix)

    @test size(ps_embedded) == size(ps_matrix)

    # Test all pairwise distances
    for i in 1:n_points
        for j in 1:n_points
            @test distance(ps_embedded, i, j) ≈ distance(ps_matrix, i, j)
        end
    end

    # Test distances to external query
    query = [5.0, 6.0, 7.0]
    for i in 1:n_points
        @test distance(ps_embedded, i, query) ≈ distance(ps_matrix, i, query)
    end
end

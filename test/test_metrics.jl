using Test
using ATRIANeighbors: EuclideanMetric, SquaredEuclideanMetric, MaximumMetric
using ATRIANeighbors: ExponentiallyWeightedEuclidean, distance

@testset "Metrics" begin
    @testset "EuclideanMetric" begin
        metric = EuclideanMetric()

        @testset "Known distances" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]
            @test distance(metric, p1, p2) ≈ 5.0

            p1 = [1.0, 2.0, 3.0]
            p2 = [1.0, 2.0, 3.0]
            @test distance(metric, p1, p2) ≈ 0.0

            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 1.0, 1.0]
            @test distance(metric, p1, p2) ≈ sqrt(3)
        end

        @testset "Symmetry" begin
            p1 = [1.0, 2.0, 3.0]
            p2 = [4.0, 5.0, 6.0]
            @test distance(metric, p1, p2) ≈ distance(metric, p2, p1)
        end

        @testset "Triangle inequality" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]
            p3 = [6.0, 0.0]

            d12 = distance(metric, p1, p2)
            d23 = distance(metric, p2, p3)
            d13 = distance(metric, p1, p3)

            @test d13 <= d12 + d23
        end

        @testset "Partial distance with threshold" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]  # distance = 5.0

            # Threshold above distance: should return exact distance
            @test distance(metric, p1, p2, 10.0) ≈ 5.0

            # Threshold below distance: should return value > threshold
            result = distance(metric, p1, p2, 3.0)
            @test result > 3.0
        end

        @testset "Edge cases" begin
            # Identical points
            p = [1.0, 2.0, 3.0]
            @test distance(metric, p, p) ≈ 0.0

            # Single dimension
            p1 = [0.0]
            p2 = [5.0]
            @test distance(metric, p1, p2) ≈ 5.0

            # High dimensional
            n = 100
            p1 = zeros(n)
            p2 = ones(n)
            @test distance(metric, p1, p2) ≈ sqrt(n)
        end
    end

    @testset "SquaredEuclideanMetric" begin
        metric = SquaredEuclideanMetric()

        @testset "Known distances" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]
            @test distance(metric, p1, p2) ≈ 25.0  # 3^2 + 4^2

            p1 = [1.0, 2.0, 3.0]
            p2 = [1.0, 2.0, 3.0]
            @test distance(metric, p1, p2) ≈ 0.0

            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 1.0, 1.0]
            @test distance(metric, p1, p2) ≈ 3.0
        end

        @testset "Symmetry" begin
            p1 = [1.0, 2.0, 3.0]
            p2 = [4.0, 5.0, 6.0]
            @test distance(metric, p1, p2) ≈ distance(metric, p2, p1)
        end

        @testset "Partial distance with threshold" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]  # squared distance = 25.0

            # Threshold above distance
            @test distance(metric, p1, p2, 30.0) ≈ 25.0

            # Threshold below distance
            result = distance(metric, p1, p2, 20.0)
            @test result > 20.0
        end

        @testset "Relation to Euclidean" begin
            p1 = [1.0, 2.0, 3.0]
            p2 = [4.0, 5.0, 6.0]

            euclidean_dist = distance(EuclideanMetric(), p1, p2)
            squared_dist = distance(SquaredEuclideanMetric(), p1, p2)

            @test squared_dist ≈ euclidean_dist^2
        end
    end

    @testset "MaximumMetric" begin
        metric = MaximumMetric()

        @testset "Known distances" begin
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]
            @test distance(metric, p1, p2) ≈ 4.0  # max(3, 4)

            p1 = [1.0, 2.0, 3.0]
            p2 = [1.0, 2.0, 3.0]
            @test distance(metric, p1, p2) ≈ 0.0

            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 5.0, 2.0]
            @test distance(metric, p1, p2) ≈ 5.0
        end

        @testset "Symmetry" begin
            p1 = [1.0, 2.0, 3.0]
            p2 = [4.0, 5.0, 6.0]
            @test distance(metric, p1, p2) ≈ distance(metric, p2, p1)
        end

        @testset "Triangle inequality" begin
            p1 = [0.0, 0.0]
            p2 = [1.0, 1.0]
            p3 = [2.0, 2.0]

            d12 = distance(metric, p1, p2)
            d23 = distance(metric, p2, p3)
            d13 = distance(metric, p1, p3)

            @test d13 <= d12 + d23
        end

        @testset "Partial distance with threshold" begin
            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 5.0, 2.0]  # max distance = 5.0

            # Threshold above distance
            @test distance(metric, p1, p2, 10.0) ≈ 5.0

            # Threshold below distance
            result = distance(metric, p1, p2, 3.0)
            @test result > 3.0
        end

        @testset "Edge cases" begin
            # All dimensions equal difference
            p1 = [0.0, 0.0, 0.0]
            p2 = [2.0, 2.0, 2.0]
            @test distance(metric, p1, p2) ≈ 2.0

            # One dominant dimension
            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 10.0, 1.0]
            @test distance(metric, p1, p2) ≈ 10.0

            # Negative differences
            p1 = [5.0, 5.0]
            p2 = [0.0, 8.0]
            @test distance(metric, p1, p2) ≈ 5.0  # max(|5-0|, |5-8|)
        end
    end

    @testset "ExponentiallyWeightedEuclidean" begin
        @testset "Construction" begin
            metric = ExponentiallyWeightedEuclidean(0.5)
            @test metric.lambda == 0.5

            metric = ExponentiallyWeightedEuclidean(1.0)
            @test metric.lambda == 1.0

            # Invalid lambda values
            @test_throws ArgumentError ExponentiallyWeightedEuclidean(0.0)
            @test_throws ArgumentError ExponentiallyWeightedEuclidean(-0.5)
            @test_throws ArgumentError ExponentiallyWeightedEuclidean(1.5)
        end

        @testset "Known distances" begin
            metric = ExponentiallyWeightedEuclidean(1.0)
            # Lambda = 1.0 should be equivalent to standard Euclidean
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]
            @test distance(metric, p1, p2) ≈ 5.0

            # Lambda < 1.0: later dimensions weighted less
            metric = ExponentiallyWeightedEuclidean(0.5)
            p1 = [0.0, 0.0]
            p2 = [2.0, 2.0]
            # d^2 = 1.0 * 4 + 0.5 * 4 = 6
            @test distance(metric, p1, p2) ≈ sqrt(6.0)
        end

        @testset "Symmetry" begin
            metric = ExponentiallyWeightedEuclidean(0.8)
            p1 = [1.0, 2.0, 3.0]
            p2 = [4.0, 5.0, 6.0]
            @test distance(metric, p1, p2) ≈ distance(metric, p2, p1)
        end

        @testset "Weighting effect" begin
            metric = ExponentiallyWeightedEuclidean(0.1)
            # First dimension should dominate
            p1 = [0.0, 0.0, 0.0]
            p2 = [1.0, 10.0, 10.0]

            dist = distance(metric, p1, p2)
            # First dimension contributes 1.0 * 1^2 = 1
            # Second dimension contributes 0.1 * 100 = 10
            # Third dimension contributes 0.01 * 100 = 1
            # Total = 12, sqrt = ~3.46
            @test dist ≈ sqrt(12.0)

            # Compare to equal differences: should be different due to weighting
            p3 = [0.0, 0.0, 0.0]
            p4 = [10.0, 1.0, 1.0]
            dist2 = distance(metric, p3, p4)
            @test dist2 > dist  # First dimension weighted more
        end

        @testset "Partial distance with threshold" begin
            metric = ExponentiallyWeightedEuclidean(0.5)
            p1 = [0.0, 0.0]
            p2 = [3.0, 4.0]

            full_dist = distance(metric, p1, p2)

            # Threshold above distance
            @test distance(metric, p1, p2, full_dist + 1.0) ≈ full_dist

            # Threshold below distance
            result = distance(metric, p1, p2, 1.0)
            @test result > 1.0
        end

        @testset "Edge cases" begin
            metric = ExponentiallyWeightedEuclidean(0.9)

            # Identical points
            p = [1.0, 2.0, 3.0]
            @test distance(metric, p, p) ≈ 0.0

            # Zero in first dimension dominates with high lambda
            metric_high = ExponentiallyWeightedEuclidean(0.99)
            p1 = [0.0, 0.0]
            p2 = [1.0, 100.0]
            dist = distance(metric_high, p1, p2)
            # Should be close to sqrt(1 + 0.99*10000) ≈ sqrt(9901) ≈ 99.5
            @test dist ≈ sqrt(1.0 + 0.99 * 10000.0)
        end
    end

    @testset "Metric comparisons" begin
        p1 = [0.0, 0.0]
        p2 = [3.0, 4.0]

        euclidean_dist = distance(EuclideanMetric(), p1, p2)
        squared_dist = distance(SquaredEuclideanMetric(), p1, p2)
        maximum_dist = distance(MaximumMetric(), p1, p2)

        @test euclidean_dist ≈ 5.0
        @test squared_dist ≈ 25.0
        @test maximum_dist ≈ 4.0

        # Maximum distance <= Euclidean distance (in general)
        @test maximum_dist <= euclidean_dist
    end

    @testset "Early termination performance property" begin
        # This is more of a conceptual test - early termination should
        # still give us the information we need (distance > threshold)

        metric = EuclideanMetric()
        p1 = zeros(1000)
        p2 = ones(1000)

        full_dist = distance(metric, p1, p2)
        @test full_dist ≈ sqrt(1000)

        # With low threshold, should terminate early
        partial_result = distance(metric, p1, p2, 1.0)
        @test partial_result > 1.0
        # We don't know the exact value, but it should be > threshold
    end
end

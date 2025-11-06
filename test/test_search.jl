using Test
using ATRIANeighbors
using Random

# Simple brute force reference implementations for correctness testing
# These use ATRIANeighbors' own distance functions to ensure identical results
# For performance comparisons, see benchmarks which use NearestNeighbors.jl

function brute_knn(ps::AbstractPointSet, query_point, k::Int; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    # Calculate all distances using ATRIANeighbors' metrics
    distances = zeros(N)
    for i in 1:N
        distances[i] = distance(ps, i, query_point)
    end

    # Get sorted indices
    indices = sortperm(distances)

    # Filter out self if needed
    if exclude_self && query_idx > 0
        indices = filter(i -> i != query_idx, indices)
    end

    # Take first k
    neighbors = [ATRIANeighbors.Neighbor(indices[i], distances[indices[i]]) for i in 1:min(k, length(indices))]

    return neighbors
end

function brute_range_search(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    # Collect all neighbors within radius
    neighbors = ATRIANeighbors.Neighbor[]

    for i in 1:N
        # Skip self if requested
        if exclude_self && i == query_idx
            continue
        end

        d = distance(ps, i, query_point)
        if d <= radius
            push!(neighbors, ATRIANeighbors.Neighbor(i, d))
        end
    end

    # Sort by distance
    sort!(neighbors, by=n->n.distance)

    return neighbors
end

function brute_count_range(ps::AbstractPointSet, query_point, radius::Float64; exclude_self::Bool=false)
    N, D = size(ps)

    # Handle the case where query_point is an index (for exclude_self)
    if exclude_self && query_point isa Integer
        query_idx = query_point
        query_point = getpoint(ps, query_idx)
    else
        query_idx = -1
    end

    count = 0

    for i in 1:N
        # Skip self if requested
        if exclude_self && i == query_idx
            continue
        end

        d = distance(ps, i, query_point)
        if d <= radius
            count += 1
        end
    end

    return count
end

@testset "Search Algorithms" begin

@testset "k-NN Search Correctness" begin
    # Test against brute force to verify correctness

    @testset "Small 2D dataset" begin
        Random.seed!(42)
        data = rand(100, 2)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=10)

        # Test k=1
        query = rand(2)
        atria_results = ATRIANeighbors.knn(tree, query, k=1)
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
        data = rand(50, 3)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=8)

        query = rand(3)
        atria_results = ATRIANeighbors.knn(tree, query, k=5)
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
        data = rand(200, 4)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=15)

        for trial in 1:10
            query = rand(4)
            atria_results = ATRIANeighbors.knn(tree, query, k=10)
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
        data = rand(500, 5)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=30)

        query = rand(5)
        atria_results = ATRIANeighbors.knn(tree, query, k=50)
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
    data = rand(100, 2)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

    query = rand(2)

    # Exclude points 10-20
    results = ATRIANeighbors.knn(tree, query, k=5, exclude_range=(10, 20))

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
        data = rand(100, 2)
        ps = PointSet(data, EuclideanMetric())
        tree = ATRIA(ps, min_points=10)

        query = rand(2)
        radius = 0.3

        atria_results = range_search(tree, query, radius)
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
    data = rand(100, 3)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=10)

    query = rand(3)
    radius = 0.5

    atria_count = count_range(tree, query, radius)
    brute_count = brute_count_range(ps, query, radius)

    @test atria_count == brute_count
end

@testset "High Dimensional Search" begin
    Random.seed!(49)
    data = rand(200, 20)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=20)

    query = rand(20)
    atria_results = ATRIANeighbors.knn(tree, query, k=10)
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
    data = rand(100, 3)
    ps = PointSet(data, MaximumMetric())
    tree = ATRIA(ps, min_points=10)

    query = rand(3)
    atria_results = ATRIANeighbors.knn(tree, query, k=5)
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
    tree = ATRIA(ps, min_points=15)

    query = rand(m)
    atria_results = ATRIANeighbors.knn(tree, query, k=10)
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

end # Search Algorithms testset

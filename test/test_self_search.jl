# Regression test for self-search bug (issue #XX)
# Bug: Querying a point in the dataset failed to return itself with distance=0
# Root cause: Degenerate partition edge case didn't update distances

using Test
using ATRIANeighbors
using Random

@testset "Self-search (query points in dataset)" begin
    # Test 1: Simple synthetic data
    @testset "Simple 2D data" begin
        data = Float64[1.0 2.0 3.0 4.0 5.0;
                       1.0 2.0 3.0 4.0 5.0]
        tree = ATRIATree(data)

        for i in 1:5
            query = data[:, i]
            neighbors = knn(tree, query, k=1)
            @test neighbors[1].index == i
            @test neighbors[1].distance == 0.0
        end
    end

    # Test 2: High-dimensional Lorenz system (original failing case)
    @testset "Lorenz with delay embedding" begin
        function generate_lorenz63(N; σ=10.0, ρ=28.0, β=8/3, dt=0.01)
            x, y, z = 1.0, 1.0, 1.0
            points = zeros(3, N)
            for i in 1:N
                points[1, i] = x
                points[2, i] = y
                points[3, i] = z
                x += dt * σ * (y - x)
                y += dt * (x * (ρ - z) - y)
                z += dt * (x * y - β * z)
            end
            return points
        end

        Random.seed!(5679)
        N = 10000
        points = generate_lorenz63(N)
        timeseries = points[1, :]

        # Create delay embedding
        D_emb = 20
        N_states = N - D_emb + 1
        states = zeros(D_emb, N_states)
        for d in 1:D_emb
            states[d, :] = timeseries[d:N_states+d-1]
        end

        tree = ATRIATree(states)

        # Test specific point that failed before the fix
        query = states[:, 877]
        neighbors = knn(tree, query, k=1)
        @test neighbors[1].index == 877
        @test neighbors[1].distance == 0.0

        # Test batch query - all points should find themselves
        neighbors_list = knn(tree, states, k=1)
        for i in 1:N_states
            @test neighbors_list[i][1].index == i
            @test neighbors_list[i][1].distance == 0.0
        end
    end

    # Test 3: Random high-dimensional data
    @testset "Random high-D data" begin
        Random.seed!(42)
        data = randn(10, 100)
        tree = ATRIATree(data)

        # Batch query all points
        neighbors_list = knn(tree, data, k=1)

        failures = []
        for i in 1:100
            if neighbors_list[i][1].index != i || neighbors_list[i][1].distance != 0.0
                push!(failures, i)
            end
        end

        @test isempty(failures)
    end
end

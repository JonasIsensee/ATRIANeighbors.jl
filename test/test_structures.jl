using Test
using ATRIANeighbors: Neighbor, Cluster, SearchItem, SortedNeighborTable
using ATRIANeighbors: is_terminal, init_search!, finish_search

@testset "Neighbor" begin
    @testset "Construction and fields" begin
        n = Neighbor(5, 2.5)
        @test n.index == 5
        @test n.distance == 2.5
    end

    @testset "Comparison operators" begin
        n1 = Neighbor(1, 1.0)
        n2 = Neighbor(2, 2.0)
        n3 = Neighbor(1, 1.0)

        @test n1 < n2
        @test !(n2 < n1)
        @test n1 == n3
        @test n1 != n2
    end

    @testset "Sorting" begin
        neighbors = [
            Neighbor(1, 3.0),
            Neighbor(2, 1.0),
            Neighbor(3, 2.0)
        ]
        sort!(neighbors)
        @test neighbors[1].distance == 1.0
        @test neighbors[2].distance == 2.0
        @test neighbors[3].distance == 3.0
    end
end

@testset "Cluster" begin
    @testset "Terminal node construction" begin
        c = Cluster(10, 5.0, 1.0, 0, 100)
        @test c.center == 10
        @test is_terminal(c)
        @test abs(c.Rmax) == 5.0
        @test c.g_min == 1.0
        @test c.start == 0
        @test c.length == 100
        @test c.left === nothing
        @test c.right === nothing
    end

    @testset "Root node construction" begin
        c = Cluster(5, 10.0)
        @test c.center == 5
        @test !is_terminal(c)
        @test c.Rmax == 10.0
        @test c.g_min == 0.0
    end

    @testset "Internal node construction" begin
        left = Cluster(1, 2.0, 0.5, 0, 50)
        right = Cluster(2, 3.0, 0.5, 50, 50)
        parent = Cluster(5, 10.0, 0.0, left, right)

        @test parent.center == 5
        @test !is_terminal(parent)
        @test parent.Rmax == 10.0
        @test parent.left === left
        @test parent.right === right
    end

    @testset "is_terminal checks" begin
        terminal = Cluster(1, 5.0, 1.0, 0, 100)
        root = Cluster(1, 5.0)
        left = Cluster(2, 3.0, 0.5, 0, 50)
        right = Cluster(3, 3.0, 0.5, 50, 50)
        internal = Cluster(1, 10.0, 0.0, left, right)

        @test is_terminal(terminal)
        @test !is_terminal(root)
        @test !is_terminal(internal)
        @test is_terminal(left)
        @test is_terminal(right)
    end
end

@testset "SearchItem" begin
    @testset "Root SearchItem construction" begin
        cluster = Cluster(5, 10.0)
        item = SearchItem(cluster, 5.0)

        @test item.cluster === cluster
        @test item.dist == 5.0
        @test item.d_min == 0.0  # max(0, 5 - 10)
        @test item.d_max == 15.0  # 5 + 10
    end

    @testset "Child SearchItem construction" begin
        # Create parent SearchItem first
        parent_cluster = Cluster(10, 20.0)
        parent = SearchItem(parent_cluster, 15.0)  # d_min=0, d_max=35

        # Create child SearchItem
        cluster = Cluster(1, 5.0, 2.0, 0, 50)
        item = SearchItem(cluster, 8.0, 12.0, parent)

        @test item.cluster === cluster
        @test item.dist == 8.0
        @test item.dist_brother == 12.0
        # d_min_local = max(0, 0.5*(8-12+2)) = max(0, -1) = 0
        # d_min = max(0, max(8-5, parent.d_min)) = max(0, max(3, 0)) = 3
        @test item.d_min == 3.0
        # d_max = min(parent.d_max, 8+5) = min(35, 13) = 13
        @test item.d_max == 13.0
    end

    @testset "SearchItem comparison" begin
        c1 = Cluster(1, 5.0)
        c2 = Cluster(2, 3.0)

        item1 = SearchItem(c1, 10.0)
        item2 = SearchItem(c2, 1.0)

        # item2 should be processed first (smaller d_min)
        @test item2 < item1
        @test !(item1 < item2)
    end
end

@testset "SortedNeighborTable" begin
    @testset "Initialization" begin
        table = SortedNeighborTable(5)
        @test table.k == 5
        @test length(table.neighbors) == 0
        @test table.high_dist == Inf
    end

    @testset "Insert with room" begin
        table = SortedNeighborTable(3)

        insert!(table, Neighbor(1, 3.0))
        @test length(table.neighbors) == 1
        @test table.high_dist == Inf

        insert!(table, Neighbor(2, 1.0))
        @test length(table.neighbors) == 2
        @test table.high_dist == Inf

        insert!(table, Neighbor(3, 2.0))
        @test length(table.neighbors) == 3
        @test table.high_dist == 3.0  # Max of {3.0, 1.0, 2.0}
    end

    @testset "Insert when full" begin
        table = SortedNeighborTable(3)

        insert!(table, Neighbor(1, 3.0))
        insert!(table, Neighbor(2, 2.0))
        insert!(table, Neighbor(3, 4.0))
        @test length(table.neighbors) == 3
        @test table.high_dist == 4.0

        # Insert better neighbor
        insert!(table, Neighbor(4, 1.0))
        @test length(table.neighbors) == 3
        @test table.high_dist == 3.0  # 4.0 was replaced

        neighbors = finish_search(table)
        @test length(neighbors) == 3
        @test neighbors[1].distance == 1.0
        @test neighbors[2].distance == 2.0
        @test neighbors[3].distance == 3.0
    end

    @testset "Insert worse neighbor when full" begin
        table = SortedNeighborTable(3)

        insert!(table, Neighbor(1, 1.0))
        insert!(table, Neighbor(2, 2.0))
        insert!(table, Neighbor(3, 3.0))
        @test table.high_dist == 3.0

        # Try to insert worse neighbor
        insert!(table, Neighbor(4, 5.0))
        @test length(table.neighbors) == 3
        @test table.high_dist == 3.0  # Unchanged

        neighbors = finish_search(table)
        @test length(neighbors) == 3
        @test neighbors[3].distance == 3.0  # Not 5.0
    end

    @testset "finish_search returns sorted neighbors" begin
        table = SortedNeighborTable(5)

        insert!(table, Neighbor(1, 5.0))
        insert!(table, Neighbor(2, 2.0))
        insert!(table, Neighbor(3, 4.0))
        insert!(table, Neighbor(4, 1.0))
        insert!(table, Neighbor(5, 3.0))

        neighbors = finish_search(table)
        @test length(neighbors) == 5

        # Check sorted order
        for i in 1:4
            @test neighbors[i].distance <= neighbors[i+1].distance
        end
        @test neighbors[1].distance == 1.0
        @test neighbors[5].distance == 5.0
    end

    @testset "init_search! resets table" begin
        table = SortedNeighborTable(3)

        insert!(table, Neighbor(1, 1.0))
        insert!(table, Neighbor(2, 2.0))
        @test length(table.neighbors) == 2

        init_search!(table, 5)
        @test table.k == 5
        @test length(table.neighbors) == 0
        @test table.high_dist == Inf
    end

    @testset "k=1 case" begin
        table = SortedNeighborTable(1)

        insert!(table, Neighbor(1, 5.0))
        @test table.high_dist == 5.0

        insert!(table, Neighbor(2, 3.0))
        @test table.high_dist == 3.0

        insert!(table, Neighbor(3, 7.0))
        @test table.high_dist == 3.0

        neighbors = finish_search(table)
        @test length(neighbors) == 1
        @test neighbors[1].index == 2
        @test neighbors[1].distance == 3.0
    end

    @testset "Large k test" begin
        k = 100
        table = SortedNeighborTable(k)

        # Insert k neighbors in random order
        for i in 1:k
            insert!(table, Neighbor(i, Float64(k - i + 1)))
        end

        neighbors = finish_search(table)
        @test length(neighbors) == k

        # Check sorted
        for i in 1:k-1
            @test neighbors[i].distance <= neighbors[i+1].distance
        end
    end
end

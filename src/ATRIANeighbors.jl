module ATRIANeighbors

# Core data structures
include("structures.jl")
export Neighbor, Cluster, SearchItem, SortedNeighborTable
export is_terminal, init_search!, finish_search

# Distance metrics
include("metrics.jl")
export Metric
export EuclideanMetric, SquaredEuclideanMetric, MaximumMetric
export ExponentiallyWeightedEuclidean
export Euclidean, SquaredEuclidean, Maximum, Chebyshev, ChebyshevMetric
export distance

# Point set abstractions
include("pointsets.jl")
export AbstractPointSet, PointSet, EmbeddedTimeSeries
export getpoint

# ATRIA tree construction
include("tree.jl")
export ATRIATree, ATRIA
export tree_depth, count_nodes, average_terminal_size, print_tree_stats

# MinHeap for efficient priority queue operations
include("minheap.jl")

# Search algorithms
include("search.jl")
export knn, range_search, count_range

# Optimized search (allocation-free)
include("search_optimized.jl")
export knn_optimized, SearchContext

# Brute force reference implementation
include("brute.jl")
export brute_knn, brute_knn_batch, brute_range_search, brute_count_range

end # module ATRIANeighbors

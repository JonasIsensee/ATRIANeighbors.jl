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

end # module ATRIANeighbors

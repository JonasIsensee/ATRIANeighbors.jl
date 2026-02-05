module ATRIANeighbors

# Core data structures
include("structures.jl")
export Neighbor

# Distance metrics
include("metrics.jl")

# Point set abstractions
include("pointsets.jl")
export AbstractPointSet, PointSet, EmbeddedTimeSeries
export getpoint

# ATRIA tree construction
include("tree.jl")
export ATRIATree
export print_tree_stats

# MinHeap for efficient priority queue operations
include("minheap.jl")

# Range search and count range
include("search.jl")
export range_search, count_range

# Main search implementation (allocation-optimized)
include("search_optimized.jl")
export knn, SearchContext

# Brute force reference implementation (not exported — use ATRIANeighbors.brute_knn etc.)
include("brute.jl")

end # module ATRIANeighbors

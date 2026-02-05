using Test
using ATRIANeighbors

@testset "ATRIANeighbors.jl" begin
    # Package quality checks
    include("test_aqua.jl")

    # Core functionality tests
    include("test_structures.jl")
    include("test_metrics.jl")
    include("test_pointsets.jl")
    include("test_tree.jl")
    include("test_search.jl")

    # Comprehensive correctness validation
    include("test_correctness.jl")
end

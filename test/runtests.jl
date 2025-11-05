using Test
using ATRIANeighbors

@testset "ATRIANeighbors.jl" begin
    include("test_structures.jl")
    include("test_metrics.jl")
    include("test_pointsets.jl")
end

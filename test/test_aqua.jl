using Test
using Aqua
using ATRIANeighbors

@testset "Aqua.jl Quality Checks" begin
    @testset "Method ambiguities" begin
        # Check for method ambiguities
        # Note: We allow some Base/Core ambiguities that we can't control
        Aqua.test_ambiguities(ATRIANeighbors)
    end

    @testset "Undefined exports" begin
        # Check that all exported names are actually defined
        Aqua.test_undefined_exports(ATRIANeighbors)
    end

    @testset "Unbound type parameters" begin
        # Check for unbound type parameters (a common source of bugs)
        Aqua.test_unbound_args(ATRIANeighbors)
    end

    @testset "Project.toml quality" begin
        # Check Project.toml is well-formed
        Aqua.test_project_extras(ATRIANeighbors)

        # Check stale dependencies
        Aqua.test_stale_deps(ATRIANeighbors)
    end

    @testset "Compat bounds" begin
        # Check that all dependencies have compat bounds
        Aqua.test_deps_compat(ATRIANeighbors)
    end

    @testset "Piracy detection" begin
        # Check for type piracy (extending methods on types we don't own)
        Aqua.test_piracies(ATRIANeighbors)
    end

    @testset "Persistent tasks" begin
        # Check for tasks that might not be properly cleaned up
        Aqua.test_persistent_tasks(ATRIANeighbors)
    end
end

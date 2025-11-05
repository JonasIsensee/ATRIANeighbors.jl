"""
profile_neighbor_search.jl

Profiling workload for ATRIA neighbor search operations.
Uses ProfilingAnalysis.jl to identify performance bottlenecks.
"""

using Pkg

# Load ATRIANeighbors and ProfilingAnalysis
Pkg.activate(".")
using ATRIANeighbors
using Random
using Printf

# Add ProfilingAnalysis
push!(LOAD_PATH, joinpath(@__DIR__, "..", "ProfilingAnalysis.jl", "src"))
using ProfilingAnalysis

# Load data generators
include("data_generators.jl")

println("=" ^ 80)
println("ATRIA Neighbor Search Profiling")
println("=" ^ 80)
println()

"""
    profile_tree_building(data_type::Symbol, N::Int, D::Int; min_points::Int=10)

Profile tree building performance.
"""
function profile_tree_building(data_type::Symbol, N::Int, D::Int; min_points::Int=10)
    println("Profiling tree building: $data_type, N=$N, D=$D")

    rng = MersenneTwister(42)
    data = generate_dataset(data_type, N, D, rng=rng)
    ps = PointSet(data, EuclideanMetric())

    # Warmup
    ATRIA(ps, min_points=min_points)

    # Profile
    profile = collect_profile_data() do
        for _ in 1:5
            ATRIA(ps, min_points=min_points)
        end
    end

    return profile
end

"""
    profile_knn_search(data_type::Symbol, N::Int, D::Int, k::Int, n_queries::Int; min_points::Int=10)

Profile k-NN search performance.
"""
function profile_knn_search(data_type::Symbol, N::Int, D::Int, k::Int, n_queries::Int; min_points::Int=10)
    println("Profiling k-NN search: $data_type, N=$N, D=$D, k=$k, queries=$n_queries")

    rng = MersenneTwister(42)
    data = generate_dataset(data_type, N, D, rng=rng)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=min_points)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = [data[i, :] for i in query_indices]

    # Add small noise to queries
    for q in queries
        q .+= randn(rng, length(q)) .* 0.01
    end

    # Warmup
    for q in queries
        knn(tree, q, k=k)
    end

    # Profile
    profile = collect_profile_data() do
        for _ in 1:3  # Repeat for more samples
            for q in queries
                knn(tree, q, k=k)
            end
        end
    end

    return profile
end

"""
    profile_range_search(data_type::Symbol, N::Int, D::Int, radius::Float64, n_queries::Int; min_points::Int=10)

Profile range search performance.
"""
function profile_range_search(data_type::Symbol, N::Int, D::Int, radius::Float64, n_queries::Int; min_points::Int=10)
    println("Profiling range search: $data_type, N=$N, D=$D, radius=$radius, queries=$n_queries")

    rng = MersenneTwister(42)
    data = generate_dataset(data_type, N, D, rng=rng)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=min_points)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = [data[i, :] for i in query_indices]

    # Add small noise to queries
    for q in queries
        q .+= randn(rng, length(q)) .* 0.01
    end

    # Warmup
    for q in queries
        range_search(tree, q, radius)
    end

    # Profile
    profile = collect_profile_data() do
        for _ in 1:3  # Repeat for more samples
            for q in queries
                range_search(tree, q, radius)
            end
        end
    end

    return profile
end

"""
    profile_count_range(data_type::Symbol, N::Int, D::Int, radius::Float64, n_queries::Int; min_points::Int=10)

Profile count_range performance.
"""
function profile_count_range(data_type::Symbol, N::Int, D::Int, radius::Float64, n_queries::Int; min_points::Int=10)
    println("Profiling count_range: $data_type, N=$N, D=$D, radius=$radius, queries=$n_queries")

    rng = MersenneTwister(42)
    data = generate_dataset(data_type, N, D, rng=rng)
    ps = PointSet(data, EuclideanMetric())
    tree = ATRIA(ps, min_points=min_points)

    # Generate query points
    query_indices = rand(rng, 1:N, n_queries)
    queries = [data[i, :] for i in query_indices]

    # Add small noise to queries
    for q in queries
        q .+= randn(rng, length(q)) .* 0.01
    end

    # Warmup
    for q in queries
        count_range(tree, q, radius)
    end

    # Profile
    profile = collect_profile_data() do
        for _ in 1:3  # Repeat for more samples
            for q in queries
                count_range(tree, q, radius)
            end
        end
    end

    return profile
end

# =============================================================================
# Main profiling workflow
# =============================================================================

println("Starting profiling workflow...")
println()

# Create output directory
output_dir = joinpath(@__DIR__, "..", "profile_results")
mkpath(output_dir)

# Test parameters
data_type = :gaussian_mixture  # Challenging dataset
N = 5000
D = 10
k = 20
n_queries = 100
radius = 1.5
min_points = 10

# =============================================================================
# 1. Profile tree building
# =============================================================================
println("\n" * "=" ^ 80)
println("1. TREE BUILDING PROFILING")
println("=" ^ 80)
profile_build = profile_tree_building(data_type, N, D, min_points=min_points)

# Save and analyze
save_profile(profile_build, joinpath(output_dir, "tree_building.json"))
println("\n--- Top 15 hotspots in tree building (excluding system code) ---")
top_build = query_top_n(profile_build, 15, filter_fn=e -> !is_system_code(e))
print_entry_table(top_build)

println("\n--- Summary ---")
summarize_profile(profile_build)

# =============================================================================
# 2. Profile k-NN search
# =============================================================================
println("\n" * "=" ^ 80)
println("2. K-NN SEARCH PROFILING")
println("=" ^ 80)
profile_knn = profile_knn_search(data_type, N, D, k, n_queries, min_points=min_points)

# Save and analyze
save_profile(profile_knn, joinpath(output_dir, "knn_search.json"))
println("\n--- Top 15 hotspots in k-NN search (excluding system code) ---")
top_knn = query_top_n(profile_knn, 15, filter_fn=e -> !is_system_code(e))
print_entry_table(top_knn)

println("\n--- Summary ---")
summarize_profile(profile_knn)

# =============================================================================
# 3. Profile range search
# =============================================================================
println("\n" * "=" ^ 80)
println("3. RANGE SEARCH PROFILING")
println("=" ^ 80)
profile_range = profile_range_search(data_type, N, D, radius, n_queries, min_points=min_points)

# Save and analyze
save_profile(profile_range, joinpath(output_dir, "range_search.json"))
println("\n--- Top 15 hotspots in range search (excluding system code) ---")
top_range = query_top_n(profile_range, 15, filter_fn=e -> !is_system_code(e))
print_entry_table(top_range)

println("\n--- Summary ---")
summarize_profile(profile_range)

# =============================================================================
# 4. Profile count_range
# =============================================================================
println("\n" * "=" ^ 80)
println("4. COUNT_RANGE PROFILING")
println("=" ^ 80)
profile_count = profile_count_range(data_type, N, D, radius, n_queries, min_points=min_points)

# Save and analyze
save_profile(profile_count, joinpath(output_dir, "count_range.json"))
println("\n--- Top 15 hotspots in count_range (excluding system code) ---")
top_count = query_top_n(profile_count, 15, filter_fn=e -> !is_system_code(e))
print_entry_table(top_count)

println("\n--- Summary ---")
summarize_profile(profile_count)

# =============================================================================
# 5. Generate recommendations
# =============================================================================
println("\n" * "=" ^ 80)
println("5. PERFORMANCE RECOMMENDATIONS")
println("=" ^ 80)

println("\n--- Tree Building ---")
recommendations_build = generate_recommendations(profile_build)
if !isempty(recommendations_build)
    for (i, rec) in enumerate(recommendations_build)
        println("$i. $rec")
    end
else
    println("No specific recommendations generated.")
end

println("\n--- K-NN Search ---")
recommendations_knn = generate_recommendations(profile_knn)
if !isempty(recommendations_knn)
    for (i, rec) in enumerate(recommendations_knn)
        println("$i. $rec")
    end
else
    println("No specific recommendations generated.")
end

println("\n--- Range Search ---")
recommendations_range = generate_recommendations(profile_range)
if !isempty(recommendations_range)
    for (i, rec) in enumerate(recommendations_range)
        println("$i. $rec")
    end
else
    println("No specific recommendations generated.")
end

println("\n--- Count Range ---")
recommendations_count = generate_recommendations(profile_count)
if !isempty(recommendations_count)
    for (i, rec) in enumerate(recommendations_count)
        println("$i. $rec")
    end
else
    println("No specific recommendations generated.")
end

# =============================================================================
# Summary
# =============================================================================
println("\n" * "=" ^ 80)
println("PROFILING COMPLETE")
println("=" ^ 80)
println("\nProfile data saved to:")
println("  - $(joinpath(output_dir, "tree_building.json"))")
println("  - $(joinpath(output_dir, "knn_search.json"))")
println("  - $(joinpath(output_dir, "range_search.json"))")
println("  - $(joinpath(output_dir, "count_range.json"))")
println("\nYou can load and analyze these profiles later using:")
println("  profile = load_profile(\"path/to/profile.json\")")
println("  summarize_profile(profile)")
println("  query_top_n(profile, 20)")
println("\n✓ Profiling workflow completed successfully!")

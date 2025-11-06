"""
    data_generators.jl

Generate various types of datasets for benchmarking ATRIA performance.

ATRIA is designed to excel on:
- Time-delay embedded data (attractors from dynamical systems)
- High-dimensional data (D > 10)
- Non-uniformly distributed data (clustered, manifold-like structures)

This module provides generators for these scenarios plus uniform baseline cases.
"""

using Random
using LinearAlgebra

# ============================================================================
# Time Series Attractors (ATRIA's primary use case)
# ============================================================================

"""
    generate_lorenz_attractor(N::Int, dt::Float64=0.01;
                              σ::Float64=10.0, ρ::Float64=28.0, β::Float64=8.0/3.0,
                              transient::Int=1000, rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from the Lorenz attractor.

Returns a matrix of size N×3.
The Lorenz system is defined by:
    dx/dt = σ(y - x)
    dy/dt = x(ρ - z) - y
    dz/dt = xy - βz

Parameters:
- σ, ρ, β: Lorenz system parameters (default: chaotic regime)
- dt: Integration timestep
- transient: Number of initial points to discard (avoid initial transients)
"""
function generate_lorenz_attractor(N::Int, dt::Float64=0.01;
                                  σ::Float64=10.0, ρ::Float64=28.0, β::Float64=8.0/3.0,
                                  transient::Int=1000, rng::AbstractRNG=Random.GLOBAL_RNG)
    # Initial condition
    x, y, z = 1.0, 1.0, 1.0

    # Discard transient
    for _ in 1:transient
        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z

        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    # Generate data
    points = zeros(N, 3)
    for i in 1:N
        points[i, 1] = x
        points[i, 2] = y
        points[i, 3] = z

        dx = σ * (y - x)
        dy = x * (ρ - z) - y
        dz = x * y - β * z

        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    return points
end

"""
    generate_rossler_attractor(N::Int, dt::Float64=0.05;
                               a::Float64=0.2, b::Float64=0.2, c::Float64=5.7,
                               transient::Int=1000, rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from the Rössler attractor.

Returns a matrix of size N×3.
The Rössler system is defined by:
    dx/dt = -y - z
    dy/dt = x + ay
    dz/dt = b + z(x - c)
"""
function generate_rossler_attractor(N::Int, dt::Float64=0.05;
                                   a::Float64=0.2, b::Float64=0.2, c::Float64=5.7,
                                   transient::Int=1000, rng::AbstractRNG=Random.GLOBAL_RNG)
    # Initial condition
    x, y, z = 1.0, 1.0, 1.0

    # Discard transient
    for _ in 1:transient
        dx = -y - z
        dy = x + a * y
        dz = b + z * (x - c)

        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    # Generate data
    points = zeros(N, 3)
    for i in 1:N
        points[i, 1] = x
        points[i, 2] = y
        points[i, 3] = z

        dx = -y - z
        dy = x + a * y
        dz = b + z * (x - c)

        x += dt * dx
        y += dt * dy
        z += dt * dz
    end

    return points
end

"""
    generate_henon_map(N::Int; a::Float64=1.4, b::Float64=0.3,
                       transient::Int=100, rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from the Henon map.

Returns a matrix of size N×2.
The Henon map is defined by:
    x_{n+1} = 1 - a*x_n^2 + y_n
    y_{n+1} = b*x_n
"""
function generate_henon_map(N::Int; a::Float64=1.4, b::Float64=0.3,
                           transient::Int=100, rng::AbstractRNG=Random.GLOBAL_RNG)
    # Initial condition
    x, y = 0.1, 0.1

    # Discard transient
    for _ in 1:transient
        x_new = 1.0 - a * x^2 + y
        y_new = b * x
        x, y = x_new, y_new
    end

    # Generate data
    points = zeros(N, 2)
    for i in 1:N
        points[i, 1] = x
        points[i, 2] = y

        x_new = 1.0 - a * x^2 + y
        y_new = b * x
        x, y = x_new, y_new
    end

    return points
end

"""
    generate_logistic_map(N::Int; r::Float64=3.99, transient::Int=100,
                          rng::AbstractRNG=Random.GLOBAL_RNG) -> Vector{Float64}

Generate N points from the logistic map.

Returns a vector of length N.
The logistic map is defined by:
    x_{n+1} = r*x_n*(1 - x_n)

For r=3.99, the map is chaotic.
"""
function generate_logistic_map(N::Int; r::Float64=3.99, transient::Int=100,
                              rng::AbstractRNG=Random.GLOBAL_RNG)
    # Initial condition
    x = 0.5

    # Discard transient
    for _ in 1:transient
        x = r * x * (1 - x)
    end

    # Generate data
    points = zeros(N)
    for i in 1:N
        points[i] = x
        x = r * x * (1 - x)
    end

    return points
end

# ============================================================================
# Clustered Data
# ============================================================================

"""
    generate_gaussian_mixture(N::Int, D::Int, n_clusters::Int;
                             cluster_std::Float64=1.0, separation::Float64=10.0,
                             rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from a Gaussian mixture model with n_clusters clusters.

Returns a matrix of size N×D.
Clusters are randomly placed and have equal probability.
"""
function generate_gaussian_mixture(N::Int, D::Int, n_clusters::Int;
                                  cluster_std::Float64=1.0, separation::Float64=10.0,
                                  rng::AbstractRNG=Random.GLOBAL_RNG)
    # Generate cluster centers
    centers = randn(rng, n_clusters, D) .* separation

    # Generate points
    points = zeros(N, D)
    for i in 1:N
        # Choose cluster randomly
        cluster_idx = rand(rng, 1:n_clusters)
        center = centers[cluster_idx, :]

        # Generate point around center
        points[i, :] = center .+ randn(rng, D) .* cluster_std
    end

    return points
end

"""
    generate_hierarchical_clusters(N::Int, D::Int, depth::Int;
                                   cluster_std::Float64=1.0, separation::Float64=5.0,
                                   rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points with hierarchical cluster structure.

Creates 2^depth clusters organized in a binary tree structure.
"""
function generate_hierarchical_clusters(N::Int, D::Int, depth::Int;
                                       cluster_std::Float64=1.0, separation::Float64=5.0,
                                       rng::AbstractRNG=Random.GLOBAL_RNG)
    n_clusters = 2^depth

    # Build hierarchical centers
    centers = zeros(n_clusters, D)
    for level in 0:depth-1
        n_at_level = 2^level
        for i in 1:n_at_level
            # Generate offset for this level
            offset = randn(rng, D) .* (separation * (depth - level))
            # Apply to both children
            centers[2*i-1, :] .+= offset
            centers[2*i, :] .+= offset
        end
    end

    # Generate points
    points = zeros(N, D)
    for i in 1:N
        cluster_idx = rand(rng, 1:n_clusters)
        center = centers[cluster_idx, :]
        points[i, :] = center .+ randn(rng, D) .* cluster_std
    end

    return points
end

# ============================================================================
# Manifold Data
# ============================================================================

"""
    generate_swiss_roll(N::Int; noise::Float64=0.1,
                       rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points on a Swiss roll manifold (2D manifold in 3D space).
"""
function generate_swiss_roll(N::Int; noise::Float64=0.1,
                            rng::AbstractRNG=Random.GLOBAL_RNG)
    points = zeros(N, 3)

    for i in 1:N
        t = 1.5 * π * (1 + 2 * rand(rng))
        h = 21.0 * rand(rng)

        points[i, 1] = t * cos(t)
        points[i, 2] = h
        points[i, 3] = t * sin(t)

        # Add noise
        points[i, :] .+= randn(rng, 3) .* noise
    end

    return points
end

"""
    generate_s_curve(N::Int; noise::Float64=0.1,
                    rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points on an S-curve manifold (2D manifold in 3D space).
"""
function generate_s_curve(N::Int; noise::Float64=0.1,
                         rng::AbstractRNG=Random.GLOBAL_RNG)
    points = zeros(N, 3)

    for i in 1:N
        t = 3 * π * (rand(rng) - 0.5)
        h = 2.0 * rand(rng)

        points[i, 1] = sin(t)
        points[i, 2] = h
        points[i, 3] = sign(t) * (cos(t) - 1)

        # Add noise
        points[i, :] .+= randn(rng, 3) .* noise
    end

    return points
end

"""
    generate_sphere(N::Int, D::Int; radius::Float64=1.0, noise::Float64=0.0,
                   rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points uniformly distributed on a D-dimensional sphere.
"""
function generate_sphere(N::Int, D::Int; radius::Float64=1.0, noise::Float64=0.0,
                        rng::AbstractRNG=Random.GLOBAL_RNG)
    points = zeros(N, D)

    for i in 1:N
        # Generate random direction
        point = randn(rng, D)
        point ./= norm(point)
        point .*= radius

        points[i, :] = point .+ randn(rng, D) .* noise
    end

    return points
end

"""
    generate_torus(N::Int; R::Float64=2.0, r::Float64=1.0, noise::Float64=0.1,
                  rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points on a torus (2D manifold in 3D space).

Parameters:
- R: Major radius (distance from center to tube center)
- r: Minor radius (tube radius)
"""
function generate_torus(N::Int; R::Float64=2.0, r::Float64=1.0, noise::Float64=0.1,
                       rng::AbstractRNG=Random.GLOBAL_RNG)
    points = zeros(N, 3)

    for i in 1:N
        θ = 2π * rand(rng)  # Major angle
        φ = 2π * rand(rng)  # Minor angle

        points[i, 1] = (R + r * cos(φ)) * cos(θ)
        points[i, 2] = (R + r * cos(φ)) * sin(θ)
        points[i, 3] = r * sin(φ)

        # Add noise
        points[i, :] .+= randn(rng, 3) .* noise
    end

    return points
end

# ============================================================================
# Uniform Random Data (baseline comparison)
# ============================================================================

"""
    generate_uniform_hypercube(N::Int, D::Int;
                              rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points uniformly distributed in a D-dimensional unit hypercube [0,1]^D.
"""
function generate_uniform_hypercube(N::Int, D::Int;
                                   rng::AbstractRNG=Random.GLOBAL_RNG)
    return rand(rng, N, D)
end

"""
    generate_uniform_hypersphere(N::Int, D::Int; radius::Float64=1.0,
                                rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points uniformly distributed inside a D-dimensional hypersphere.
"""
function generate_uniform_hypersphere(N::Int, D::Int; radius::Float64=1.0,
                                     rng::AbstractRNG=Random.GLOBAL_RNG)
    points = zeros(N, D)

    for i in 1:N
        # Generate random direction
        direction = randn(rng, D)
        direction ./= norm(direction)

        # Generate random radius (uniform in volume)
        r = radius * rand(rng)^(1/D)

        points[i, :] = direction .* r
    end

    return points
end

"""
    generate_gaussian(N::Int, D::Int; μ::Float64=0.0, σ::Float64=1.0,
                     rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from a D-dimensional Gaussian distribution.
"""
function generate_gaussian(N::Int, D::Int; μ::Float64=0.0, σ::Float64=1.0,
                          rng::AbstractRNG=Random.GLOBAL_RNG)
    return μ .+ σ .* randn(rng, N, D)
end

# ============================================================================
# Pathological Cases (stress tests)
# ============================================================================

"""
    generate_line(N::Int, D::Int; noise::Float64=0.0,
                 rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points on a line in D-dimensional space (1D manifold in high-D).
This is a pathological case where most space-partitioning trees struggle.
"""
function generate_line(N::Int, D::Int; noise::Float64=0.0,
                      rng::AbstractRNG=Random.GLOBAL_RNG)
    # Random line direction
    direction = randn(rng, D)
    direction ./= norm(direction)

    points = zeros(N, D)
    for i in 1:N
        t = (i - N/2) / N  # Parameter along line
        points[i, :] = t .* direction .+ randn(rng, D) .* noise
    end

    return points
end

"""
    generate_grid(N::Int, D::Int; grid_size::Int=10) -> Matrix{Float64}

Generate points on a regular grid in D dimensions.
Total points will be ≈ N (adjusted to fit grid structure).
"""
function generate_grid(N::Int, D::Int; grid_size::Int=10)
    points_per_dim = ceil(Int, N^(1/D))
    points_per_dim = max(points_per_dim, 2)  # At least 2 per dimension

    # Generate grid coordinates
    coords = [range(0, 1, length=points_per_dim) for _ in 1:D]

    # Generate all combinations (Cartesian product)
    points = zeros(0, D)
    for idx in Iterators.product(coords...)
        point = collect(idx)
        points = vcat(points, point')
        if size(points, 1) >= N
            break
        end
    end

    return points[1:min(N, size(points, 1)), :]
end

"""
    generate_skewed_gaussian(N::Int, D::Int; skew_factor::Float64=10.0,
                            rng::AbstractRNG=Random.GLOBAL_RNG) -> Matrix{Float64}

Generate N points from a highly skewed distribution.
First dimension has much larger variance than others.
"""
function generate_skewed_gaussian(N::Int, D::Int; skew_factor::Float64=10.0,
                                 rng::AbstractRNG=Random.GLOBAL_RNG)
    points = randn(rng, N, D)
    points[:, 1] .*= skew_factor  # First dimension has high variance
    return points
end

# ============================================================================
# Helper: Generate dataset by name
# ============================================================================

"""
    generate_dataset(dataset_type::Symbol, N::Int, D::Int; kwargs...) -> Matrix{Float64}

Generate a dataset by name. Supported types:
- :lorenz - Lorenz attractor (ignores D, always 3D)
- :rossler - Rössler attractor (ignores D, always 3D)
- :henon - Henon map (ignores D, always 2D)
- :logistic - Logistic map (ignores D, always 1D, returns as N×1 matrix)
- :gaussian_mixture - Gaussian mixture model
- :hierarchical - Hierarchical clusters
- :swiss_roll - Swiss roll (ignores D, always 3D)
- :s_curve - S-curve (ignores D, always 3D)
- :sphere - Sphere in D dimensions
- :torus - Torus (ignores D, always 3D)
- :uniform_hypercube - Uniform in unit hypercube
- :uniform_hypersphere - Uniform in hypersphere
- :gaussian - Standard Gaussian
- :line - Points on a line
- :grid - Regular grid
- :skewed_gaussian - Skewed Gaussian

Additional keyword arguments are passed to the specific generator.
"""
function generate_dataset(dataset_type::Symbol, N::Int, D::Int; kwargs...)
    if dataset_type == :lorenz
        return generate_lorenz_attractor(N; kwargs...)
    elseif dataset_type == :rossler
        return generate_rossler_attractor(N; kwargs...)
    elseif dataset_type == :henon
        return generate_henon_map(N; kwargs...)
    elseif dataset_type == :logistic
        data = generate_logistic_map(N; kwargs...)
        return reshape(data, N, 1)  # Return as N×1 matrix
    elseif dataset_type == :gaussian_mixture
        n_clusters = get(kwargs, :n_clusters, 5)
        return generate_gaussian_mixture(N, D, n_clusters; kwargs...)
    elseif dataset_type == :hierarchical
        depth = get(kwargs, :depth, 3)
        return generate_hierarchical_clusters(N, D, depth; kwargs...)
    elseif dataset_type == :swiss_roll
        return generate_swiss_roll(N; kwargs...)
    elseif dataset_type == :s_curve
        return generate_s_curve(N; kwargs...)
    elseif dataset_type == :sphere
        return generate_sphere(N, D; kwargs...)
    elseif dataset_type == :torus
        return generate_torus(N; kwargs...)
    elseif dataset_type == :uniform_hypercube
        return generate_uniform_hypercube(N, D; kwargs...)
    elseif dataset_type == :uniform_hypersphere
        return generate_uniform_hypersphere(N, D; kwargs...)
    elseif dataset_type == :gaussian
        return generate_gaussian(N, D; kwargs...)
    elseif dataset_type == :line
        return generate_line(N, D; kwargs...)
    elseif dataset_type == :grid
        return generate_grid(N, D; kwargs...)
    elseif dataset_type == :skewed_gaussian
        return generate_skewed_gaussian(N, D; kwargs...)
    else
        error("Unknown dataset type: $dataset_type")
    end
end

# Export all generators
export generate_lorenz_attractor, generate_rossler_attractor, generate_henon_map, generate_logistic_map
export generate_gaussian_mixture, generate_hierarchical_clusters
export generate_swiss_roll, generate_s_curve, generate_sphere, generate_torus
export generate_uniform_hypercube, generate_uniform_hypersphere, generate_gaussian
export generate_line, generate_grid, generate_skewed_gaussian
export generate_dataset

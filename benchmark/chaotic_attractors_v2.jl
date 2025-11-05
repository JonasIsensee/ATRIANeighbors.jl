# Chaotic attractor generators using DynamicalSystems.jl
# This replaces chaotic_attractors.jl with validated, well-tested implementations

using DynamicalSystems

"""
    generate_lorenz_attractor(; N::Int=500000,
                               Ds::Int=25,
                               Δt::Float64=0.01,
                               delay::Int=2,
                               Ttr::Float64=40.0,
                               σ::Float64=10.0,
                               ρ::Float64=28.0,
                               β::Float64=8.0/3.0)

Generate Lorenz attractor using DynamicalSystems.jl with time-delay embedding.

Uses the validated Lorenz system implementation and proper embedding utilities.

# Arguments
- `N`: Number of embedded vectors to generate
- `Ds`: Embedding dimension
- `Δt`: Integration time step
- `delay`: Time delay for embedding (in samples)
- `Ttr`: Transient time to discard
- `σ, ρ, β`: Lorenz system parameters (default: chaotic regime)

# Returns
- `(data, metadata)`: N×Ds embedded matrix and Dict with generation parameters
"""
function generate_lorenz_attractor(; N::Int=500000,
                                   Ds::Int=25,
                                   Δt::Float64=0.01,
                                   delay::Int=2,
                                   Ttr::Float64=40.0,
                                   σ::Float64=10.0,
                                   ρ::Float64=28.0,
                                   β::Float64=8.0/3.0)

    println("Generating Lorenz attractor with DynamicalSystems.jl...")
    println("  System parameters: σ=$σ, ρ=$ρ, β=$β")
    println("  Integration: Δt=$Δt, N=$N points")
    println("  Transient: Ttr=$Ttr time units")
    println("  Embedding: Ds=$Ds, delay=$delay samples")

    # Create Lorenz system
    ds = Systems.lorenz([0.0, 10.0, 0.0]; σ=σ, ρ=ρ, β=β)

    # Calculate total time needed (including transient)
    # Need N + (Ds-1)*delay points after transient
    N_total = N + (Ds - 1) * delay
    T_total = (N_total - 1) * Δt

    println("  Generating trajectory (T=$T_total, transient removed)...")

    # Generate trajectory with transient removal
    traj, t = trajectory(ds, T_total, Δt=Δt, Ttr=Ttr)

    println("  Raw trajectory: $(size(traj))")

    # Extract x component for embedding
    x = traj[:, 1]

    println("  Creating time-delay embedding...")

    # Create time-delay embedding: [x(t), x(t+τ), ..., x(t+(Ds-1)τ)]
    # where τ = delay * Δt (in samples)
    embedded = genembed(x, (0:Ds-1) .* delay)

    # Take first N points
    data = Matrix(embedded[1:N, :])

    println("  Generated $(size(data, 1)) × $(size(data, 2)) embedded vectors")

    metadata = Dict(
        "system" => "Lorenz",
        "N" => size(data, 1),
        "Ds" => Ds,
        "Δt" => Δt,
        "delay" => delay,
        "delay_time" => delay * Δt,
        "Ttr" => Ttr,
        "parameters" => Dict("σ" => σ, "ρ" => ρ, "β" => β),
        "expected_D1" => 2.05,
        "library" => "DynamicalSystems.jl"
    )

    return (data, metadata)
end

"""
    generate_roessler_attractor(; N::Int=200000,
                                Ds::Int=24,
                                Δt::Float64=0.05,
                                delay::Int=10,
                                Ttr::Float64=10.0,
                                a::Float64=0.2,
                                b::Float64=0.2,
                                c::Float64=5.7)

Generate Rössler attractor using DynamicalSystems.jl with time-delay embedding.

Uses the standard 3D Rössler system (not hyperchaotic extensions).
Expected D1 ≈ 2.0 for standard parameters.

# Arguments
- `N`: Number of embedded vectors to generate
- `Ds`: Embedding dimension
- `Δt`: Integration time step
- `delay`: Time delay for embedding (in samples)
- `Ttr`: Transient time to discard
- `a, b, c`: Rössler system parameters

# Returns
- `(data, metadata)`: N×Ds embedded matrix and Dict with generation parameters
"""
function generate_roessler_attractor(; N::Int=200000,
                                    Ds::Int=24,
                                    Δt::Float64=0.05,
                                    delay::Int=10,
                                    Ttr::Float64=10.0,
                                    a::Float64=0.2,
                                    b::Float64=0.2,
                                    c::Float64=5.7)

    println("Generating Rössler attractor with DynamicalSystems.jl...")
    println("  System parameters: a=$a, b=$b, c=$c")
    println("  Integration: Δt=$Δt, N=$N points")
    println("  Transient: Ttr=$Ttr time units")
    println("  Embedding: Ds=$Ds, delay=$delay samples")

    # Create Rössler system
    ds = Systems.roessler([1.0, -2.0, 0.1]; a=a, b=b, c=c)

    # Calculate total time needed
    N_total = N + (Ds - 1) * delay
    T_total = (N_total - 1) * Δt

    println("  Generating trajectory (T=$T_total, transient removed)...")

    # Generate trajectory with transient removal
    traj, t = trajectory(ds, T_total, Δt=Δt, Ttr=Ttr)

    println("  Raw trajectory: $(size(traj))")

    # Extract x component for embedding
    x = traj[:, 1]

    println("  Creating time-delay embedding...")

    # Create time-delay embedding
    embedded = genembed(x, (0:Ds-1) .* delay)

    # Take first N points
    data = Matrix(embedded[1:N, :])

    println("  Generated $(size(data, 1)) × $(size(data, 2)) embedded vectors")

    metadata = Dict(
        "system" => "Rössler",
        "N" => size(data, 1),
        "Ds" => Ds,
        "Δt" => Δt,
        "delay" => delay,
        "delay_time" => delay * Δt,
        "Ttr" => Ttr,
        "parameters" => Dict("a" => a, "b" => b, "c" => c),
        "expected_D1" => 2.0,  # Standard 3D Rössler
        "library" => "DynamicalSystems.jl"
    )

    return (data, metadata)
end

"""
    generate_henon_map(; N::Int=200000,
                       Ds::Int=12,
                       Ttr::Int=5000,
                       a::Float64=1.76,
                       b::Float64=0.1)

Generate generalized Hénon map as described in ATRIA paper.

This implements the Ds-dimensional generalization:
    x₁(n+1) = a - x_{Ds-1}(n)² - b·x_{Ds}(n)
    xᵢ(n+1) = xᵢ₋₁(n),  i=2,...,Ds

This is NOT time-delay embedding - it's a coupled Ds-dimensional system.

# Arguments
- `N`: Number of points to generate
- `Ds`: Dimension of the generalized map (2 to 12 in paper)
- `Ttr`: Number of transient iterations to discard (paper uses 5000)
- `a, b`: Hénon map parameters (paper uses a=1.76, b=0.1)

# Returns
- `(data, metadata)`: N×Ds matrix and Dict with generation parameters
"""
function generate_henon_map(; N::Int=200000,
                            Ds::Int=12,
                            Ttr::Int=5000,
                            a::Float64=1.76,
                            b::Float64=0.1)

    println("Generating generalized Hénon map (paper specification)...")
    println("  Parameters: a=$a, b=$b")
    println("  Dimension: Ds=$Ds (generalized map, NOT embedding)")
    println("  Transient: Ttr=$Ttr iterations")

    # Initialize state from random initial conditions
    # For higher Ds, the map can diverge from some initial conditions,
    # so we retry if divergence is detected
    max_attempts = 100
    state = nothing

    for attempt in 1:max_attempts
        state = randn(Ds) .* 0.1  # Smaller initial values help avoid divergence
        diverged = false

        # Discard transient
        for iter in 1:Ttr
            # Generalized Hénon map iteration
            x1_new = a - state[Ds-1]^2 - b * state[Ds]

            # Check for divergence
            if isnan(x1_new) || isinf(x1_new) || abs(x1_new) > 1e6
                diverged = true
                break
            end

            # Shift other dimensions (delay line coupling)
            state_new = zeros(Ds)
            state_new[1] = x1_new
            for i in 2:Ds
                state_new[i] = state[i-1]
            end

            state = state_new
        end

        if !diverged
            println("  Found stable trajectory (attempt $attempt)")
            break
        elseif attempt == max_attempts
            error("Could not find stable trajectory after $max_attempts attempts")
        end
    end

    println("  Generating $N iterations...")

    # Generate data
    data = zeros(N, Ds)
    for n in 1:N
        # Store current state
        data[n, :] = state

        # Generalized Hénon map iteration
        x1_new = a - state[Ds-1]^2 - b * state[Ds]

        # Safety check (should not happen if transient was successful)
        if isnan(x1_new) || isinf(x1_new) || abs(x1_new) > 1e6
            error("Trajectory diverged during data generation at iteration $n")
        end

        # Shift other dimensions
        state_new = zeros(Ds)
        state_new[1] = x1_new
        for i in 2:Ds
            state_new[i] = state[i-1]
        end

        state = state_new

        # Progress indicator
        if n % 50000 == 0
            println("  Progress: $n/$N iterations")
        end
    end

    println("  Generated $(size(data, 1)) × $(size(data, 2)) points")
    println("  Note: D1 grows with Ds for generalized Hénon map (not constant!)")

    metadata = Dict(
        "system" => "Hénon (generalized)",
        "N" => N,
        "Ds" => Ds,
        "Ttr" => Ttr,
        "parameters" => Dict("a" => a, "b" => b),
        "expected_D1" => NaN,  # D1 grows with Ds, no single expected value
        "type" => "generalized_map",
        "note" => "Ds-dimensional coupled system, not time-delay embedding. D1 increases with Ds (paper Fig 6)."
    )

    return (data, metadata)
end

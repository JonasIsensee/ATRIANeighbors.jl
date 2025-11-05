using DynamicalSystems

println("Available systems in DynamicalSystems.Systems:")
for name in names(DynamicalSystems.Systems, all=true)
    str = string(name)
    if !startswith(str, "#") && str != "Systems"
        println("  ", name)
    end
end

# Test Lorenz
println("\n\nTesting Lorenz system:")
ds = Systems.lorenz()
println("  Type: ", typeof(ds))
println("  Initial state: ", current_state(ds))

# Generate trajectory
traj, t = trajectory(ds, 100.0, Δt=0.01)
println("  Trajectory shape: ", size(traj))

# Test embedding
println("\n\nTesting DelayEmbeddings:")
x = traj[:, 1]  # Extract x component
println("  Time series length: ", length(x))
embedded = genembed(x, (0:24) .* 2)  # Ds=25, delay=2
println("  Embedded shape: ", size(embedded))

# Test Rössler
println("\nTesting Rössler system:")
ds = Systems.roessler()
println("  Type: ", typeof(ds))
println("  Initial state: ", current_state(ds))
traj2, t2 = trajectory(ds, 100.0, Δt=0.05)
println("  Trajectory shape: ", size(traj2))

# Test Hénon
println("\nTesting Hénon map:")
ds = Systems.henon()
println("  Type: ", typeof(ds))
println("  Initial state: ", current_state(ds))

# Generate iterations
traj3, _ = trajectory(ds, 1000)
println("  Trajectory shape: ", size(traj3))
println("  Trajectory type: ", typeof(traj3))

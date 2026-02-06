"""
# Time-Delay Embedding: Lorenz Attractor

ATRIA excels on delay-embedded time series (low intrinsic dimension
in high-dimensional space). This example generates a Lorenz attractor,
embeds it with time-delay embedding, and runs k-NN search.
"""

using ATRIANeighbors
using Random

# Generate a short Lorenz trajectory (or use your own time series)
function lorenz_step(x, y, z; σ=10.0, ρ=28.0, β=8.0/3.0, dt=0.01)
    dx = σ * (y - x)
    dy = x * (ρ - z) - y
    dz = x * y - β * z
    return x + dt*dx, y + dt*dy, z + dt*dz
end

Random.seed!(123)
N = 5000
ts = let
    x, y, z = 1.0, 1.0, 1.0
    for _ in 1:1000
        x, y, z = lorenz_step(x, y, z)
    end
    out = Float64[]
    for _ in 1:N
        x, y, z = lorenz_step(x, y, z)
        push!(out, x)
    end
    out
end

# Time-delay embedding: dim=3, delay=10
# Each point is [x(t), x(t-10), x(t-20)]
ps = EmbeddedTimeSeries(ts, dim=3, delay=10)
tree = ATRIATree(ps)
N_pts, dim_emb = size(ps)
println("Embedded time series: $N_pts points, $dim_emb dimensions")
println("Tree: $(tree.total_clusters) clusters, $(tree.terminal_nodes) leaves")

# Query using the first embedded point
query = getpoint(ps, 1)
neighbors = knn(tree, query, k=5)
println("\n5 nearest neighbors to first point:")
for n in neighbors
    println("  index $(n.index), distance = $(round(n.distance, digits=6))")
end

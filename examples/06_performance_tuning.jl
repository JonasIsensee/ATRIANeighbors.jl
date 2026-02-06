"""
# Performance Tuning: min_points and When to Use ATRIA

- ATRIA is best for high embedding dimension with low intrinsic (fractal) dimension.
- For low-D or random high-D data, prefer NearestNeighbors.jl (KDTree/BallTree).
- min_points controls tree depth: smaller → deeper tree, more pruning, more overhead.
"""

using ATRIANeighbors
using Random

Random.seed!(7)
D = 24   # e.g. delay-embedded time series
N = 10_000
data = randn(D, N)
query = randn(D)
k = 10

# Compare different min_points (trade-off: tree depth vs cluster size)
for min_pt in [8, 32, 64, 128]
    tree = ATRIATree(data, min_points=min_pt)
    t = @elapsed for _ in 1:100; knn(tree, query, k=k); end
    println("min_points=$min_pt: $(tree.terminal_nodes) leaves, 100 queries ≈ $(round(t*1000, digits=2)) ms")
end

# Rule of thumb: use default min_points=64 unless profiling shows benefit
tree = ATRIATree(data)
println("\nDefault tree: $(tree.total_clusters) clusters, $(tree.terminal_nodes) terminal nodes")

"""
# Range Search and Correlation Sum

Find all neighbors within a radius, or count them (e.g. for correlation
dimension or recurrence analysis).
"""

using ATRIANeighbors
using Random

Random.seed!(44)
D = 8
N = 5_000
data = randn(D, N)
tree = ATRIATree(data)

query = randn(D)
radius = 1.5

# All neighbors within radius
neighbors_in_radius = range_search(tree, query, radius=radius)
println("Points within radius $radius: $(length(neighbors_in_radius))")

# Count only (no allocation of neighbor list) — useful for correlation sum
count_in_radius = count_range(tree, query, radius=radius)
println("Count within radius $radius: $count_in_radius")
@assert count_in_radius == length(neighbors_in_radius)

# Exclude a range of indices (e.g. exclude query point's time window in time series)
exclude_range = (1, 10)  # exclude indices 1..10
count_excluded = count_range(tree, query, radius=radius, exclude_range=exclude_range)
println("Count within radius (excluding indices 1–10): $count_excluded")

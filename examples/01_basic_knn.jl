"""
# Basic k-NN Search with ATRIA

This example demonstrates the simplest use case: finding k nearest
neighbors in a matrix of points.
"""

using ATRIANeighbors
using Random

# Create random data (D×N layout: columns are points)
Random.seed!(42)
D = 20  # dimensions
N = 10_000  # points
data = randn(D, N)

# Build ATRIA tree
tree = ATRIATree(data)
println("Tree built: $(tree.total_clusters) clusters, $(tree.terminal_nodes) leaves")

# Find 10 nearest neighbors
query = randn(D)
neighbors = knn(tree, query, k=10)

# Extract results
indices = [n.index for n in neighbors]
distances = [n.distance for n in neighbors]

println("\n10 Nearest Neighbors:")
for (idx, dist) in zip(indices, distances)
    println("  Point $idx: distance = $(round(dist, digits=4))")
end

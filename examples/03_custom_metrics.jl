"""
# Custom Distance Metrics

ATRIA supports different metrics. Besides the default Euclidean metric,
you can use Maximum (Chebyshev) or ExponentiallyWeightedEuclidean.
Access them via ATRIANeighbors since they are not exported.
"""

using ATRIANeighbors
using Random

# Use internal metrics (not exported)
const EuclideanMetric = ATRIANeighbors.EuclideanMetric
const MaximumMetric = ATRIANeighbors.MaximumMetric
const ExponentiallyWeightedEuclidean = ATRIANeighbors.ExponentiallyWeightedEuclidean

Random.seed!(99)
data = randn(5, 1000)

# --- Euclidean (default) ---
tree_euc = ATRIATree(data, metric=EuclideanMetric())
query = randn(5)
neighbors_euc = knn(tree_euc, query, k=3)
println("Euclidean metric, 3-NN distances: ", [round(n.distance, digits=4) for n in neighbors_euc])

# --- Maximum (Chebyshev, L∞) ---
tree_max = ATRIATree(data, metric=MaximumMetric())
neighbors_max = knn(tree_max, query, k=3)
println("Maximum (Chebyshev) metric, 3-NN distances: ", [round(n.distance, digits=4) for n in neighbors_max])

# --- Exponentially weighted Euclidean ---
# Weights earlier dimensions more (lambda < 1)
metric_ew = ExponentiallyWeightedEuclidean(0.7)
tree_ew = ATRIATree(data, metric=metric_ew)
neighbors_ew = knn(tree_ew, query, k=3)
println("Exponentially weighted Euclidean (λ=0.7), 3-NN distances: ", [round(n.distance, digits=4) for n in neighbors_ew])

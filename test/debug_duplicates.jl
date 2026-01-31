using ATRIANeighbors
using Random

# Simple test to debug duplicate issue
Random.seed!(43)
data = rand(50, 3)
ps = PointSet(data, EuclideanMetric())
tree = ATRIATree(ps, min_points=8)

query = rand(3)

println("Testing k=5 search...")
atria_results = knn(tree, query, k=5)
brute_results = brute_knn(ps, query, 5)

println("\nATRIA results:")
for (i, n) in enumerate(atria_results)
    println("  $i: index=$(n.index), dist=$(n.distance)")
end

println("\nBrute force results:")
for (i, n) in enumerate(brute_results)
    println("  $i: index=$(n.index), dist=$(n.distance)")
end

println("\nChecking for duplicates in ATRIA results:")
indices = [n.index for n in atria_results]
unique_indices = unique(indices)
if length(indices) != length(unique_indices)
    println("  FOUND DUPLICATES!")
    println("  Indices: $indices")
    println("  Unique: $unique_indices")
    println("  Duplicate indices: $(setdiff(indices, unique_indices))")
end

"""
# Batch Processing: Context Reuse and Parallel Queries

For many queries, reuse a SearchContext to minimize allocations, or use
parallel batch dispatch for multi-threaded speedup.
"""

using ATRIANeighbors
using Random

Random.seed!(1)
D = 15
N = 20_000
data = randn(D, N)
tree = ATRIATree(data)
k = 10

# --- Single-context batch (minimal allocations) ---
num_queries = 500
queries = randn(D, num_queries)

# Option A: Pass matrix; context is created and reused internally per query
results_batch = knn(tree, queries, k=k)
@assert length(results_batch) == num_queries
@assert all(length(r) == k for r in results_batch)
println("Batch: $(num_queries) queries, k=$k → $(length(results_batch)) result vectors")

# Option B: Explicit SearchContext reuse (e.g. in a loop with custom logic)
ctx = SearchContext(tree, k)
local_results = []
for j in 1:min(100, size(queries, 2))
    q = view(queries, :, j)
    push!(local_results, knn(tree, q, k=k, ctx=ctx))
end
println("With explicit SearchContext: $(length(local_results)) queries processed")

# --- Parallel batch (multi-threaded) ---
# Use parallel=true for matrix of queries (uses Threads.@threads)
results_parallel = knn(tree, queries, k=k, parallel=true)
@assert length(results_parallel) == num_queries
println("Parallel batch: $(num_queries) queries completed")

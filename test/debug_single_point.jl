using ATRIANeighbors

# Test single point
data = Float64[1 2 3]
ps = PointSet(data)

println("Building tree for single point...")
tree = ATRIATree(ps, min_points=10)

println("Total clusters: ", tree.total_clusters)
println("Terminal nodes: ", tree.terminal_nodes)
println("Root Rmax: ", tree.root.Rmax)
println("Is terminal: ", is_terminal(tree.root))
if is_terminal(tree.root)
    println("Root length: ", tree.root.length)
    println("Root start: ", tree.root.start)
else
    println("Root is NOT terminal!")
    println("Root left: ", tree.root.left)
    println("Root right: ", tree.root.right)
end

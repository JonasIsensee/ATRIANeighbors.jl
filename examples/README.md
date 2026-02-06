# ATRIANeighbors.jl Examples

Run any example from the repo root:

```bash
julia --project=. examples/01_basic_knn.jl
```

Or from a Julia REPL:

```julia
include("examples/01_basic_knn.jl")
```

## Index

| File                                                 | Description                                 |
| ---------------------------------------------------- | ------------------------------------------- |
| [01_basic_knn.jl](01_basic_knn.jl)                   | Simple matrix k-NN search                   |
| [02_lorenz_attractor.jl](02_lorenz_attractor.jl)     | Time series with delay embedding            |
| [03_custom_metrics.jl](03_custom_metrics.jl)         | Maximum and ExponentiallyWeighted metrics   |
| [04_batch_processing.jl](04_batch_processing.jl)     | Context reuse and parallel batch queries    |
| [05_range_search.jl](05_range_search.jl)             | Range search and correlation sum            |
| [06_performance_tuning.jl](06_performance_tuning.jl) | Choosing `min_points` and when to use ATRIA |

## Requirements

- Julia 1.10+
- ATRIANeighbors (add or dev from this repo)

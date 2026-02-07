# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Examples directory with 6 documented scripts (basic k-NN, Lorenz embedding, custom metrics, batch processing, range search, performance tuning)
- Documentation check script `scripts/check_docs.jl` for exported symbol docstrings
- Benchmark baseline and regression check (`benchmark/baseline.jl`) with optional CI step

## [0.1.0] - (unreleased)

### Added

- ATRIA tree construction with configurable `min_points` and optional custom metric
- k-NN search: single query, batch (matrix), and parallel batch
- `SearchContext` for allocation-efficient repeated queries
- Range search and `count_range` (correlation sum)
- Point set abstractions: `PointSet` (matrix), `EmbeddedTimeSeries` (time-delay embedding)
- Metrics: Euclidean, Maximum (Chebyshev), ExponentiallyWeightedEuclidean
- Brute-force reference implementations for validation (internal)
- Test suite including Aqua.jl quality checks and correctness tests vs brute force and NearestNeighbors.jl

### Performance

- Optimized for low intrinsic dimension in high-dimensional space (e.g. delay-embedded time series)
- Column-major (D×N) layout for cache-friendly distance computation
- Minimal allocations in search path when reusing `SearchContext`

[Unreleased]: https://github.com/JonasIsensee/ATRIANeighbors.jl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/JonasIsensee/ATRIANeighbors.jl/releases/tag/v0.1.0

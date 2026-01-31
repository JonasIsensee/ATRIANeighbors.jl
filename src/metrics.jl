# Distance metrics for ATRIA algorithm

using LoopVectorization

"""
    Metric

Abstract base type for all distance metrics.

Each metric should implement:
- `distance(metric, p1, p2)` - Full distance calculation
- `distance(metric, p1, p2, thresh)` - Partial distance with early termination
"""
abstract type Metric end

"""
    EuclideanMetric <: Metric

Standard Euclidean distance (L2 norm).

``d(x, y) = \\sqrt{\\sum_i (x_i - y_i)^2}``

This is the most common distance metric. The early termination version
is particularly effective for pruning in the ATRIA algorithm.
"""
struct EuclideanMetric <: Metric end

"""
    distance(::EuclideanMetric, p1, p2) -> Float64

Compute full Euclidean distance between two points.
"""
@inline function distance(::EuclideanMetric, p1, p2)
    sum_sq = 0.0
    # Use explicit bounds for better optimization
    # @turbo works best with explicit integer ranges
    n = length(p1)
    @turbo for i in 1:n
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
    end
    return sqrt(sum_sq)
end

"""
    distance(::EuclideanMetric, p1, p2, thresh::Float64) -> Float64

Compute Euclidean distance with early termination.

If the distance exceeds `thresh`, the calculation stops early and returns
a value >= thresh. This is a key optimization for the ATRIA algorithm.

Optimized with chunked processing to reduce branch misprediction overhead.
"""
@inline function distance(::EuclideanMetric, p1, p2, thresh::Float64)
    thresh_sq = thresh * thresh
    n = length(p1)

    # For small dimensions, use unrolled version
    if n <= 4
        return _distance_small(p1, p2, thresh, thresh_sq, n)
    end

    # For larger dimensions, process in chunks to reduce branch overhead
    # Check threshold every 8 elements instead of every element
    sum_sq = 0.0
    chunk_size = 8
    n_chunks = div(n, chunk_size)

    # Process complete chunks
    @fastmath @inbounds for chunk in 0:(n_chunks-1)
        chunk_sum = 0.0
        base_idx = chunk * chunk_size
        @simd for offset in 1:chunk_size
            i = base_idx + offset
            diff = p1[i] - p2[i]
            chunk_sum += diff * diff
        end
        sum_sq += chunk_sum

        # Check threshold after each chunk
        if sum_sq > thresh_sq
            return thresh + 1.0
        end
    end

    # Process remaining elements
    @fastmath @inbounds for i in (n_chunks * chunk_size + 1):n
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
    end

    # Final threshold check
    if sum_sq > thresh_sq
        return thresh + 1.0
    end

    return sqrt(sum_sq)
end

# Specialized version for small dimensions (unrolled for better performance)
@inline function _distance_small(p1, p2, thresh, thresh_sq, n)
    sum_sq = 0.0

    @fastmath @inbounds for i in 1:n
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
        if sum_sq > thresh_sq
            return thresh + 1.0
        end
    end

    return sqrt(sum_sq)
end

"""
    SquaredEuclideanMetric <: Metric

Squared Euclidean distance (L2 norm without square root).

``d(x, y) = \\sum_i (x_i - y_i)^2``

WARNING: This metric should ONLY be used with brute-force search, not with ATRIA.
The triangle inequality does not hold for squared distances, which breaks the
ATRIA pruning logic.

This metric is faster than Euclidean since it avoids the sqrt operation.
"""
struct SquaredEuclideanMetric <: Metric end

"""
    distance(::SquaredEuclideanMetric, p1, p2) -> Float64

Compute squared Euclidean distance between two points.
"""
@inline function distance(::SquaredEuclideanMetric, p1, p2)
    sum_sq = 0.0
    n = length(p1)
    @turbo for i in 1:n
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
    end
    return sum_sq
end

"""
    distance(::SquaredEuclideanMetric, p1, p2, thresh::Float64) -> Float64

Compute squared Euclidean distance with early termination.
"""
@inline function distance(::SquaredEuclideanMetric, p1, p2, thresh::Float64)
    sum_sq = 0.0

    # Note: Cannot use @simd here due to early termination
    @inbounds for i in eachindex(p1)
        diff = p1[i] - p2[i]
        sum_sq += diff * diff
        # Early termination
        if sum_sq > thresh
            return thresh + 1.0
        end
    end

    return sum_sq
end

"""
    MaximumMetric <: Metric

Maximum (Chebyshev) distance (L∞ norm).

``d(x, y) = \\max_i |x_i - y_i|``

This is the maximum absolute difference across all dimensions.
Useful for certain types of data where any single dimension's
difference is the limiting factor.
"""
struct MaximumMetric <: Metric end

"""
    distance(::MaximumMetric, p1, p2) -> Float64

Compute maximum distance between two points.
"""
@inline function distance(::MaximumMetric, p1, p2)
    max_dist = 0.0
    @inbounds for i in eachindex(p1)
        diff = abs(p1[i] - p2[i])
        max_dist = max(max_dist, diff)
    end
    return max_dist
end

"""
    distance(::MaximumMetric, p1, p2, thresh::Float64) -> Float64

Compute maximum distance with early termination.
"""
@inline function distance(::MaximumMetric, p1, p2, thresh::Float64)
    max_dist = 0.0

    @inbounds for i in eachindex(p1)
        diff = abs(p1[i] - p2[i])
        max_dist = max(max_dist, diff)
        # Early termination
        if max_dist > thresh
            return thresh + 1.0
        end
    end

    return max_dist
end

"""
    ExponentiallyWeightedEuclidean <: Metric

Exponentially weighted Euclidean distance.

``d(x, y) = \\sqrt{\\sum_i \\lambda^i (x_i - y_i)^2}``

where λ is the decay factor (0 < λ <= 1).

This metric gives more weight to earlier dimensions and exponentially
less weight to later dimensions. Useful for time series where recent
values are more important than distant past values.

# Fields
- `lambda::Float64`: Decay factor (0 < lambda <= 1)
"""
struct ExponentiallyWeightedEuclidean <: Metric
    lambda::Float64

    function ExponentiallyWeightedEuclidean(lambda::Float64)
        if lambda <= 0 || lambda > 1
            throw(ArgumentError("lambda must be in (0, 1], got $lambda"))
        end
        new(lambda)
    end
end

"""
    distance(metric::ExponentiallyWeightedEuclidean, p1, p2) -> Float64

Compute exponentially weighted Euclidean distance.
"""
@inline function distance(metric::ExponentiallyWeightedEuclidean, p1, p2)
    sum_sq = 0.0
    weight = 1.0
    lambda = metric.lambda

    # Note: Cannot use @simd here due to weight accumulation dependency
    @inbounds for i in eachindex(p1)
        diff = p1[i] - p2[i]
        sum_sq += weight * diff * diff
        weight *= lambda
    end

    return sqrt(sum_sq)
end

"""
    distance(metric::ExponentiallyWeightedEuclidean, p1, p2, thresh::Float64) -> Float64

Compute exponentially weighted Euclidean distance with early termination.
"""
@inline function distance(metric::ExponentiallyWeightedEuclidean, p1, p2, thresh::Float64)
    thresh_sq = thresh * thresh
    sum_sq = 0.0
    weight = 1.0
    lambda = metric.lambda

    @inbounds for i in eachindex(p1)
        diff = p1[i] - p2[i]
        sum_sq += weight * diff * diff

        # Early termination
        if sum_sq > thresh_sq
            return thresh + 1.0
        end

        weight *= lambda
    end

    return sqrt(sum_sq)
end

# Convenience aliases
const Euclidean = EuclideanMetric
const SquaredEuclidean = SquaredEuclideanMetric
const Maximum = MaximumMetric
const ChebyshevMetric = MaximumMetric
const Chebyshev = MaximumMetric

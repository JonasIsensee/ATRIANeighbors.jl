# Point set abstractions for ATRIA algorithm

using LinearAlgebra

"""
    EmbeddedPoint{T} <: AbstractVector{T}

Zero-allocation view into an embedded time series point.

This is a custom view type that provides AbstractVector interface
without allocating a new vector. It lazily computes indices into
the original time series data.

# Fields
- `data::Vector{T}`: The original time series
- `start_idx::Int`: Starting index in the time series
- `dim::Int`: Embedding dimension
- `delay::Int`: Time delay
"""
struct EmbeddedPoint{T} <: AbstractVector{T}
    data::Vector{T}
    start_idx::Int
    dim::Int
    delay::Int
end

Base.size(v::EmbeddedPoint) = (v.dim,)
Base.length(v::EmbeddedPoint) = v.dim
@inline Base.getindex(v::EmbeddedPoint, i::Int) = v.data[v.start_idx + (i - 1) * v.delay]
Base.IndexStyle(::Type{<:EmbeddedPoint}) = IndexLinear()

# Implement iterate for compatibility
@inline function Base.iterate(v::EmbeddedPoint, state=1)
    state > v.dim ? nothing : (v[state], state + 1)
end

# Implement eachindex for better performance
@inline Base.eachindex(v::EmbeddedPoint) = Base.OneTo(v.dim)

"""
    AbstractPointSet{T,D,M<:Metric}

Abstract base type for all point set representations.

Type parameters:
- `T`: Element type (e.g., Float64)
- `D`: Dimension (Int for fixed, Nothing for dynamic)
- `M`: Metric type

Each concrete point set should implement:
- `Base.size(ps)`: Return (N, D) where N is number of points, D is dimension
- `getpoint(ps, i)`: Return the i-th point as a vector
- `distance(ps, i, j)`: Distance between points i and j
- `distance(ps, i, query)`: Distance between point i and external query point
- `distance(ps, i, query, thresh)`: Distance with early termination threshold
"""
abstract type AbstractPointSet{T,D,M<:Metric} end

"""
    PointSet{T,D,M} <: AbstractPointSet{T,D,M}

Standard point set backed by a matrix.

The data matrix is N × D where each row is a point.

# Fields
- `data::Matrix{T}`: N × D matrix of points (row-major)
- `metric::M`: Distance metric to use

# Example
```julia
data = [0.0 0.0; 3.0 4.0; 1.0 1.0]  # 3 points in 2D
ps = PointSet(data, EuclideanMetric())
```
"""
struct PointSet{T,M<:Metric} <: AbstractPointSet{T,Int,M}
    data::Matrix{T}
    metric::M

    function PointSet(data::Matrix{T}, metric::M) where {T,M<:Metric}
        new{T,M}(data, metric)
    end
end

# Convenience constructor with default Euclidean metric
PointSet(data::Matrix{T}) where {T} = PointSet(data, EuclideanMetric())

"""
    size(ps::PointSet) -> Tuple{Int, Int}

Return (N, D) where N is the number of points and D is the dimension.
"""
Base.size(ps::PointSet) = size(ps.data)

"""
    getpoint(ps::PointSet, i::Int)

Get the i-th point as a view (zero-copy).
"""
@inline function getpoint(ps::PointSet, i::Int)
    return view(ps.data, i, :)
end

"""
    distance(ps::PointSet, i::Int, j::Int) -> Float64

Compute distance between the i-th and j-th points in the set.
"""
@inline function distance(ps::PointSet, i::Int, j::Int)
    p1 = getpoint(ps, i)
    p2 = getpoint(ps, j)
    return distance(ps.metric, p1, p2)
end

"""
    distance(ps::PointSet, i::Int, query) -> Float64

Compute distance between the i-th point and an external query point.
"""
@inline function distance(ps::PointSet, i::Int, query)
    # Specialized implementation for EuclideanMetric to avoid view overhead
    if ps.metric isa EuclideanMetric
        return _euclidean_distance_row(ps.data, i, query)
    else
        p = getpoint(ps, i)
        return distance(ps.metric, p, query)
    end
end

"""
    distance(ps::PointSet, i::Int, query, thresh::Float64) -> Float64

Compute distance with early termination threshold.
"""
@inline function distance(ps::PointSet, i::Int, query, thresh::Float64)
    # Specialized implementation for EuclideanMetric to avoid view overhead
    if ps.metric isa EuclideanMetric
        return _euclidean_distance_row_thresh(ps.data, i, query, thresh)
    else
        p = getpoint(ps, i)
        return distance(ps.metric, p, query, thresh)
    end
end

# Specialized implementations for Euclidean distance that work directly with matrix rows
# This avoids the overhead of creating views

"""
    _euclidean_distance_row(data::Matrix, row::Int, query) -> Float64

Compute Euclidean distance between a row of data and a query point.
Optimized to avoid view overhead.
"""
@inline function _euclidean_distance_row(data::Matrix{T}, row::Int, query) where T
    sum_sq = zero(T)
    @inbounds for j in 1:size(data, 2)
        diff = data[row, j] - query[j]
        sum_sq += diff * diff
    end
    return sqrt(sum_sq)
end

"""
    _euclidean_distance_row_thresh(data::Matrix, row::Int, query, thresh::Float64) -> Float64

Compute Euclidean distance with early termination.
Optimized to avoid view overhead.
"""
@inline function _euclidean_distance_row_thresh(data::Matrix{T}, row::Int, query, thresh::Float64) where T
    thresh_sq = thresh * thresh
    sum_sq = zero(T)

    @inbounds for j in 1:size(data, 2)
        diff = data[row, j] - query[j]
        sum_sq += diff * diff
        # Early termination
        if sum_sq > thresh_sq
            return thresh + 1.0
        end
    end

    return sqrt(sum_sq)
end

"""
    EmbeddedTimeSeries{T,M} <: AbstractPointSet{T,Nothing,M}

Point set with on-the-fly time-delay embedding of a time series.

This is memory-efficient: instead of storing all embedded vectors,
we compute them on-the-fly from the original time series.

# Fields
- `data::Vector{T}`: Original time series
- `dim::Int`: Embedding dimension
- `delay::Int`: Time delay
- `metric::M`: Distance metric

# Example
For a time series [x₁, x₂, x₃, x₄, x₅] with dim=3 and delay=1:
- Point 1: [x₁, x₂, x₃]
- Point 2: [x₂, x₃, x₄]
- Point 3: [x₃, x₄, x₅]

Number of embedded points: length(data) - (dim - 1) * delay
"""
struct EmbeddedTimeSeries{T,M<:Metric} <: AbstractPointSet{T,Nothing,M}
    data::Vector{T}
    dim::Int
    delay::Int
    metric::M

    function EmbeddedTimeSeries(data::Vector{T}, dim::Int, delay::Int,
                                metric::M) where {T,M<:Metric}
        if dim < 1
            throw(ArgumentError("dim must be >= 1, got $dim"))
        end
        if delay < 1
            throw(ArgumentError("delay must be >= 1, got $delay"))
        end
        n_points = length(data) - (dim - 1) * delay
        if n_points < 1
            throw(ArgumentError(
                "Not enough data for embedding: length=$(length(data)), " *
                "dim=$dim, delay=$delay requires at least $((dim-1)*delay+1) points"
            ))
        end
        new{T,M}(data, dim, delay, metric)
    end
end

# Convenience constructor with default Euclidean metric
function EmbeddedTimeSeries(data::Vector{T}, dim::Int, delay::Int=1) where {T}
    EmbeddedTimeSeries(data, dim, delay, EuclideanMetric())
end

"""
    size(ps::EmbeddedTimeSeries) -> Tuple{Int, Int}

Return (N, D) where N is the number of embedded points and D is the embedding dimension.
"""
function Base.size(ps::EmbeddedTimeSeries)
    n_points = length(ps.data) - (ps.dim - 1) * ps.delay
    return (n_points, ps.dim)
end

"""
    getpoint(ps::EmbeddedTimeSeries, i::Int) -> EmbeddedPoint

Get the i-th embedded point as a zero-allocation view.

Returns an EmbeddedPoint which implements AbstractVector interface
without allocating a new vector. This is a critical optimization since
getpoint is called thousands of times during tree construction and search.
"""
@inline function getpoint(ps::EmbeddedTimeSeries{T}, i::Int) where {T}
    return EmbeddedPoint(ps.data, i, ps.dim, ps.delay)
end

"""
    distance(ps::EmbeddedTimeSeries, i::Int, j::Int) -> Float64

Compute distance between the i-th and j-th embedded points.

Uses EmbeddedPoint views to avoid allocating full embedded vectors.
"""
@inline function distance(ps::EmbeddedTimeSeries, i::Int, j::Int)
    # EmbeddedPoint views are now zero-allocation
    p1 = getpoint(ps, i)
    p2 = getpoint(ps, j)
    return distance(ps.metric, p1, p2)
end

"""
    distance(ps::EmbeddedTimeSeries, i::Int, query) -> Float64

Compute distance between the i-th embedded point and a query point.
"""
@inline function distance(ps::EmbeddedTimeSeries, i::Int, query)
    p = getpoint(ps, i)
    return distance(ps.metric, p, query)
end

"""
    distance(ps::EmbeddedTimeSeries, i::Int, query, thresh::Float64) -> Float64

Compute distance with early termination threshold.
"""
@inline function distance(ps::EmbeddedTimeSeries, i::Int, query, thresh::Float64)
    p = getpoint(ps, i)
    return distance(ps.metric, p, query, thresh)
end

# Optimized distance calculation for EmbeddedTimeSeries that avoids allocation
# This version computes distance on-the-fly without materializing the points
"""
    distance_direct(ps::EmbeddedTimeSeries, i::Int, j::Int) -> Float64

Direct distance calculation without materializing embedded vectors (optimization).
"""
function distance_direct(ps::EmbeddedTimeSeries, i::Int, j::Int)
    # This would be an optimization for specific metrics
    # For now, we use the standard path
    return distance(ps, i, j)
end

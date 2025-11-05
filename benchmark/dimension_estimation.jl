# Fractal dimension estimation for benchmark validation
# Based on the Grassberger-Procaccia algorithm used in the ATRIA paper

"""
    correlation_sum(data::Matrix{Float64}, r::Float64; max_pairs::Int=10000)

Compute the correlation sum C(r) - the fraction of point pairs within distance r.

For a dataset with N points, C(r) = (1/N²) * |{(i,j) : ||x_i - x_j|| < r}|

# Arguments
- `data`: N×D matrix where each row is a point
- `r`: Distance threshold
- `max_pairs`: Maximum number of pairs to sample (for computational efficiency)

# Returns
- Correlation sum C(r) ∈ [0, 1]
"""
function correlation_sum(data::Matrix{Float64}, r::Float64; max_pairs::Int=10000)
    N, D = size(data)

    # For large N, sample random pairs to avoid O(N²) computation
    total_possible_pairs = N * (N - 1) ÷ 2

    if total_possible_pairs <= max_pairs
        # Compute all pairs
        count = 0
        for i in 1:N
            for j in (i+1):N
                dist = 0.0
                for d in 1:D
                    diff = data[i, d] - data[j, d]
                    dist += diff * diff
                end
                dist = sqrt(dist)
                if dist < r
                    count += 1
                end
            end
        end
        return count / total_possible_pairs
    else
        # Sample random pairs
        count = 0
        for _ in 1:max_pairs
            i = rand(1:N)
            j = rand(1:N)
            while i == j
                j = rand(1:N)
            end

            dist = 0.0
            for d in 1:D
                diff = data[i, d] - data[j, d]
                dist += diff * diff
            end
            dist = sqrt(dist)
            if dist < r
                count += 1
            end
        end
        return count / max_pairs
    end
end

"""
    estimate_correlation_dimension(data::Matrix{Float64};
                                   r_min::Union{Float64,Nothing}=nothing,
                                   r_max::Union{Float64,Nothing}=nothing,
                                   n_scales::Int=20,
                                   max_pairs::Int=10000)

Estimate the correlation dimension (D1) using the correlation sum method.

The correlation dimension is estimated as the slope of log(C(r)) vs log(r)
in the scaling region.

# Arguments
- `data`: N×D matrix where each row is a point
- `r_min`: Minimum distance scale (default: auto-detect from data)
- `r_max`: Maximum distance scale (default: auto-detect from data)
- `n_scales`: Number of distance scales to sample
- `max_pairs`: Maximum pairs to sample per scale

# Returns
- `(D1, r_values, C_values)`: Estimated dimension and raw data for plotting
"""
function estimate_correlation_dimension(data::Matrix{Float64};
                                       r_min::Union{Float64,Nothing}=nothing,
                                       r_max::Union{Float64,Nothing}=nothing,
                                       n_scales::Int=20,
                                       max_pairs::Int=10000)
    N, D = size(data)

    # Auto-detect distance range if not provided
    if r_min === nothing || r_max === nothing
        # Sample some random pairs to estimate typical distances
        sample_dists = Float64[]
        n_samples = min(1000, N * (N - 1) ÷ 2)
        for _ in 1:n_samples
            i = rand(1:N)
            j = rand(1:N)
            while i == j
                j = rand(1:N)
            end

            dist = 0.0
            for d in 1:D
                diff = data[i, d] - data[j, d]
                dist += diff * diff
            end
            push!(sample_dists, sqrt(dist))
        end

        sort!(sample_dists)
        if r_min === nothing
            r_min = sample_dists[max(1, length(sample_dists) ÷ 20)]  # 5th percentile
        end
        if r_max === nothing
            r_max = sample_dists[min(end, 19 * length(sample_dists) ÷ 20)]  # 95th percentile
        end
    end

    # Generate logarithmically-spaced distance scales
    r_values = exp.(range(log(r_min), log(r_max), length=n_scales))
    C_values = Float64[]

    println("Estimating correlation dimension...")
    println("Distance range: [$(round(r_min, digits=4)), $(round(r_max, digits=4))]")

    for (i, r) in enumerate(r_values)
        C_r = correlation_sum(data, r, max_pairs=max_pairs)
        push!(C_values, C_r)
        if i % 5 == 0 || i == 1 || i == n_scales
            println("  r = $(round(r, digits=4)), C(r) = $(round(C_r, digits=6))")
        end
    end

    # Estimate D1 as slope of log(C) vs log(r) in the linear region
    # Use middle 60% of points to avoid edge effects
    start_idx = max(1, n_scales ÷ 5)
    end_idx = min(n_scales, 4 * n_scales ÷ 5)

    # Filter out C_values that are 0 or 1 (outside scaling region)
    valid_indices = Int[]
    for i in start_idx:end_idx
        if C_values[i] > 1e-6 && C_values[i] < 0.999
            push!(valid_indices, i)
        end
    end

    if length(valid_indices) < 3
        @warn "Insufficient points in scaling region for reliable dimension estimate"
        return (NaN, r_values, C_values)
    end

    # Linear regression on log-log plot
    log_r = [log(r_values[i]) for i in valid_indices]
    log_C = [log(C_values[i]) for i in valid_indices]

    # Fit: log(C) = D1 * log(r) + const
    n = length(valid_indices)
    mean_log_r = sum(log_r) / n
    mean_log_C = sum(log_C) / n

    numerator = sum((log_r[i] - mean_log_r) * (log_C[i] - mean_log_C) for i in 1:n)
    denominator = sum((log_r[i] - mean_log_r)^2 for i in 1:n)

    D1 = numerator / denominator

    # Calculate R² for goodness of fit
    predicted_log_C = [D1 * log_r[i] + (mean_log_C - D1 * mean_log_r) for i in 1:n]
    ss_res = sum((log_C[i] - predicted_log_C[i])^2 for i in 1:n)
    ss_tot = sum((log_C[i] - mean_log_C)^2 for i in 1:n)
    R2 = 1 - ss_res / ss_tot

    println("\nEstimated correlation dimension D1 = $(round(D1, digits=3))")
    println("R² = $(round(R2, digits=4)) (goodness of fit)")
    println("Used $(length(valid_indices))/$(n_scales) points in scaling region")

    return (D1, r_values, C_values)
end

"""
    quick_dimension_estimate(data::Matrix{Float64}; max_pairs::Int=5000)

Quick estimate of correlation dimension using default parameters.
Suitable for rapid assessment during benchmarking.

# Arguments
- `data`: N×D matrix where each row is a point
- `max_pairs`: Maximum pairs to sample per scale (lower = faster but less accurate)

# Returns
- Estimated D1 value
"""
function quick_dimension_estimate(data::Matrix{Float64}; max_pairs::Int=5000)
    D1, _, _ = estimate_correlation_dimension(data, max_pairs=max_pairs)
    return D1
end

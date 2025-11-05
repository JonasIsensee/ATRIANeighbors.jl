# Benchmark Validation: Our Tests vs. Original ATRIA Publication

## Executive Summary

**Critical Finding:** We are **NOT testing ATRIA on its intended use cases!** The original publication tests primarily on **time-delay embedded chaotic attractors** with specific characteristics. Our tests use abstract clustered data that lacks the key geometric properties ATRIA was designed to exploit.

---

## Original Publication Test Specifications

### Data Set A: Hénon Map (PhysRevE.62.2089, page 4)

```
Type: Ds-dimensional generalization of iterated Hénon map
Dimensions: Ds = 2 to 12
Data size: N = 200,000 points
Information dimension D1: ~1 to ~9 (grows with Ds)
Parameters: a=1.76, b=0.1
```

**Purpose:** Test how performance scales with changing D1 when Ds also changes

---

### Data Set B: Rössler System (PhysRevE.62.2089, page 4-5)

```
Type: Hyperchaotic Rössler system with TIME-DELAY EMBEDDING
System dimension: M = 3, 5, 7, 9, 11 (varied)
Embedding dimension: Ds = 24 (FIXED!)
Time delay: τ = 9ΔT where ΔT = 0.1
Data size: N = 200,000 points
Information dimension D1: ~2 to ~8 (varies with M)
Parameters: a=0.28, b=4, d=2, ε=0.1
```

**Purpose:** Show that performance depends on D1, NOT Ds (Ds fixed at 24!)

**Key Result:** "Despite the very different dimension Ds of the data space, the resulting curves f1 and f128 are quite similar for both types of data sets. Focusing on the first intersection of the f1 curves, data set A's data space dimension Ds equals 3, while data set B's Ds is 24. This clearly indicates that this dimension is of little importance for the search efficiency of the algorithm."

---

### Data Set C: Lorenz Attractor (PhysRevE.62.2089, page 5)

```
Type: Standard Lorenz system with TIME-DELAY EMBEDDING
Embedding dimension: Ds = 25
Time delay: τ = ΔT = 0.025
Data size: N = 500,000 points (!)
Information dimension D1 ≈ 2.05 (very low!)
Parameters: σ=10, b=8/3, r=28
```

**Purpose:** Real-world nonlinear signal processing benchmark

---

## Key Performance Metric: Distance Calculation Fraction (f_k)

The paper's primary metric is:

**f_k = (# distance calculations) / (N × # queries)**

This is hardware-independent and measures algorithmic efficiency.

### Paper's Results (Figure 6):

| D1 | f_1 (k=1) | f_128 (k=128) |
|----|-----------|---------------|
| 2  | 0.001     | 0.003         |
| 3  | 0.002     | 0.008         |
| 4  | 0.005     | 0.015         |
| 5  | 0.015     | 0.040         |
| 6  | 0.035     | 0.080         |
| 8  | 0.100     | 0.200         |

**Interpretation:** At D1≈2, only 0.1-0.3% of distances are computed! At D1≈4-5, still only 1.5-4%.

---

## Our Current Benchmark Suite

### quick_test.jl

```
Datasets: gaussian_mixture, uniform_hypercube
Dimensions: D = 10
Data size: N = 100, 500, 1000
k: 10
Terminal nodes: min_points=10
```

**Issues:**
1. ❌ D=10 is relatively low, but...
2. ❌ **No measurement of fractal dimension D1!**
3. ❌ N=100-1000 is 100-2000x smaller than paper
4. ❌ Abstract synthetic data, not time-delay embedded attractors
5. ❌ min_points=10, paper uses L=64

---

### favorable_conditions_test.jl

```
Datasets: gaussian_mixture, hierarchical
Dimensions: D = 20, 50
Data size: N = 1000, 2000
k: 10, 50
Terminal nodes: min_points=32
```

**Issues:**
1. ⚠️ D=20-50 matches paper's embedding dimensions
2. ❌ **No measurement of fractal dimension D1!**
3. ❌ N=1000-2000 is 100-250x smaller than paper
4. ❌ Abstract synthetic data, not actual attractors
5. ⚠️ min_points=32 is closer to paper's L=64

---

## Critical Missing Element: Fractal Dimension (D1)

### Why D1 Matters

From the paper (page 6):

> "The number of distance calculations grows almost exponentially with D1."

> "Despite the very different dimension Ds of the data space, the resulting curves f1 and f128 are quite similar for both types of data sets... This clearly indicates that this dimension [Ds] is of little importance for the search efficiency of the algorithm."

**Our gaussian_mixture and hierarchical datasets:**
- We don't know their D1!
- D1 could be anywhere from ~log(#clusters) to ~D
- Without D1, we can't interpret results properly

### Information Dimension D1 Definition

From Halsey et al. (1986), referenced in paper:

```
D1 = lim(ε→0) Σi p_i log(p_i) / log(ε)
```

Where p_i is the probability of finding a point in box i of size ε.

**Practical computation:**
- Use correlation sum C(r) = (1/N²) Σ Θ(r - ||xi - xj||)
- D1 ≈ slope of log(C(r)) vs log(r) in scaling region

---

## What ATRIA Was Actually Designed For

### Use Case: Nonlinear Time Series Analysis (page 1)

> "The task of finding one or more nearest neighbors in a Ds-dimensional space occurs in many fields... especially for modeling and prediction of time series (via time-delay reconstruction), fast correlation sum computation (correlation dimension, generalized mutual information, etc.), estimation of the Renyi dimension spectrum or Lyapunov exponents, and nonlinear noise reduction."

### Design Goal

ATRIA excels when:
1. **High embedding dimension Ds** (20-25+)
2. **Low fractal dimension D1** (2-5)
3. **Data from time-delay embedding** of low-dimensional chaotic attractors
4. **Large datasets** (100,000+ points)

**Example:** Lorenz attractor
- Ds = 25 (high dimensional embedding space)
- D1 ≈ 2.05 (attractor is ~2D surface in 25D space)
- **Ratio Ds/D1 ≈ 12!** (Huge dimensional gap)

This is where ATRIA shines!

---

## Specific Issues with Our Benchmarks

### Issue 1: Data Size Too Small

**Paper:** N = 200,000 (standard), up to 500,000
**Us:** N = 1,000-2,000

**Impact:**
- Tree construction overhead is relatively much larger for small N
- Paper's benchmarks (Tables I-II) show ATRIA improves significantly as N grows
- At N=10,000, ATRIA is still slower than KDTree in some cases
- At N=50,000+, ATRIA pulls ahead (see Figures 8-9)

**From Table II:** For Lorenz (D1≈2.05):
- N=10,000: ATRIA query ~4-9s, KDTree ~3-11s (competitive)
- N=50,000: ATRIA query ~10s, KDTree ~13-428s (ATRIA wins!)

### Issue 2: No Fractal Dimension Measurement

**Paper:** Reports D1 for all datasets, plots f_k vs D1

**Us:** No D1 measurement at all

**Impact:**
- Can't verify if our "favorable" datasets actually have favorable D1
- gaussian_mixture might have D1 ≈ D (high!) depending on cluster separation
- Can't compare our f_k curves to paper's Figure 6

### Issue 3: Wrong Data Type

**Paper:**
- Primarily time-delay embedded chaotic attractors
- Tests specific dynamical systems (Lorenz, Rössler, Hénon)
- These have **intrinsic low-dimensional structure**

**Us:**
- Abstract gaussian_mixture (may not have attractor geometry)
- hierarchical (closer, but still not time-series data)
- No actual dynamical system embeddings

**Impact:**
- ATRIA was optimized for attractor geometry
- Our data may have different distance distributions
- Not testing the algorithm's intended domain

### Issue 4: Terminal Node Size

**Paper:** L = 64 for all tests

**Us:** min_points = 10 or 32

**Impact:**
- Smaller min_points = deeper tree = more overhead
- Paper found L≈64 is optimal trade-off
- Should match their parameter

### Issue 5: Query Protocol

**Paper:**
- Query points FROM the dataset
- Self-matches explicitly excluded
- 5,000-20,000 queries

**Us:**
- Add noise to data points for queries
- 20 queries (very few!)

**Impact:**
- Different query distribution
- Too few queries for stable statistics
- Can't directly compare to paper's results

---

## Recommended Benchmark Suite Corrections

### Priority 1: Implement Fractal Dimension Calculation ⭐⭐⭐

```julia
function estimate_information_dimension(data; r_values=nothing, n_samples=10000)
    """
    Estimate D1 using correlation sum approach
    Returns: D1, log_r, log_C for plotting
    """
    N = size(data, 1)

    # Sample point pairs
    indices = sample(1:N, min(n_samples, N), replace=false)

    # Compute pairwise distances
    distances = compute_pairwise_distances(data, indices)

    # Correlation sum at different scales
    if r_values === nothing
        r_min, r_max = quantile(distances, [0.01, 0.99])
        r_values = exp.(range(log(r_min), log(r_max), length=50))
    end

    C_r = [mean(distances .< r) for r in r_values]

    # Fit line to log-log plot in scaling region
    valid = (C_r .> 0.001) .& (C_r .< 0.9)
    if sum(valid) < 10
        @warn "Insufficient scaling region"
        return NaN, log.(r_values), log.(C_r)
    end

    # Linear regression
    X = log.(r_values[valid])
    Y = log.(C_r[valid])
    D1 = linreg_slope(X, Y)

    return D1, log.(r_values), log.(C_r)
end
```

### Priority 2: Add Chaotic Attractor Generators ⭐⭐⭐

```julia
function generate_lorenz_attractor(N; τ=0.025, Ds=25, transient=40000)
    """
    Generate Lorenz attractor with time-delay embedding
    Matches paper's Data Set C
    """
    # Integrate Lorenz system
    σ, ρ, β = 10.0, 28.0, 8.0/3.0

    function lorenz!(du, u, p, t)
        du[1] = σ*(u[2] - u[1])
        du[2] = u[1]*(ρ - u[3]) - u[2]
        du[3] = u[1]*u[2] - β*u[3]
    end

    # Integrate
    u0 = randn(3)
    tspan = (0.0, τ * (transient + N * Ds))
    prob = ODEProblem(lorenz!, u0, tspan)
    sol = solve(prob, saveat=τ)

    # Take x1 component, discard transient
    x1 = [s[1] for s in sol.u]
    x1 = x1[transient+1:end]

    # Time-delay embedding
    data = zeros(N, Ds)
    for i in 1:N
        for d in 1:Ds
            data[i, d] = x1[i + (d-1)]
        end
    end

    return data
end

function generate_rossler_hyperchaotic(N; M=5, Ds=24, τ=0.9, transient=10000)
    """
    Generate hyperchaotic Rössler system
    Matches paper's Data Set B
    """
    # M-dimensional Rössler system
    # Parameters: a=0.28, b=4, d=2, ε=0.1
    # ... (implement as per paper)
end

function generate_henon_map(N; Ds=8)
    """
    Generate Ds-dimensional Hénon map
    Matches paper's Data Set A
    """
    # ... (implement as per paper)
end
```

### Priority 3: Larger Datasets ⭐⭐

Test with:
- N = 10,000 (minimum)
- N = 50,000 (good)
- N = 200,000 (matches paper)

### Priority 4: Match Paper's Protocol ⭐

```julia
# Query on actual data points
query_indices = sample(1:N, n_queries, replace=false)
queries = data[query_indices, :]

# Exclude self-matches in search
for (i, query_idx) in enumerate(query_indices)
    neighbors = knn(tree, queries[i, :], k=k+1,
                    exclude_range=(query_idx, query_idx))
    # Filter out self-match
    neighbors = [n for n in neighbors if n.index != query_idx][1:k]
end
```

### Priority 5: Report f_k Metric ⭐⭐

Track and report distance calculation fraction:

```julia
mutable struct SearchStats
    distance_calculations::Int
    clusters_visited::Int
end

# During search, increment stats.distance_calculations

# After search:
f_k = stats.distance_calculations / (N * n_queries)
println("Distance fraction f_$k = $f_k")
```

---

## Proposed New Benchmark Suite

### Benchmark 1: Lorenz Attractor (Paper's Data Set C)

```julia
Configuration:
- N = 200,000 (or 50,000 if too slow)
- Ds = 25 (time-delay embedding)
- τ = 0.025
- Expected D1 ≈ 2.05
- k = 1, 12, 128
- n_queries = 10,000
- min_points = 64

Expected result: ATRIA should significantly outperform KDTree
Paper shows: At N=50,000, ATRIA ~10s vs KDTree ~428s (L2 metric)
```

### Benchmark 2: Rössler System (Paper's Data Set B)

```julia
Configurations:
- M = 3, 5, 7, 9 (system dimensions)
- N = 200,000
- Ds = 24 (FIXED embedding dimension)
- Expected D1 ≈ 2-8 (varies with M)
- k = 1, 128
- n_queries = 5,000
- min_points = 64

Expected result: Performance should depend on D1, not Ds
Can plot f_k vs D1 and compare to paper's Figure 6
```

### Benchmark 3: Dimensional Scaling (Paper's Data Set A)

```julia
Configurations:
- Ds = 2, 4, 6, 8, 10, 12 (Hénon map dimension)
- N = 200,000
- Expected D1 grows with Ds
- k = 1, 128
- n_queries = 5,000
- min_points = 64

Expected result: Can replicate paper's Figure 5
Shows how performance scales with D1
```

---

## Expected Outcomes After Fixes

### If We Test on Correct Data:

**Lorenz (D1≈2.05, Ds=25, N=50,000+):**
- ATRIA should compute only ~0.1-0.5% of distances
- Query time should be **significantly faster** than KDTree
- This is ATRIA's sweet spot!

**Rössler (D1≈4-5, Ds=24, N=200,000):**
- ATRIA should compute ~1-2% of distances
- Should match or beat KDTree

**Current Abstract Data:**
- Unknown D1 (might be high!)
- If D1 ≈ D, then ATRIA struggles (as we're seeing)
- Not representative of ATRIA's design goals

---

## Summary Table: Paper vs. Our Tests

| Aspect | Paper | Our Current | Issue |
|--------|-------|-------------|-------|
| **Data size N** | 200,000-500,000 | 1,000-2,000 | ❌ 100x too small |
| **Data type** | Time-delay embedded attractors | Abstract clusters | ❌ Wrong domain |
| **Embedding dim Ds** | 24-25 | 10-50 | ⚠️ Range OK, but... |
| **Fractal dim D1** | Measured & reported | NOT measured | ❌ Can't interpret results |
| **Ds/D1 ratio** | ~10-12 (huge gap!) | Unknown | ❌ Key metric missing |
| **Terminal nodes L** | 64 | 10-32 | ⚠️ Should match |
| **Number of queries** | 5,000-20,000 | 20 | ❌ Too few for statistics |
| **Query protocol** | From dataset, exclude self | Add noise | ⚠️ Different distribution |
| **Metric tracked** | f_k (distance fraction) | Time only | ❌ Missing key metric |
| **Dynamical systems** | Lorenz, Rössler, Hénon | None | ❌ Not testing use case |

---

## Action Plan

### Immediate (High Priority):

1. **Implement D1 estimation** - Essential for interpretation
2. **Add Lorenz attractor generator** - Paper's main benchmark
3. **Test at N=50,000+** - Where ATRIA advantages appear
4. **Track f_k metric** - Hardware-independent comparison

### Important (Medium Priority):

5. **Add Rössler generator** - Validates D1 independence from Ds
6. **Increase n_queries to 1,000+** - Better statistics
7. **Set min_points=64** - Match paper's parameter
8. **Use self-match exclusion** - Match paper's protocol

### Nice to Have (Low Priority):

9. **Add Hénon map generator** - Complete replication
10. **Test up to N=200,000** - Full paper replication
11. **Plot f_k vs D1** - Direct comparison to Figure 6

---

## Conclusion

**We are NOT testing ATRIA under conditions where it was designed to excel:**

1. ❌ Data size too small (1-2K vs 200K)
2. ❌ Wrong data type (abstract clusters vs chaotic attractors)
3. ❌ Missing critical metric (D1 fractal dimension)
4. ❌ Not testing on dynamical systems (ATRIA's intended use)

**The paper shows ATRIA excels when:**
- D1 ≈ 2-5 (low fractal dimension)
- Ds ≈ 20-25 (high embedding dimension)
- N ≥ 50,000 (large datasets)
- Data from time-delay embeddings

**Our tests use:**
- D1 = unknown (possibly high!)
- Ds = 10-50 (variable)
- N = 1,000-2,000 (small)
- Abstract synthetic data

**This explains why ATRIA underperforms in our benchmarks!** We need to test on the algorithm's intended domain to see its advantages.

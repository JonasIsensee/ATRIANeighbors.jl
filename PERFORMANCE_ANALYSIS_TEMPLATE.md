# Performance Analysis Template

**Date:** [YYYY-MM-DD]
**Analyst:** [Human/AI Model Name]
**Profile Run:** [Minimal/Comprehensive]
**Commit:** [Git commit hash]

---

## Executive Summary

**Total Samples:** [N]
**Top Bottleneck:** [Function name] ([X]% of samples)
**Estimated Speedup Potential:** [X]x (if top 3 bottlenecks eliminated)

---

## Top 5 Hotspots

### 1. [Function Name] - [file.jl:line]
- **Samples:** [N] ([X]%)
- **Category:** [Distance/Heap/Partition/Search/PointAccess/Other]
- **Description:** [What this function does]
- **Why it's slow:** [Root cause analysis]
- **Proposed fix:** [Specific optimization]
- **Expected impact:** [X]% reduction in samples
- **Risk:** [Low/Medium/High]

### 2. [Function Name] - [file.jl:line]
[Same format as above]

### 3. [Function Name] - [file.jl:line]
[Same format as above]

### 4. [Function Name] - [file.jl:line]
[Same format as above]

### 5. [Function Name] - [file.jl:line]
[Same format as above]

---

## Category Breakdown

| Category | Samples | % Total | Status |
|----------|---------|---------|--------|
| Distance Calculations | [N] | [X]% | [OK/Needs Optimization] |
| Heap Operations | [N] | [X]% | [OK/Needs Optimization] |
| Tree Construction | [N] | [X]% | [OK/Needs Optimization] |
| Search Operations | [N] | [X]% | [OK/Needs Optimization] |
| Point Access | [N] | [X]% | [OK/Needs Optimization] |
| Other/Unknown | [N] | [X]% | [OK/Needs Optimization] |

---

## Detailed Analysis

### Distance Calculations ([X]% of samples)

**Functions:**
- `function_name` (file.jl:line) - [N] samples
- `function_name` (file.jl:line) - [N] samples

**Issues Found:**
- [ ] Missing `@inbounds` annotations
- [ ] Missing `@simd` annotations
- [ ] Missing `@inline` annotations
- [ ] Early termination not implemented/inefficient
- [ ] Type instabilities detected
- [ ] Unnecessary allocations

**Recommended Fixes:**
1. [Specific fix with code location]
2. [Specific fix with code location]

---

### Heap Operations ([X]% of samples)

**Functions:**
- `function_name` (file.jl:line) - [N] samples
- `function_name` (file.jl:line) - [N] samples

**Issues Found:**
- [ ] Using dynamic arrays instead of StaticArrays
- [ ] Unnecessary allocations in hot path
- [ ] Inefficient heap implementation
- [ ] Redundant operations

**Recommended Fixes:**
1. [Specific fix with code location]
2. [Specific fix with code location]

---

### Tree Construction ([X]% of samples)

**Functions:**
- `function_name` (file.jl:line) - [N] samples
- `function_name` (file.jl:line) - [N] samples

**Issues Found:**
- [ ] Poor cache locality
- [ ] Unnecessary allocations
- [ ] Missing `@inbounds`
- [ ] Inefficient partition algorithm

**Recommended Fixes:**
1. [Specific fix with code location]
2. [Specific fix with code location]

---

### Search Operations ([X]% of samples)

**Functions:**
- `function_name` (file.jl:line) - [N] samples
- `function_name` (file.jl:line) - [N] samples

**Issues Found:**
- [ ] Inefficient priority queue operations
- [ ] Unnecessary allocations
- [ ] Missing `@inbounds` for permutation table access
- [ ] Redundant distance calculations

**Recommended Fixes:**
1. [Specific fix with code location]
2. [Specific fix with code location]

---

### Point Access ([X]% of samples)

**Functions:**
- `function_name` (file.jl:line) - [N] samples
- `function_name` (file.jl:line) - [N] samples

**Issues Found:**
- [ ] Type instabilities
- [ ] Missing `@inline`
- [ ] Inefficient bounds checking
- [ ] Unnecessary copies

**Recommended Fixes:**
1. [Specific fix with code location]
2. [Specific fix with code location]

---

## Code Examples

### Example 1: [Optimization Name]

**Location:** `src/file.jl:line`

**Before:**
```julia
function slow_function(x, y)
    result = 0.0
    for i in 1:length(x)
        result += (x[i] - y[i])^2
    end
    return sqrt(result)
end
```

**After:**
```julia
@inline function fast_function(x, y)
    result = 0.0
    @inbounds @simd for i in 1:length(x)
        result += (x[i] - y[i])^2
    end
    return sqrt(result)
end
```

**Expected Impact:** [X]% reduction in this function's samples

---

### Example 2: [Optimization Name]

[Same format as above]

---

## Type Stability Analysis

### Functions Checked

- [ ] `distance` functions in `metrics.jl`
- [ ] `getpoint` in `pointsets.jl`
- [ ] `assign_points_to_centers!` in `tree.jl`
- [ ] `knn` in `search.jl`
- [ ] `heap operations` in `structures.jl`

### Issues Found

| Function | File:Line | Issue | Fix |
|----------|-----------|-------|-----|
| [name] | file.jl:N | [Type instability description] | [Proposed fix] |

---

## Allocation Analysis

| Function | Current Allocations | Target | Fix |
|----------|-------------------|--------|-----|
| [name] | [N bytes] | [N bytes] | [Description] |

---

## Implementation Priority

### High Priority (>10% improvement potential)
1. [Optimization] - Expected [X]% improvement
2. [Optimization] - Expected [X]% improvement

### Medium Priority (5-10% improvement potential)
1. [Optimization] - Expected [X]% improvement
2. [Optimization] - Expected [X]% improvement

### Low Priority (<5% improvement potential)
1. [Optimization] - Expected [X]% improvement
2. [Optimization] - Expected [X]% improvement

---

## Risks and Considerations

### Safety Concerns
- Using `@inbounds` in [location]: [Justification for safety]
- Using `@inbounds` in [location]: [Justification for safety]

### Correctness
- [ ] All proposed optimizations preserve exact numerical results
- [ ] Tests will verify correctness after each optimization
- [ ] Edge cases have been considered

### Maintainability
- [ ] Optimizations don't significantly harm readability
- [ ] Comments added to explain non-obvious optimizations
- [ ] Complex optimizations have benchmark tests

---

## Verification Plan

### Before Optimization
- [ ] Run profiling: `./profile.sh`
- [ ] Run benchmarks: `julia --project=benchmark benchmark/quick_test.jl`
- [ ] Run tests: `julia --project=. -e 'using Pkg; Pkg.test()'`
- [ ] Save baseline results

### After Each Optimization
- [ ] Run tests to ensure correctness
- [ ] Run profiling to measure impact
- [ ] Run benchmarks to measure speedup
- [ ] Verify expected sample reduction

### Final Verification
- [ ] Overall speedup: [X]x (target: [Y]x)
- [ ] All tests passing
- [ ] No new type instabilities
- [ ] No increase in allocations

---

## Benchmark Results

### Before Optimizations

```
Dataset              N    ATRIA (ms)  KDTree (ms)  Brute (ms)  vs Brute  vs KDTree
gaussian_mixture   1000        X.XXX       X.XXX      X.XXX     X.XXx     X.XXx
```

### After Optimizations

```
Dataset              N    ATRIA (ms)  KDTree (ms)  Brute (ms)  vs Brute  vs KDTree
gaussian_mixture   1000        X.XXX       X.XXX      X.XXX     X.XXx     X.XXx
```

### Improvement Summary

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Build Time | X.XX s | X.XX s | X.X% |
| Query Time | X.XX ms | X.XX ms | X.X% |
| Speedup vs Brute | X.Xx | X.Xx | X.X% |
| Speedup vs KDTree | X.Xx | X.Xx | X.X% |

---

## Next Steps

1. [ ] Implement high-priority optimizations
2. [ ] Run verification tests
3. [ ] Measure actual improvements
4. [ ] Update this analysis with results
5. [ ] Commit changes with detailed description
6. [ ] Consider medium-priority optimizations if needed

---

## Notes

[Any additional observations, concerns, or context]

---

## References

- Profile output: `profile_results/profile_summary.txt`
- Detailed tree: `profile_results/profile_tree.txt`
- Flat view: `profile_results/profile_flat.txt`
- Julia Performance Tips: https://docs.julialang.org/en/v1/manual/performance-tips/

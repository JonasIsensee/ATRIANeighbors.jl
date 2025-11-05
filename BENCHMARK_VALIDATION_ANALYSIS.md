# Benchmark Methodology Notes

## ATRIA's Intended Use Cases

**Critical:** ATRIA was designed for **time-delay embedded chaotic attractors**, not generic high-dimensional data.

## Original Paper Test Specifications (PhysRevE.62.2089)

### Data Characteristics
- **Data size:** N = 200,000 - 500,000 points
- **Embedding dimension:** Ds = 24-25 (high dimensional)
- **Fractal dimension:** D1 = 2-5 (low dimensional structure)
- **Terminal nodes:** L = 64
- **Primary metric:** f_k = (distance calculations) / (N × queries)

### Test Datasets
1. **Lorenz Attractor** - Ds=25, D1≈2.05, N=500,000
2. **Rössler System** - Ds=24, D1≈2-8 (varies), N=200,000
3. **Hénon Map** - Ds=2-12, D1≈1-9, N=200,000

## Key Insight

**Performance depends on D1 (fractal dimension), NOT Ds (embedding dimension).**

ATRIA excels when:
- High Ds (20-25+) with low D1 (2-5)
- Large datasets (N > 50,000)
- Data from dynamical systems with low-dimensional attractors

## Implementation Notes

The `benchmark/` directory contains generators for Lorenz, Rössler, and Hénon systems matching the paper's specifications. See `benchmark/PAPER_FINDINGS.md` for detailed results.

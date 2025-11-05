# Materials Folder Overview

## Summary

The materials folder contains a complete C++ implementation of the **ATRIA (Advanced TRiangle Inequality Algorithm)** nearest neighbor search algorithm, originally developed by Christian Merkwirth at DPI Göttingen (1998-2000). This is a highly optimized algorithm specifically designed for efficient nearest neighbor searching in high-dimensional spaces with unevenly distributed points.

## Contents

### 1. Documentation Files

- **PhysRevE.62.2089.pdf** - Research paper providing theoretical background
- **manual.pdf** - User manual for the original implementation (517 KB)

### 2. Core Algorithm Implementation (`NNSearcher/`)

The heart of the algorithm, containing header files with template-based implementations:

#### `nearneigh_search.h` (Main Algorithm - 939 lines)
- **Base class**: `nearneigh_searcher<POINT_SET>` - Common interface for all search algorithms
- **Brute Force**: `Brute<POINT_SET>` - O(N²) simple linear search (good for small datasets or few queries)
- **ATRIA**: `ATRIA<POINT_SET>` - Advanced algorithm using triangle inequality for efficient search

**Key Features:**
- k-nearest neighbor search (find k closest points)
- Range search (find all points within distance r)
- Count range (correlation sum - count points within distance)
- Supports excluding temporal neighbors (useful for time series)
- Approximative queries (epsilon-approximate nearest neighbors)
- Multiple metrics support
- Profiling capabilities

**Algorithm Parameters:**
- `ATRIAMINPOINTS = 64` - Minimum points in a cluster before subdivision stops

#### `point_set.h` (Data Abstraction - 246 lines)
Defines how point data is stored and accessed:
- **`point_set<METRIC>`** - Standard point set (for matrices)
- **`embedded_time_series_point_set<METRIC>`** - On-the-fly time-delay embedding (memory efficient)
- **`C_point_set<METRIC>`** - C-style row-major matrix format
- **`spherical_point_set`** - Points on sphere surface
- **`interleaved_pointer`** - Smart pointer for matrix iteration

#### `metric.h` (Distance Functions - 175 lines)
Templated distance metrics:
- **Euclidean distance** - Standard L2 norm
- **Squared Euclidean distance** - Without sqrt (faster, use only with Brute)
- **Exponentially weighted Euclidean** - Weighted distance with decay
- **Maximum distance** - L∞ norm (max absolute difference)

**Special Feature**: Partial distance calculation - early termination when distance exceeds threshold (significant speedup)

#### `nn_aux.h` (Auxiliary Structures - 153 lines)
Core data structures:
- **`neighbor`** - Stores index and distance
- **`SortedNeighborTable`** - Priority queue for k-nearest neighbors
- **`cluster`** - Tree node for ATRIA algorithm
  - Stores center point, max radius (Rmax), min gap (g_min)
  - Uses union for terminal/non-terminal node efficiency
  - Terminal nodes: stores start index and length of point section
  - Non-terminal nodes: stores left/right child pointers
- **`searchitem`** - Search queue item with bounds (d_min, d_max) for pruning

#### `nn_predictor.h` - Prediction routines (not examined in detail)
#### `nn2matlab.h` - MATLAB interface helpers

#### `nn_aux.cpp` - Implementation of auxiliary functions

### 3. MATLAB MEX Wrappers (`NN/NN/`)

Applications and wrappers for MATLAB:

**Preprocessing & Search:**
- `nn_prepare.cpp` - Preprocesses dataset, builds ATRIA tree structure
- `nn_search.cpp` - Performs k-NN search using preprocessed structure
- `create_searcher.cpp` - Creates and stores searcher object

**Analysis Tools:**
- `fnearneigh.cpp` - Fast nearest neighbor (all-in-one)
- `range_search.cpp` - Range-based neighbor search
- `corrsum.cpp` - Correlation sum calculation
- `corrsum2.cpp` - Alternative correlation sum
- `crosscorrsum.cpp` - Cross-correlation sum
- `cao.cpp` - Cao's method for dimension estimation
- `takens_estimator.cpp` - Takens estimator
- `largelyap.cpp` - Largest Lyapunov exponent
- `predict.cpp`, `predict2.cpp` - Prediction algorithms
- `crossprediction.cpp` - Cross-prediction
- `emb_nn_search.cpp` - Embedded time series search
- `return_time.cpp` - Return time statistics

**Test Suite** (`NN/NN/TestSuite/`):
- `test.m` - Comprehensive test suite
- `brute.m` - MATLAB brute force reference implementation
- `points.dat`, `querypoints.dat`, `result.dat` - Test data
- `recompile.m` - Recompilation script

### 4. Ternary Search Tree (`TernarySearchTree/`)

Alternative data structure implementation:

#### `ternary_search_tree.h` (131 lines)
- Memory-efficient tree for multi-key data
- Used for applications like box counting and mutual information
- Fixed key length, buffered allocation for performance

**Applications:**
- `BoxCounting/boxcount.cpp` - Box counting dimension
- `MutualInformation/amutual.cpp` - Mutual information calculation

### 5. Utilities (`Utils/`)

- `loadascii.cpp` - ASCII data loading
- `mixembed.cpp` - Mixed embedding
- `randref.cpp` - Random reference generation
- `mtrand.cpp` - Mersenne Twister random number generator

## ATRIA Algorithm - How It Works

### Preprocessing Phase (Tree Construction)

1. **Initialization**: Select random center point for root cluster
2. **Recursive Division**: For each cluster with > MINPOINTS:
   - Find two cluster centers:
     - Right center: Point farthest from current center
     - Left center: Point farthest from right center
   - Partition points using quicksort-like procedure
   - Assign each point to nearest center
   - Calculate Rmax (max radius) and g_min (min gap between clusters)
   - Create two child clusters
3. **Terminal Nodes**: Clusters with ≤ MINPOINTS are marked as terminal (Rmax set negative)

**Data Structure**: Binary tree with permutation table storing point indices and distances

### Search Phase (k-NN Query)

1. **Priority Queue**: Initialize with root cluster
2. **Best-First Search**: Process clusters by minimum possible distance (d_min)
3. **Triangle Inequality Pruning**:
   - Use precomputed distances to cluster centers
   - Calculate bounds: d_min and d_max for each cluster
   - Skip clusters where d_min > current k-th nearest distance
4. **Terminal Node Processing**:
   - Use stored distances for additional pruning
   - Test only promising points
5. **Early Termination**: When queue is empty or no better candidates exist

**Complexity**: Much better than O(N²) for typical cases, especially in high dimensions

### Key Optimizations

1. **Triangle Inequality**: Avoids distance calculations using precomputed center distances
2. **Partial Distance Calculation**: Stops computing distance when threshold exceeded
3. **g_min (Gap Minimum)**: Additional pruning using minimum gap between clusters
4. **Memory Layout**: Permutation table for cache-friendly access
5. **Approximative Search**: Allows (1+ε)-approximate neighbors for extra speed

## Use Cases

The algorithm is particularly well-suited for:
- **High-dimensional data** (where tree-based methods often fail)
- **Unevenly distributed points** (ATRIA adapts to data distribution)
- **Time series analysis** (supports temporal exclusion, embedding)
- **Multiple queries** (preprocessing amortized over many searches)
- **Nonlinear dynamics** (Lyapunov exponents, prediction, dimension estimation)

## Implementation Considerations for Julia

### Advantages to Leverage
1. Julia's type system maps well to C++ templates
2. Multiple dispatch natural for different metrics
3. SIMD and performance optimizations available
4. Easy integration with test data

### Challenges
1. Memory management (C++ uses manual allocation, Julia uses GC)
2. Balancing abstraction vs performance
3. Ensuring type stability throughout
4. Cache-friendly data layouts

### Performance Goals
- Match or exceed C++ performance
- Leverage Julia's strengths (SIMD, inlining, specialization)
- Provide clean, idiomatic API
- Support both in-place and allocating operations

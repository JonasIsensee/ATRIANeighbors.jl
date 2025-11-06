"""
demo_workload.jl

Demo workload with linear algebra operations for testing profiling.
These functions are designed to be identifiable in profile data.
"""

using LinearAlgebra

"""
    matrix_multiply(N::Int, iterations::Int)

Perform matrix multiplication multiple times.
This should show up as a hotspot in profiling.
"""
function matrix_multiply(N::Int, iterations::Int)
    result = 0.0
    for _ in 1:iterations
        A = rand(N, N)
        B = rand(N, N)
        C = A * B
        result += sum(C)
    end
    return result
end

"""
    solve_linear_system(N::Int, iterations::Int)

Solve linear systems using LU factorization.
This should be another identifiable hotspot.
"""
function solve_linear_system(N::Int, iterations::Int)
    result = 0.0
    for _ in 1:iterations
        A = rand(N, N) + I
        b = rand(N)
        x = A \ b
        result += sum(x)
    end
    return result
end

"""
    compute_eigenvalues(N::Int, iterations::Int)

Compute eigenvalues of matrices.
This is typically an expensive operation.
"""
function compute_eigenvalues(N::Int, iterations::Int)
    result = 0.0
    for _ in 1:iterations
        A = rand(N, N)
        A = (A + A') / 2  # Make symmetric
        λ = eigvals(A)
        result += sum(λ)
    end
    return result
end

"""
    qr_decomposition(N::Int, iterations::Int)

Perform QR decomposition multiple times.
"""
function qr_decomposition(N::Int, iterations::Int)
    result = 0.0
    for _ in 1:iterations
        A = rand(N, N)
        F = qr(A)
        # Extract Q and R matrices and compute sums
        result += sum(Matrix(F.Q)) + sum(F.R)
    end
    return result
end

"""
    vector_operations(N::Int, iterations::Int)

Basic vector operations - this should be relatively fast.
"""
function vector_operations(N::Int, iterations::Int)
    result = 0.0
    for _ in 1:iterations
        v = rand(N)
        w = rand(N)
        result += dot(v, w) + norm(v) + norm(w)
    end
    return result
end

"""
    run_demo_workload(; duration_seconds=3.0)

Run a balanced workload for approximately the specified duration.

This workload is designed to:
1. Run long enough to collect meaningful profile data
2. Have identifiable hotspots (matrix_multiply, solve_linear_system, compute_eigenvalues)
3. Be reproducible (same functions will be top hotspots)

Returns a tuple of (matrix_multiply_result, linear_system_result, eigenvalue_result,
                    qr_result, vector_result)
"""
function run_demo_workload(; duration_seconds=3.0)
    # Warm up to estimate timing
    matrix_multiply(10, 1)

    # Estimate how many iterations we need
    # Adjust these to balance time spent in each function
    mat_size = 100

    # These operations have different costs, so we use different iteration counts
    # Matrix multiply: Most expensive, fewer iterations
    mat_mult_iters = 50

    # Linear solve: Medium cost
    linear_solve_iters = 30

    # Eigenvalues: Very expensive, fewest iterations
    eigen_iters = 15

    # QR: Medium-high cost
    qr_iters = 25

    # Vector ops: Cheap, many iterations
    vector_iters = 1000

    println("Running demo workload...")
    println("  - Matrix multiplication ($mat_mult_iters iterations)")
    println("  - Linear system solving ($linear_solve_iters iterations)")
    println("  - Eigenvalue computation ($eigen_iters iterations)")
    println("  - QR decomposition ($qr_iters iterations)")
    println("  - Vector operations ($vector_iters iterations)")

    r1 = matrix_multiply(mat_size, mat_mult_iters)
    r2 = solve_linear_system(mat_size, linear_solve_iters)
    r3 = compute_eigenvalues(mat_size, eigen_iters)
    r4 = qr_decomposition(mat_size, qr_iters)
    r5 = vector_operations(mat_size * 10, vector_iters)

    println("Demo workload completed.")

    return (r1, r2, r3, r4, r5)
end

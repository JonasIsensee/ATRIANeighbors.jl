"""
    test_library_comparison.jl

Quick test of the library comparison framework.
Runs a small benchmark to verify all libraries are working.
"""

using Pkg
Pkg.activate(@__DIR__)

@info "Loading packages..."
include("library_comparison.jl")

@info "Running quick library comparison test..."

# Test with small dataset
results = run_comprehensive_library_comparison(
    dataset_types=[:gaussian_mixture, :uniform_hypercube],
    N_values=[500, 1000],
    D_values=[10],
    k_values=[10],
    n_queries=20,
    trials=2,
    use_cache=false,  # Don't use cache for testing
    verbose=true
)

@info "Test complete! Collected $(length(results)) results"

# Print summary
println("\n" * "="^80)
println("QUICK TEST RESULTS")
println("="^80)
print_results_table(results, sortby=:algorithm)

# Generate a quick report
output_dir = joinpath(@__DIR__, "results", "test_report")
generate_comparison_report(results, output_dir)

@info "Test report generated at: $output_dir"
@info "✓ Library comparison framework is working correctly!"

"""
type_stability.jl

Helper functions for checking type stability and detecting dynamic dispatch.
"""

using InteractiveUtils

"""
    check_type_stability_simple(f::Function, types::Tuple) -> Bool

Quick check if function is type-stable.

Returns true if function appears type-stable, false otherwise.

# Example
```julia
is_stable = check_type_stability_simple(my_function, (Int, Float64))
```

Note: For detailed analysis, use `@code_warntype` directly in the REPL.
"""
function check_type_stability_simple(f::Function, types::Tuple)
    # Capture @code_warntype output
    io = IOBuffer()
    InteractiveUtils.code_warntype(io, f, types; optimize=false)
    output = String(take!(io))

    # Check for common instability indicators
    has_any = contains(output, "Body::Any")
    has_union = contains(output, r"Body::Union\{[^}]+\}")

    # Type-stable if no Any or Union in return type
    return !has_any && !has_union
end

"""
    print_type_stability_guide()

Print guide for checking type stability manually.
"""
function print_type_stability_guide()
    println("""
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                         TYPE STABILITY CHECKING GUIDE                      ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    Type instabilities cause dynamic dispatch and can make code 10-100x slower!

    HOW TO CHECK:
    -------------
    In the Julia REPL:

        julia> using YourPackage
        julia> @code_warntype your_function(args...)

    WHAT TO LOOK FOR:
    -----------------
    🔴 Body::Any
       → Complete type instability (FIX IMMEDIATELY!)
       → Return type cannot be inferred

    🟡 Body::Union{Type1, Type2}
       → Partial instability (SHOULD FIX)
       → Multiple possible return types

    🟡 Variables highlighted in RED (in color terminals)
       → Type-unstable intermediate variables
       → Can cause performance issues

    ✅ Body::ConcreteType (e.g., Body::Int64, Body::Float64)
       → Type-stable! This is good!

    HOW TO FIX:
    -----------
    1. Add type annotations to function arguments:
       function my_func(x::Float64, y::Int) instead of my_func(x, y)

    2. Add type assertions for return values:
       return result::Float64

    3. Avoid changing variable types:
       ❌ x = 1; x = 1.5  (Int → Float64)
       ✅ x = 1.0; x = 1.5 (Float64 → Float64)

    4. Use type-stable containers:
       ❌ arr = []  (Vector{Any})
       ✅ arr = Float64[]  (Vector{Float64})

    ADVANCED TOOLS:
    ---------------
    • Cthulhu.jl: Interactive type inference explorer
        using Cthulhu
        @descend your_function(args...)

    • JET.jl: Automated static analysis
        using JET
        @report_opt your_function(args...)

    ════════════════════════════════════════════════════════════════════════════
    """)
end

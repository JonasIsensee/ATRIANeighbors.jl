# Debug the generalized Hénon map
using LinearAlgebra

function test_henon()
    a = 1.76
    b = 0.1
    Ds = 4

    state = [0.0, 0.0, 0.0, 0.0]

    println("Initial state: ", state)
    for iter in 1:20
        x1_new = a - state[Ds-1]^2 - b * state[Ds]

        state_new = zeros(Ds)
        state_new[1] = x1_new
        for i in 2:Ds
            state_new[i] = state[i-1]
        end

        state = state_new
        println("Iteration $iter: x1=$x1_new, state=$state")

        if any(isnan, state) || any(isinf, state)
            println("  DIVERGED at iteration $iter!")
            break
        end
    end

    println("\n\nNow testing from random initial conditions:")
    state = randn(Ds)
    println("Initial state: ", state)
    for iter in 1:20
        x1_new = a - state[Ds-1]^2 - b * state[Ds]

        state_new = zeros(Ds)
        state_new[1] = x1_new
        for i in 2:Ds
            state_new[i] = state[i-1]
        end

        state = state_new
        println("Iteration $iter: x1=$x1_new, |state|=$(norm(state))")

        if any(isnan, state) || any(isinf, state) || norm(state) > 1e6
            println("  DIVERGED at iteration $iter!")
            break
        end
    end
end

test_henon()

"""
Functions for recursively calculating mean and variance and comparing
    comparing to full sample calculated mean and variance.

Functions based on:

- Chou (2021, 5) <https://arxiv.org/pdf/2102.03316.pdf>

- Chan et al (1983) <http://www.cs.yale.edu/publications/techreports/tr222.pdf>
"""

using Distributions, Random, StatsPlots


# Functions --------------------------------------------------------------------

"""
    sum_of_squares(x::Vector{Real})::Float64
Find sum of squared deviations from a vector `x`.
"""
function sum_of_squares(x)::Float64
	length_x = length(x)
	x̄ = mean(x)
	squared_deviations = [(x[i] - x̄)^2 for i in 1:length_x]
	sum(squared_deviations)
end

"""
batcher(N, k)
Create `K` batches for a vector of length `N`

Function modified from <https://stackoverflow.com/a/37992134>
"""
function batcher(N::Int64, K::Int64) 
    n, r = divrem(N, K)
    b = collect(1:n:N + 1)
    for i in 1:length(b)
        b[i] += i > r ? r : i-1  
    end
    p = collect(1:N) # Keep original order rather than randperm
    return [p[r] for r in [b[i]:b[i+1]-1 for i=1:K]]
end

"""
    batch_mean_variance(batchₖ::Vector{Real}, t::Int64, x̄ₜ::Real, sₜ::Real)
Update estimate of mean, variance, and sum of squared deviations from a new 
batch of observations
"""
function batch_mean_variance(batchₖ, t::Int64, x̄ₜ::Real, sₜ::Real)
    # mean ----------
    Δₖ = sum(batchₖ)
    t′ = t + length(batchₖ)
    x̄ₜ′ = x̄ₜ + (1/t′) * (Δₖ - ((t′ - t) * x̄ₜ)) 

    # variance ------
    Δ̄ₖ = mean(batchₖ) 
    sₖ = sum_of_squares(batchₖ)
    sₜ′ = (sₜ + sₖ) + (t / t′) * (t′ - t) * (Δ̄ₖ - x̄ₜ)^2
    varianceₜ′ = sₜ′ / (t′ - 1)

    (mean_updated = x̄ₜ′, variance_updated = varianceₜ′, 
     sum_squares_updated = sₜ′, observations = t′)
end

# Simulation -------------------------------------------------------------------

"""
    sim_batch(x, K::Int64 = 84)
Given a vector of values `X`, break it into `K` batches and recursively find
the mean, and variance. Used to test recursive mean and variance algorithms.
"""
function sim_batch(X, K::Int64)
    Nₓ = length(X)
    batches = batcher(Nₓ, K)
    means, variances, sums_of_squares = zeros(K), zeros(K), zeros(K)
    mean_classic, var_classic = zeros(K), zeros(K)

    for i in eachindex(batches)
        tₜ₊₁, t′ = first(batches[i]), last(batches[i])
		Xₖ = X[tₜ₊₁:t′]

        if i == 1
            means[i], variances[i], sums_of_squares[i] = mean(Xₖ), var(Xₖ), sum_of_squares(Xₖ)
        else
            means[i], variances[i], sums_of_squares[i] = batch_mean_variance(Xₖ, 
                          last(batches[i-1]), means[i-1], sums_of_squares[i-1])
        end

        # For comparision, using classic methods on full sample up to and including batch
        X₁ₜ′ = X[1:t′]
        mean_classic[i], var_classic[i] = mean(X₁ₜ′), var(X₁ₜ′)
    end
    return (means = means, vars = variances, 
            means_classic = mean_classic, vars_classic = var_classic)
end

# Run simulation and plot differences between error 
N = 100_000 # observations
K = 168 # number of batches

p_var, p_mean = plot(1:K, zeros(K), legend = false, 
                     yticks = ([-1.5e-16, 0, 1.5e-16]),
                     xlab = "Batches",
                     title = "Variance"), 
                 plot(1:K, zeros(K), legend = false, 
                     yticks = ([-1e-16, 0, 1e-16]),
                     xlab = "Batches", ylab = "Absolute Error",
                     title = "Mean")

for _ in 1:100
    γ = Normal()
    x = rand(γ, N)
    
    e = sim_batch(x, K)
    mean_error, var_error = e.means - e.means_classic, e.vars - e.vars_classic

    plot!(p_mean, mean_error, linecolor = :grey, linealpha = 0.3)
    plot!(p_var, var_error, linecolor = :grey, linealpha = 0.3)
end

png(plot(p_mean, p_var, layout = 2), "sims-error")

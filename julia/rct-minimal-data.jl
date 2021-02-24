### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ 104838de-71f0-11eb-1cf3-5bd7b31e2e6c
begin
	using Distributions, Random, StatsPlots
end

# ╔═╡ 2ff54132-6f53-11eb-21a0-653b9cab4e81
md"

# Reading notes for \"Randomized Controlled Trials with Minimal Data Retention\"

Christopher Gandrud, 2021-02-15


Many data science questions are about groups of people (the simplest is often A vs. B treatment exposed customers). We aren't really interested in retaining individual people's data for this. But standard approaches to analytics and A/B testing often collect the entire set of actions we are interested in and then analyse it. 

Winston Chou has an interesting recent paper--[\"Randomzed Controlled Trials with Minimal Data Retention\"](https://arxiv.org/pdf/2102.03316.pdf)--developing approaches to analysing A/B tests without needing to retain customer data, even for longer running A/B tests where we are interested in repeated behaviour.

Though not explicitly discussed in the paper, it proposes on an interesting way of rethinking analysing experiments as [signal processing](https://en.wikipedia.org/wiki/Signal_processing). Rather than selecting methods that assume all of the data is collected--the traditional starting point of many social science data scientists--, the paper draws on signal processing methods like [recursive least squares](https://en.wikipedia.org/wiki/Recursive_least_squares_filter). These methods address problems where some noisy signal is being received and needs to be understood and acted upon in something like real-time.    

This are my notes for the article with some simulations to help me think through the algorithms.
"

# ╔═╡ bdb11a90-71eb-11eb-3f8e-6185ca6526cc
md"
## Average treatment effect

Let's start simple. Imagine we are running a simple A/B test and are only interested in the average treatment effect.  

### Simulate data

Let's simulate some data. We want to find the average treatment effect of the A/B test on some variable ``x`` The data is from a hurdle data generating process for a variable ``x``. This is the type of data I often encounter. 
"

# ╔═╡ 2a191476-7202-11eb-20e0-5799dac12cc2
begin
	n = 10_000
	
	"""
		simple_hurdle(;n::Int64, p::Float64 = 0.1, μ::Float64 = 2.5, σ::Float64 = 1.0)
	Simulate a data set drawn from a log-normal hurdle model.
	"""
	function simple_hurdle(;n::Int64, p::Float64 = 0.1, μ::Float64 = 2.5, σ::Float64 = 1.0) 
		b = Binomial(1, p)
		c = LogNormal(μ, σ)
	
		x = rand(b, n)
		x = ifelse.(x .> 0, rand.(c, 1), x)
		collect(Iterators.flatten(x))	
	end
end

# ╔═╡ b0de6366-72bf-11eb-1ee0-958a2a3069c9
x = simple_hurdle(n = n)

# ╔═╡ 6258c714-72c1-11eb-3033-b51acd8d5ddc
md"
## Recursive mean

We can recursively find the running mean--estimated average treatment effect--as this observations arrive up to observation ``t`` with:

``
\bar{x}_t = \bar{x}_{t - 1} + \frac{1}{t}(x_t - \bar{x}_{t-1}).
``

Note that ``\frac{1}{t}`` is the Kalman gain.

In many online settings, it is unlikely that we have exactly one observation arriving at a time. Instead, we often have batches of observations. We can generalise the recursive mean equation to batches. ``t^\prime`` is the total number of observations after observing the batch and Δ is the batch sum of ``x``. The recursive batch mean is then:

``
\bar{x}_{t^\prime} = \bar{x}_{t - 1} + \frac{1}{t^\prime}[\Delta - (t^\prime - t) \bar{x}_{t-1}].
``

"

# ╔═╡ 51c0bdb8-72c2-11eb-0bb7-5f22e5ca952e
# Recursive mean 
function recursive_mean(;t::Int64, x̄_before, xₜ = missing, Δ = missing, t′ = missing)::Float64
	if ismissing(t′) | ismissing(Δ) #  single step evaluation
		x̄_before + (1/t) * (xₜ - x̄_before) 
	elseif ismissing(xₜ) # batch evaluation
		x̄_before + (1/t′) * (Δ - ((t′ - t) * x̄_before))
	end
end

# ╔═╡ c70ad042-75e0-11eb-1b7f-dbbc36e8d208
md"
### Single step recursive mean
"

# ╔═╡ 995d0bf2-759e-11eb-327b-49c1820f60b2
function process_mean_recursively_single_step(x)
	# Initialise
	length_x = length(x)
	x̄ₜ_out = zeros(length_x)
	x̄ₜ_out[1] = recursive_mean(t = 1, x̄_before = x[1], xₜ = x[1])
	
	# Update
	for i in 2:length_x
		x̄ₜ_out[i] = recursive_mean(t = i, x̄_before = x̄ₜ_out[i-1], xₜ = x[i])
	end
	return(x̄ₜ_out)
end		

# ╔═╡ 9c405076-759f-11eb-37b3-e5644096529a
begin 
	x̄_single_step = process_mean_recursively_single_step(x)
	full_sample_mean_x = mean(x)
	p_single = plot(1:n, x̄_single_step, label = "Recursive Mean")
	plot!(p_single, repeat([full_sample_mean_x], n), 
		label = "Complete Sample Mean", legend = :bottomright) 
end

# ╔═╡ 915aa256-75ed-11eb-2fe3-694827b07e54
md"
### Batch recursive mean
"

# ╔═╡ 9c05ce3a-75ed-11eb-1c9f-5d13a97725dd
begin
	k = 84
	
	function batcher(N, k) # modified from <https://stackoverflow.com/a/37992134> 
    	n, r = divrem(N, k)
    	b = collect(1:n:N+1)
    	for i in 1:length(b)
        	b[i] += i > r ? r : i-1  
    	end
    	p = collect(1:N) # Keep original order rather than randperm
    	return [p[r] for r in [b[i]:b[i+1]-1 for i=1:k]]
	end


	function process_mean_recursively_batch(x)
		# Initialise
		length_x = length(x)
		batches = batcher(length_x, k)
		x̄ₜ_out = zeros(length(batches))
		
		# Batch values
		for i in 1:length(batches)
			f, t′ = first(batches[i]), last(batches[i])
			Δ = sum(x[f:t′])
			x̄_before = Δ/t′
			if i == 1
				x̄ₜ_out[1] = recursive_mean(t = 1, x̄_before = x̄_before, Δ = Δ, t′ = t′)
			else
				t_before = last(batches[i-1])
				x̄ₜ_out[i] = recursive_mean(t = t_before, x̄_before = x̄ₜ_out[i-1], Δ = Δ, t′ = t′)
			end
		end
		return x̄ₜ_out
	end
end		

# ╔═╡ 7675ea88-75f2-11eb-3fde-e5e0be91b628
begin
	x̄_batch = process_mean_recursively_batch(x)
	p_batch = plot(1:k, x̄_batch, label = "Batched Recursive Mean")
	plot!(p_batch, repeat([full_sample_mean_x], k), 
		label = "Complete Sample Mean", legend = :bottomright) 
	
end

# ╔═╡ f2eff40a-72c3-11eb-02f2-9d0edd810573
md"

## Recursive variance

The variance can be found recursively by first finding the sum of squares up to and including observation ``t``: 

``
s_t = s_{t-1} + \frac{t-1}{t}(z_t - \bar{z}_{t-1})^2. 
``

where ``s_{t-1}`` is the is the sum of squares after ``t-1`` observations. The variance is then:

``
\widehat{v_t^2} = \frac{s_t}{t -1}.
``
"

# ╔═╡ 87632fae-7412-11eb-1f0c-6bd407ba93b6
function sum_of_squares(x::Vector{Float64})
	length_x = length(x)
	x̄ = mean(x)
	squared_deviations = [(x[i] - x̄)^2 for i in 1:length_x]
	sum(squared_deviations)
end

# ╔═╡ 1f150818-7413-11eb-3a1e-47022d0ad3ad
sum_of_squares(collect(1.0:10.0))

# ╔═╡ 0ca37d6e-72c3-11eb-1914-a95669d3d8ae
function recursive_variance(xₜ::Float64, t::Int64, x̄_before::Float64, s_before::Float64)
	sₜ = s_before + (t-1) / t * (xₜ - x̄_before)
	varianceₜ = sₜ / (t - 1)
	(varianceₜ = varianceₜ, sum_squares = sₜ) 	
end

# ╔═╡ def22912-7441-11eb-0892-afeb5bd39fb7
test2 = recursive_variance(20.1, 10, 15.1, 2.0)

# ╔═╡ 0162c182-7442-11eb-2ad3-2770c96aa71e
test2.sum_squares

# ╔═╡ Cell order:
# ╟─2ff54132-6f53-11eb-21a0-653b9cab4e81
# ╠═104838de-71f0-11eb-1cf3-5bd7b31e2e6c
# ╟─bdb11a90-71eb-11eb-3f8e-6185ca6526cc
# ╠═2a191476-7202-11eb-20e0-5799dac12cc2
# ╠═b0de6366-72bf-11eb-1ee0-958a2a3069c9
# ╟─6258c714-72c1-11eb-3033-b51acd8d5ddc
# ╠═51c0bdb8-72c2-11eb-0bb7-5f22e5ca952e
# ╟─c70ad042-75e0-11eb-1b7f-dbbc36e8d208
# ╠═995d0bf2-759e-11eb-327b-49c1820f60b2
# ╠═9c405076-759f-11eb-37b3-e5644096529a
# ╟─915aa256-75ed-11eb-2fe3-694827b07e54
# ╠═9c05ce3a-75ed-11eb-1c9f-5d13a97725dd
# ╠═7675ea88-75f2-11eb-3fde-e5e0be91b628
# ╠═f2eff40a-72c3-11eb-02f2-9d0edd810573
# ╠═87632fae-7412-11eb-1f0c-6bd407ba93b6
# ╠═1f150818-7413-11eb-3a1e-47022d0ad3ad
# ╠═0ca37d6e-72c3-11eb-1914-a95669d3d8ae
# ╠═def22912-7441-11eb-0892-afeb5bd39fb7
# ╠═0162c182-7442-11eb-2ad3-2770c96aa71e

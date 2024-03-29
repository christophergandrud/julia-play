### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ 104838de-71f0-11eb-1cf3-5bd7b31e2e6c
using Distributions, Random, StatsPlots

# ╔═╡ 2ff54132-6f53-11eb-21a0-653b9cab4e81
md"

# Reading notes for \"Randomized Controlled Trials with Minimal Data Retention (p. 5-6)\"

Christopher Gandrud, 2021-03-01


Many data science questions are about groups of people (the simplest is often A vs. B treatment exposed customers). We aren't really interested in retaining individual people's data for this. But standard approaches to analytics and A/B testing often collect the entire set of actions we are interested in and then analyse it. 

Winston Chou has an interesting recent paper--[\"Randomzed Controlled Trials with Minimal Data Retention\"](https://arxiv.org/pdf/2102.03316.pdf)--developing approaches to analysing A/B tests without needing to retain customer data, even for longer running A/B tests where we are interested in repeated behaviour.

Though not explicitly discussed in the paper, it draws on methods from older computer science and information processing literatures (e.g. [Chan et al. (1983)](http://www.cs.yale.edu/publications/techreports/tr222.pdf)) to address privacy problems in A/B testing. 

In the early 80s (and before) the problem was less \"how do we run an A/B test without storing customer data\" than \"how do we do statistics without having don't enough memory to hold all of the data for the computation.\" 

The [Wiki article on Algorithms for calculating variance](https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance) is a good place to understand some of the key issues. 

This are my notes for pages 5-6 of the article with some simulations to help me think through the algorithms (and find a few typos).
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

$$\bar{x}_t = \bar{x}_{t - 1} + \frac{1}{t}(x_t - \bar{x}_{t-1}).$$

Note that ``\frac{1}{t}`` is the Kalman gain.

In many online settings, it is unlikely that we have exactly one observation arriving at a time. Instead, we often have batches of observations. We can generalise the recursive mean equation to batches. ``t^\prime`` is the total number of observations after observing the batch and Δ is the batch sum of ``x``. The recursive batch mean is then:

$$\bar{x}_{t^\prime} = \bar{x}_{t - 1} + \frac{1}{t^\prime}[\Delta - (t^\prime - t) \bar{x}_{t-1}].$$

"

# ╔═╡ 51c0bdb8-72c2-11eb-0bb7-5f22e5ca952e
# Recursive mean 
function recursive_mean(;t::Int64, x̄_before::Real, xₜ = missing, Δ = missing, t′ = missing)::Float64
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
function process_mean_recursively_single_step(x::Vector{Real})
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
		xlab = "Observations",
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


	function process_mean_recursively_batch(x::Vector{Real})
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
				x̄ₜ_out[i] = recursive_mean(t = t_before, x̄_before = x̄ₜ_out[i-1], 
										   Δ = Δ, t′ = t′)
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
		xlab = "Batches",
		label = "Complete Sample Mean", legend = :bottomright) 	
end

# ╔═╡ 465b9a82-7a89-11eb-26b4-1fe156e83ee8
md"
It's important to note that the full sample variance calculated by both methods is not exactly the same due to (a) roundoff error and (b) lack of precision in how the numbers are represented by the computer:
"

# ╔═╡ 5aacce7a-7a89-11eb-2aa4-e158311a1969
full_sample_mean_x, x̄_batch[k]

# ╔═╡ f2eff40a-72c3-11eb-02f2-9d0edd810573
md"

## Recursive variance

The variance can be found recursively by first finding the sum of squares up to and including observation ``t``: 

$$s_t = s_{t-1} + \frac{t-1}{t}(x_t - \bar{x}_{t-1})^2.$$

where ``s_{t-1}`` is the is the sum of squares after ``t-1`` observations. The variance is then:

$$\widehat{v_t^2} = \frac{s_t}{t -1}.$$

The batch version is:

$$s_{t^′} = s_{t-1} + s_{\Delta} + \frac{t}{t^\prime}(t^\prime - t)(\bar{\Delta} - \bar{x}_{t})^2.$$

``\bar{\Delta}`` is the batch mean and ``s_\Delta`` is the batch sum of squares.

Note that the batch recursive variance formula reported in [Chuo (2021, footnote 4)](https://arxiv.org/pdf/2102.03316.pdf) appears be incorrect. It is missing the sum or squared deviations prior to the current batch (``s_{t-1}``). See [Chan et al. (1983, Eq. 1.5)](http://www.cs.yale.edu/publications/techreports/tr222.pdf).

Let's put this together:

"

# ╔═╡ 87632fae-7412-11eb-1f0c-6bd407ba93b6
function sum_of_squares(x::Vector{Real})::Float64
	length_x = length(x)
	x̄ = mean(x)
	squared_deviations = [(x[i] - x̄)^2 for i in 1:length_x]
	sum(squared_deviations)
end

# ╔═╡ 0ca37d6e-72c3-11eb-1914-a95669d3d8ae
function recursive_variance(;t::Int64, x̄_before::Real, xₜ = missing, s::Real, 
		s_batch = missing, t′ = missing, Δ̄ = missing)
	if ismissing(t′) | ismissing(Δ̄)
		sₜ = s + ((t-1) / t) * (xₜ - x̄_before)^2
		varianceₜ = sₜ / (t - 1)
	else
		sₜ = s + s_batch + (t / t′) * (t′ - t) * (Δ̄ - x̄_before)^2
		varianceₜ = sₜ / (t′ - 1)
	end
	(varianceₜ = varianceₜ, sum_squares = sₜ) 	
end

# ╔═╡ 0162c182-7442-11eb-2ad3-2770c96aa71e
md"
### Single step recursive variance
"

# ╔═╡ d3312804-7736-11eb-10fc-fbf14354d4c5
function process_variance_recursively_singe_step(x::Vector{Real})
	# Initialise
	length_x = length(x)
	x̄ₜ_out, var_out, s = zeros(length_x), zeros(length_x), zeros(length_x)
	
	x̄ₜ_out[1] = recursive_mean(t = 1, x̄_before = x[1], xₜ = x[1])
	var_out[1] = recursive_variance(t = 1, x̄_before = x[1], xₜ = x[1], s = 0)[1]
	
	# Recursion
	for i in 2:length_x
		x̄ₜ_out[i] = recursive_mean(t = i, x̄_before = x̄ₜ_out[i-1], xₜ = x[i])
		var_out[i], s[i] = recursive_variance(t = i, x̄_before = x̄ₜ_out[i-1], 
											  xₜ = x[i], s = s[i-1])
	end
	return x̄ₜ_out, var_out, s
end

# ╔═╡ 2d830248-77ff-11eb-25b5-c94d631fdc7b
begin
	var_single = process_variance_recursively_singe_step(x)[2]
	var_full_sample = var(x)
	p_var_single = plot(1:n, var_single, label = "Recursive Variance")
	plot!(p_var_single, repeat([var_full_sample], n), 
		xlab = "Observations",
		label = "Complete Sample Variance",
		legend = :bottomright)
end

# ╔═╡ e0c47a80-780e-11eb-29f1-73898a88c1c4
md"
### Batch recursive variance

"

# ╔═╡ ec636b26-780e-11eb-1477-dddbd014b808
function process_variance_recusively_batch(x::Vector{Real}, k::Int64 = 84)
	# Initialise
	length_x = length(x)
	batches = batcher(length_x, k)
	x̄ₜ_out, var_out, s = zeros(k), zeros(k), zeros(k)
	
	# Batch values
	for i in 1:k
		f, t′ = first(batches[i]), last(batches[i])
		batch_values = x[f:t′]
		Δ, Δ̄ = sum(batch_values), mean(batch_values)
		s_batch = sum_of_squares(batch_values)
		
		if i == 1
			x̄ₜ_out[1] = recursive_mean(t = 1, x̄_before = Δ̄, Δ = Δ, t′ = t′)
			var_out[1], s[1] = recursive_variance(t = 1, 
												  x̄_before = Δ̄, 
												  Δ̄ = Δ̄, t′ = t′,
												  s = s_batch, s_batch = s_batch)
			
		else
			t_before = last(batches[i-1])
			x̄ₜ_out[i] = recursive_mean(t = t_before, x̄_before = x̄ₜ_out[i-1], 
									   Δ = Δ, t′ = t′)
			var_out[i], s[i] = recursive_variance(t = t_before, 
												  x̄_before = x̄ₜ_out[i-1], t′ = t′,
												  Δ̄ = Δ̄, 
												  s = s[i-1], s_batch = s_batch)
		end
	end
	return x̄ₜ_out, var_out, s
end

# ╔═╡ 827410ea-7998-11eb-1754-ffb904e6c560
process_variance_recusively_batch(x)

# ╔═╡ 753005ec-790e-11eb-29c6-f73b1dd22b25
begin
	p_test = plot(1:k, process_variance_recusively_batch(x)[1])
	plot!(p_test, repeat([mean(x)], k))
end

# ╔═╡ ed45cd80-780f-11eb-2ed0-4b28e866f4fe
begin
	var_batch = process_variance_recusively_batch(x)[2]
	p_var_batch = plot(1:k, var_batch, label = "Batch Variance")
	plot!(p_var_batch, repeat([var_full_sample], k), label = "Full Sample Variance")
end 

# ╔═╡ dca8f8a4-7a84-11eb-2c72-99ef103ceb44
md"
Again, it's important to note that the full sample variance calculated by both methods is not exactly the same:
"

# ╔═╡ f81974b0-7a84-11eb-0bd8-f3155f4f8adb
var_full_sample, var_batch[k]

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
# ╟─465b9a82-7a89-11eb-26b4-1fe156e83ee8
# ╠═5aacce7a-7a89-11eb-2aa4-e158311a1969
# ╟─f2eff40a-72c3-11eb-02f2-9d0edd810573
# ╠═87632fae-7412-11eb-1f0c-6bd407ba93b6
# ╠═0ca37d6e-72c3-11eb-1914-a95669d3d8ae
# ╟─0162c182-7442-11eb-2ad3-2770c96aa71e
# ╠═d3312804-7736-11eb-10fc-fbf14354d4c5
# ╠═2d830248-77ff-11eb-25b5-c94d631fdc7b
# ╟─e0c47a80-780e-11eb-29f1-73898a88c1c4
# ╠═ec636b26-780e-11eb-1477-dddbd014b808
# ╠═827410ea-7998-11eb-1754-ffb904e6c560
# ╠═753005ec-790e-11eb-29c6-f73b1dd22b25
# ╠═ed45cd80-780f-11eb-2ed0-4b28e866f4fe
# ╟─dca8f8a4-7a84-11eb-2c72-99ef103ceb44
# ╠═f81974b0-7a84-11eb-0bd8-f3155f4f8adb

### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 7da07040-6cfa-11eb-34f7-0b3ab55b2bce
using StatsBase, Plots

# ╔═╡ 5552d3f0-6cf8-11eb-20a6-ed5780dc79b0
md"
# Julia muliti-threaded

Christopher Gandrud, 2021-02-12

Julia was created with [distributed computing in mind](https://docs.julialang.org/en/v1.0/manual/parallel-computing/). Here is a simple example of how to run a for-loop on multiple CPU cores.
"

# ╔═╡ db44d7ce-6cf8-11eb-2e67-57b7ca7ad626
md"

## Example

Right now I'm studying for something called the *Deutscher Einbürgerungstest*. When I take the test, it will have 30 questions from a [test set](http://oet.bamf.de/pls/oetut/f?p=514:1:329473569276328:::::) of 310 ordered questions. I want to study by creating practice tests of randomly selected questions. Many questions in the test set are testing the same material, just with different wording. These questions are bunched together in the test set. So, to create practice tests with consistently good coverage over the questinos, I want a stratified random sampling procedure. 

Here is my algorithm:
"

# ╔═╡ 789c2c92-6cfa-11eb-2707-0db43a21db14
"""
    ebt_sampler(total_questions::Int = 310)
Create question set to practice for the Deutscher Einbürgerungstest. 
The official question set can be found at: <http://oet.bamf.de/pls/oetut/f?p=514:1:329473569276328:::::>.
The question set has 310 questions, but who knows, maybe this could change. 
Adjust the total question set with `total_questions::Int`.
"""
function ebt_sampler(total_questions::Int = 310) 
    i::Int = -9; u::Int = 0
    out = zeros(Int, 0)
    while u < total_questions
         i += 10; u += 10
         x = StatsBase.sample(i:u)
         out = append!(out, x)
    end
    return(out)
end

# ╔═╡ a0e24bdc-6cfa-11eb-08e7-69eb4bf447b1
md"

Note: I also want to oversample from questions 300-310 to create a test of 31 rather than 30 questions. This helps me make sure I'm studying the questions related to my local state (Berlin).

Here is an example:
"

# ╔═╡ da29ab62-6cfa-11eb-1b2b-4157675492da
x = ebt_sampler()

# ╔═╡ e4225568-6cfa-11eb-13f0-7777ac4ed57e
md"
Looks good. But I want to make certain that I am randomly sampling the all of the questions with known and equal probability. Who knows, maybe I didn't write the algorithm correctly.

To validate this, I could take lots of samples and then make a histogram of the draws. This should look like a flat bar--each question was drawn with the same frequency--if I wrote the algorithm correctly.

This is where we can use multi-threading (we could also have done it in the sampler function, but given how few samples it runs, the overhead of setting up the multi-threading would almost certainly outweigh the reduced computation time).

### Single threaded

Here are 1 million samples drawn sequentially on a single CPU: 
"

# ╔═╡ 432da8e8-6dc6-11eb-1fe2-179a5a92e07b
n = 1_000_000

# ╔═╡ 8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
samps_single_threaded = [ebt_sampler() for _ in 1:n]

# ╔═╡ a506ec4c-6cfb-11eb-3235-69f825519bdc
md"
This took between 1.1 and 1.6 seconds (depending on when I run it).

Now let's run it across two of my local machine's CPU cores:
"

# ╔═╡ fb3a3ae4-6cfb-11eb-0d9b-5b69ae91eb81
# Check threads available to Julia
Threads.nthreads()

# ╔═╡ ddb9d96a-6d3d-11eb-29d1-47b996953f55
begin
	samps_multi = Vector{AbstractArray}(undef, n)

	Threads.@threads for i in 1:n
		samps_multi[i] = ebt_sampler()
	end
end

# ╔═╡ 68ca5b14-6dc6-11eb-0cb9-216e9021daad
md"
Using two rather than one core sped up the operation about 2x (~650ms vs. 1.5 seconds). About what we would expect.

Note that I needed to explicitly initialise the `samps_multi` object in order to take advantage of the `@threads` [macro](https://docs.julialang.org/en/v1/manual/metaprogramming/). This is because the macro only works (at least as far as I can tell in Julia 1.5.3) on `for` loops where the `for` is directly after the macro call. To do this, I needed to create the `samps_multi` object with `undef` (undefined) types and length `n` (the number of samples). Each sample then knows where to put its output. The first time I tried this, I didn't have the explicit indexing and it crashed the notebook as each process likely tried to access the same data at the same time.

I'm sure I could optimise this code. In paricular, I could explicitly define the type of each element of `samps_multi`, rather than using `undef` and having Julia define them at runtime.

Finally, let's collapse all of these arrays and make a histogram to see if each question has an equal probability of being sampled:
"

# ╔═╡ d62f72f6-6dc7-11eb-14e4-916ede86c49f
samps_multi_collected = collect(Iterators.flatten(samps_multi))

# ╔═╡ efc2caba-6dc7-11eb-1156-4333745e9575
histogram(samps_multi_collected)

# ╔═╡ 15457c18-6e0d-11eb-1bad-b19ad9331eb5
md"
Looks good.
"

# ╔═╡ d909212e-6cfb-11eb-0844-49a2bc156db0


# ╔═╡ adc118c6-6cfd-11eb-0543-2f509af688f0


# ╔═╡ 5cf4891a-6cfc-11eb-074b-55d8e460319e


# ╔═╡ Cell order:
# ╟─5552d3f0-6cf8-11eb-20a6-ed5780dc79b0
# ╟─db44d7ce-6cf8-11eb-2e67-57b7ca7ad626
# ╠═7da07040-6cfa-11eb-34f7-0b3ab55b2bce
# ╠═789c2c92-6cfa-11eb-2707-0db43a21db14
# ╟─a0e24bdc-6cfa-11eb-08e7-69eb4bf447b1
# ╠═da29ab62-6cfa-11eb-1b2b-4157675492da
# ╟─e4225568-6cfa-11eb-13f0-7777ac4ed57e
# ╠═432da8e8-6dc6-11eb-1fe2-179a5a92e07b
# ╠═8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
# ╟─a506ec4c-6cfb-11eb-3235-69f825519bdc
# ╠═fb3a3ae4-6cfb-11eb-0d9b-5b69ae91eb81
# ╠═ddb9d96a-6d3d-11eb-29d1-47b996953f55
# ╟─68ca5b14-6dc6-11eb-0cb9-216e9021daad
# ╠═d62f72f6-6dc7-11eb-14e4-916ede86c49f
# ╠═efc2caba-6dc7-11eb-1156-4333745e9575
# ╟─15457c18-6e0d-11eb-1bad-b19ad9331eb5
# ╟─d909212e-6cfb-11eb-0844-49a2bc156db0
# ╟─adc118c6-6cfd-11eb-0543-2f509af688f0
# ╟─5cf4891a-6cfc-11eb-074b-55d8e460319e

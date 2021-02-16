### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 7da07040-6cfa-11eb-34f7-0b3ab55b2bce
using BenchmarkTools, StatsPlots, StatsBase

# ╔═╡ 5552d3f0-6cf8-11eb-20a6-ed5780dc79b0
md"
# Julia muliti-threaded

Christopher Gandrud, 2021-02-12

Julia was created with [distributed computing in mind](https://docs.julialang.org/en/v1.0/manual/parallel-computing/). This notebook started out as a simple illustration of the `Threads.@threads for`  [macro](https://docs.julialang.org/en/v1/manual/metaprogramming/). [That worked ok](https://github.com/christophergandrud/julia-play/blob/c93570107280b918e70d70be0240c95d7414212c/julia/multithread-example.jl), but as expected when the documentation says that something is 'experimental' and 'not fully thread-safe', that was easy to hard mess up. The `@threads` macro only works with for loops written in a particular way. As far I can tell, you can't use `@threads` with for loops in [comprehensions](https://docs.julialang.org/en/v1/manual/arrays/#man-comprehensions). This is a real shame because comprehensions take care of messy work of constructing arrays from the looped elements. 

It seems like the Julia developers are also [moving away](https://www.oxinabox.net/2021/02/13/Julia-1.6-what-has-changed-since-1.0.html#threading) from `@threads` to a more general purpose, and frankly amazing, `Threads.@spawn`. The promise is that you can stick that macro in front of an operation and Julia will just figure out how to distribute it. It works really well, once I figured out one step I was forgetting.    

So here is a more involved introduction to multi-threading (on a single computer) in Julia than I expected.
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

Here is a single run of the sampler:
"

# ╔═╡ da29ab62-6cfa-11eb-1b2b-4157675492da
x = ebt_sampler()

# ╔═╡ e4225568-6cfa-11eb-13f0-7777ac4ed57e
md"
Looks good. But I want to make certain that I am randomly sampling the all of the questions with known and equal probability. Who knows, maybe I didn't write the algorithm correctly.

One way to validate the algorithm's correctness is to run it many times and then make a histogram of the outcomes. If I wrote the algorithm correctly the plot should look like a flat bar--each question was drawn with the same frequency.

This is where I will use multi-threading (we could also have done it in the sampler function, but given how few samples it runs, the overhead of setting up the multi-threading would almost certainly outweigh the reduced computation time).

### Single threaded

Before multi-threading, let's benchmark Here are 1000 samples drawn sequentially on a single CPU: 
"

# ╔═╡ 432da8e8-6dc6-11eb-1fe2-179a5a92e07b
n = 100

# ╔═╡ 8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
@benchmark samps_single_threaded = @time [ebt_sampler() for _ in 1:n]

# ╔═╡ a506ec4c-6cfb-11eb-3235-69f825519bdc
md"
100 samples took about 660 ``\mu``s.

Note: I took so few samples because of the (so far only one I've found) major downside of Pluto notebooks. Because it is reactive, every time I open the notebook it runs all of the samples. This is a lot when using BenchmarkTools to assess the speed of the implementations as it is taking samples of samples. The time adds up quickly.

## Multi-threaded

Now let's look at a few different ways to draw the samples in parallel. We're only going to use 2 CPU cores and so (depending on the set up overhead) expect about about 2x speed up.
"

# ╔═╡ fb3a3ae4-6cfb-11eb-0d9b-5b69ae91eb81
# Check threads available to Julia
Threads.nthreads()

# ╔═╡ 1ecb8902-705f-11eb-2391-45b69613ea32
md"

### `@threads` approach

Let's start with the `@threads` approach that I started with. Here we need to use a standard `for` loop. We also (as far as I could figure out) manage the creation of initialising an empty array (with `n` `undef` undefined elements) and placing the results of each sample at the correct array index.
"

# ╔═╡ ddb9d96a-6d3d-11eb-29d1-47b996953f55
function ebt_sampler_threads(n)
    x = Vector{AbstractArray}(undef, n)
    
    Threads.@threads for i in 1:n
        x[i] = ebt_sampler()
    end
end

# ╔═╡ 4ae69b88-705f-11eb-07a3-83975b17d934
@benchmark ebt_sampler_threads(n)

# ╔═╡ 1c33aa16-7060-11eb-03ab-53af14e90ac4
md"
### `@spawn` with `for` loop in comprehension

Now let's get rid of dealing with the overhead of creating an empty array by using `@spawn` on a `for` loop with a comprehension.

Note, I included a `fetch` step. This ensures that the results of the call is completed before returning output. Not doing this can sometimes lead to incomplete output as some of the workers are still busy trying to complete even after the results are returned. This was especially problematic for the `@benchmark`, causing it to hang seemingly indefinitely (see [here](https://discourse.julialang.org/t/spawn-and-btime-benchmark-causes-julia-to-hang/31712/4)).

"

# ╔═╡ 158e834a-7022-11eb-2b92-a967f272bdb7
function ebt_spawner_simple(n)
    x = Threads.@spawn [ebt_sampler() for _ in 1:n]
    fetch(x)
end

# ╔═╡ 5760b6e2-7060-11eb-2bb9-0514a2cccff6
@benchmark ebt_spawner_simple(n)

# ╔═╡ 25d0c942-7064-11eb-3a43-0dadd264400b
md"

Some interesting results from the test. The median time for the `@threads` approach was the fastest, but both it and the `@spawn` with comprehensions approaches were orders of magnitude faster. The maximum `@threads` time was about half the maximum single-threaded approach. Surprisingly, `@spawn` had an almost 8x faster maximum time.  

"

# ╔═╡ 51d2ab9c-7063-11eb-07e4-cd2be2f13134
# draw samples for plotting
samps_multi_spawn = ebt_spawner_simple(n)

# ╔═╡ 68ca5b14-6dc6-11eb-0cb9-216e9021daad
md"

## Plot samples

Finally, let's collapse all of these arrays and make a histogram to see if each question has an equal probability of being sampled:
"

# ╔═╡ d62f72f6-6dc7-11eb-14e4-916ede86c49f
samps_multi_collected = collect(Iterators.flatten(samps_multi_spawn))

# ╔═╡ efc2caba-6dc7-11eb-1156-4333745e9575
histogram(samps_multi_collected, bins = 31)

# ╔═╡ 15457c18-6e0d-11eb-1bad-b19ad9331eb5
md"
Looks pretty good. With more samples (I tried outside of the notebook) it is what we expect. 
"

# ╔═╡ d909212e-6cfb-11eb-0844-49a2bc156db0


# ╔═╡ adc118c6-6cfd-11eb-0543-2f509af688f0


# ╔═╡ 5cf4891a-6cfc-11eb-074b-55d8e460319e


# ╔═╡ Cell order:
# ╟─5552d3f0-6cf8-11eb-20a6-ed5780dc79b0
# ╠═7da07040-6cfa-11eb-34f7-0b3ab55b2bce
# ╟─db44d7ce-6cf8-11eb-2e67-57b7ca7ad626
# ╠═789c2c92-6cfa-11eb-2707-0db43a21db14
# ╟─a0e24bdc-6cfa-11eb-08e7-69eb4bf447b1
# ╠═da29ab62-6cfa-11eb-1b2b-4157675492da
# ╟─e4225568-6cfa-11eb-13f0-7777ac4ed57e
# ╠═432da8e8-6dc6-11eb-1fe2-179a5a92e07b
# ╠═8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
# ╟─a506ec4c-6cfb-11eb-3235-69f825519bdc
# ╠═fb3a3ae4-6cfb-11eb-0d9b-5b69ae91eb81
# ╟─1ecb8902-705f-11eb-2391-45b69613ea32
# ╠═ddb9d96a-6d3d-11eb-29d1-47b996953f55
# ╠═4ae69b88-705f-11eb-07a3-83975b17d934
# ╟─1c33aa16-7060-11eb-03ab-53af14e90ac4
# ╠═158e834a-7022-11eb-2b92-a967f272bdb7
# ╠═5760b6e2-7060-11eb-2bb9-0514a2cccff6
# ╟─25d0c942-7064-11eb-3a43-0dadd264400b
# ╠═51d2ab9c-7063-11eb-07e4-cd2be2f13134
# ╟─68ca5b14-6dc6-11eb-0cb9-216e9021daad
# ╠═d62f72f6-6dc7-11eb-14e4-916ede86c49f
# ╠═efc2caba-6dc7-11eb-1156-4333745e9575
# ╠═15457c18-6e0d-11eb-1bad-b19ad9331eb5
# ╟─d909212e-6cfb-11eb-0844-49a2bc156db0
# ╟─adc118c6-6cfd-11eb-0543-2f509af688f0
# ╟─5cf4891a-6cfc-11eb-074b-55d8e460319e

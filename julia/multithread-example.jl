### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 7da07040-6cfa-11eb-34f7-0b3ab55b2bce
using BenchmarkTools, StatsPlots, StatsBase

# ╔═╡ 25dca468-70e8-11eb-36c1-e39dc55de9e4
using Lazy

# ╔═╡ 5552d3f0-6cf8-11eb-20a6-ed5780dc79b0
md"
# Julia muliti-threaded

Christopher Gandrud, 2021-02-17

Julia was created with [distributed computing in mind](https://docs.julialang.org/en/v1.0/manual/parallel-computing/). To explore practice these capabilities, I started this notebook started as a simple illustration of the `Threads.@threads for`  [macro](https://docs.julialang.org/en/v1/manual/metaprogramming/). [That worked ok](https://github.com/christophergandrud/julia-play/blob/c93570107280b918e70d70be0240c95d7414212c/julia/multithread-example.jl).

However, as expected when the documentation says that something is 'experimental' and 'not fully thread-safe', that approach was easy to mess up in a way that crashed things. The `@threads` macro is also limited in that it only works with `for` loops written in a particular way. As far I can tell, you can't use `@threads` with for loops in [comprehensions](https://docs.julialang.org/en/v1/manual/arrays/#man-comprehensions). This is a real shame because comprehensions take care of the tedious work of constructing arrays from the looped elements. 

It seems like the Julia developers are also [moving away](https://www.oxinabox.net/2021/02/13/Julia-1.6-what-has-changed-since-1.0.html#threading) from `@threads` to a more general purpose `Threads.@spawn` macro. The promise is that you can stick this macro in front of an operation and Julia will just figure out how to distribute it.     

Let's see how to implement the two approaches.
"

# ╔═╡ db44d7ce-6cf8-11eb-2e67-57b7ca7ad626
md"

## Example

Right now I'm studying for something called the *Deutscher Einbürgerungstest*. The test has 33 questions from a [test set](http://oet.bamf.de/pls/oetut/f?p=514:1:329473569276328:::::) of 310 ordered questions. I want to study by creating practice tests of randomly selected questions. Many questions in the test set are testing the same material, just with different wording. These questions are bunched together in the test set. So, to create practice tests with consistently good coverage over the questinos, I want a stratified random sampling procedure. 

Here's my algorithm:
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
         if u == total_questions
            x = StatsBase.sample(i:u, 3, replace = false)
         else
            x = StatsBase.sample(i:u)
         end
         out = append!(out, x)
    end
    return(out)
end

# ╔═╡ a0e24bdc-6cfa-11eb-08e7-69eb4bf447b1
md"

Note: I also want to sample three questions from questions 300-310 of the test set. The test will include three questions about my local state (Berlin). These three questions are drawn from the last 10 questions in the test set.

Here is a single run of the sampler:
"

# ╔═╡ da29ab62-6cfa-11eb-1b2b-4157675492da
x = ebt_sampler()

# ╔═╡ e4225568-6cfa-11eb-13f0-7777ac4ed57e
md"
Looks good. But I want to make certain that I'm actually randomly sampling all of the questions with equal probability, except questions 300-310, which should be 3x as likely to be sampled. Who knows, maybe I didn't write the algorithm correctly.

One way to validate the algorithm's correctness is to run it many times and then make a histogram of the outcomes. If I wrote the algorithm correctly the plot should look like a flat bar--each question was drawn with the same frequency--except for a 3x spike for questions 300-310.

This is where I will use multi-threading.

### Single threaded

Before multi-threading, let's benchmark Here are 1000 samples drawn sequentially on a single CPU: 
"

# ╔═╡ 432da8e8-6dc6-11eb-1fe2-179a5a92e07b
n = 100

# ╔═╡ 8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
@benchmark samps_single_threaded = @time [ebt_sampler() for _ in 1:n]

# ╔═╡ a506ec4c-6cfb-11eb-3235-69f825519bdc
md"

Note: I took so few samples because of one of the major downsides of [Pluto notebooks](https://github.com/fonsp/Pluto.jl). Because they are reactive (usually a Pluto highlight), every time I open the notebook it runs all of the samples. This is a lot when using BenchmarkTools to assess the speed of the implementations. BenchmarkTools takes samples of the samplers. The computation time adds up quickly.

## Multi-threaded

We're only going to use 2 CPU cores and so (depending on the set up overhead) I would expect about about 2x speed up.
"

# ╔═╡ fb3a3ae4-6cfb-11eb-0d9b-5b69ae91eb81
# Check threads available to Julia
Threads.nthreads()

# ╔═╡ 1ecb8902-705f-11eb-2391-45b69613ea32
md"

### `@threads` approach

Let's start with the `@threads` approach. Here we need to use a standard `for` loop. We also (as far as I could figure out) manage the creation of initialising an empty array (with `n` undefined (`undef`) elements) and place the results of each sample at the correct array index.
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

Now let's get rid of dealing with the overhead of creating an empty array by using `@spawn` on a `for` loop within a comprehension.

Note, I included a `fetch` step. This ensures that the results of the call are completed before the function returns the output. Not doing this can sometimes lead to incomplete output as some of the workers are still busy trying to complete their tasks even after the results are returned. This was especially problematic for the `@benchmark`, causing it to hang seemingly indefinitely (see [here](https://discourse.julialang.org/t/spawn-and-btime-benchmark-causes-julia-to-hang/31712/4)).

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

Some interesting results from the test. The median time for the `@threads` approach was the fastest, but both it and the `@spawn` with comprehensions approaches were orders of magnitude faster. Surprisingly, `@spawn` has a much lower maximum time than either of the other approaches. I'm still digging around to learn how the multi-threaded approaches could be much faster than the we would expect from only doubling the number of available cores. Maybe it has to do with how compilation works in the different approaches. 

"

# ╔═╡ 51d2ab9c-7063-11eb-07e4-cd2be2f13134
# draw samples for plotting
samps_multi_spawn = ebt_spawner_simple(n)

# ╔═╡ 68ca5b14-6dc6-11eb-0cb9-216e9021daad
md"

## Plot samples

Finally, let's `collect` all of these arrays and make a histogram to see if each test question the expected probability of being sampled:
"

# ╔═╡ d62f72f6-6dc7-11eb-14e4-916ede86c49f
samps_multi_collected = collect(Iterators.flatten(samps_multi_spawn))

# ╔═╡ efc2caba-6dc7-11eb-1156-4333745e9575
histogram(samps_multi_collected, bins = 31, legend = false)

# ╔═╡ 15457c18-6e0d-11eb-1bad-b19ad9331eb5
md"
Looks pretty good. 

Note that the low first and last bars (the first bar is about 10% lower than the others and the last is about 90% lower) are expected. We didn't sample any 0's for the first bin and the last bin only includes 310. 

To see how t his works (and mostly for me to practice piping with Lazy 😀):
"

# ╔═╡ 298fee3a-70e8-11eb-1a24-5b7caec1f433
# draw 100 samples from the range 1:10
@> sample(1:10, 100) histogram(bins = 1, legend = false)

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
# ╟─8d76cc52-6cfb-11eb-3042-c39b0e7aa4f9
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
# ╟─15457c18-6e0d-11eb-1bad-b19ad9331eb5
# ╠═25dca468-70e8-11eb-36c1-e39dc55de9e4
# ╠═298fee3a-70e8-11eb-1a24-5b7caec1f433
# ╟─d909212e-6cfb-11eb-0844-49a2bc156db0
# ╟─adc118c6-6cfd-11eb-0543-2f509af688f0
# ╟─5cf4891a-6cfc-11eb-074b-55d8e460319e

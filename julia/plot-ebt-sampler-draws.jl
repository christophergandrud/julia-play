# Plot draws from EBT Sampler

using StatsBase, Plots, Threads

"""
    ebt_sampler(total_questions::Int = 310)
Create question set to practice for the Deutscher Einbürgerungstest. 
The official question set can be found at: <http://oet.bamf.de/pls/oetut/f?p=514:1:329473569276328:::::>.
The question set has 310 questions, but who knows, maybe this could change. Adjust the total 
question set with `total_questions::Int`.
"""
function ebt_sampler(total_questions::Int = 310) 
    i = -9; u = 0
    out = zeros(Int, 0)
    while u < total_questions
         i += 10; u += 10
         x = StatsBase.sample(i:u)
         out = append!(out, x)
    end
    return(out)
end


Threads.@threads samps = [ebt_sampler() for _ in 1:1_000_000]
samps = collect(Iterators.flatten(samps))

histogram(samps)



begin
	samps_multi_threaded = zeros(Int, 0)
	Threads.@threads for _ in 1:1_000_000
		append!(samps_multi_threaded, ebt_sampler())
	end
end
"""
    ebt_sampler(total_questions::Int = 310)
Create question set to practice for the Deutscher Einbürgerungstest. 
The official question set can be found at: <http://oet.bamf.de/pls/oetut/f?p=514:1:329473569276328:::::>.
The question set has 310 questions, but who knows, maybe this could change. Adjust the total 
question set with `total_questions::Int`.
"""
function ebt_sampler(total_questions::Int = 310) 
    print("Select the following questions to practice the Einbürgerungstest:\n\n")
    i = -9; u = 0
    while u < total_questions
         i += 10; u += 10
         x = StatsBase.sample(i:u)
         println(x)
    end
end
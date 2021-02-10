### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ cbeafb1c-6aa2-11eb-19e5-1544e0677bcd
md"
# Optimiser's Curse, Naive Analytics, and Unexpected Returns

Christopher Gandrud, 2021-02-09

Two papers caught my eye recently:


- [Smith and Winkler (2006) \"The Optimizer's Curse: Skepticism and Postdecision Surprise in Decision Analysis\"](http://tuck-fac-cen.dartmouth.edu/images/uploads/faculty/james-smith/The_Optimizers_Curse.pdf) [Hat tip to [Gwen.net Newsletter](https://gwern.substack.com/)]

- [Berman and Heller (draft 2020) \"Naive Analytics Equilibrium\"](https://arxiv.org/abs/2010.15810) [Recently presented at the great [Virtual Quantitative Marketing Seminar](https://sites.google.com/view/vquantmarketing/virtual-quant-marketing-seminar)]

Both of these papers touch on ways that business/investment/policy decisions (for simplicity, I'll just use 'investment decisions' from now on) driven by standard data analysis can lead to unexpectedly low returns. 

Smith and Winkler demonstrate that even with unbiased estimates of an investment's returns, by choosing the investment with the highest expected value among a range of alternative investments decisionmakers will tend to be disappointed with lower than expected returns. They provide a useful shrinkage prior corrective approach (similar to on that Martin Tingley discussed at the Stanford Causal Inference Seminar). Berman and Heller discuss how \"naive\" estimates of price elasticities and advertising effectiveness can cause firms to set prices too high and advertise too much. 

Both of these findings ring true to the anecdata I have and inform an important [stylised fact](https://en.wikipedia.org/wiki/Stylized_fact): 

>the actual **direct** impact of a **particular** decision is less than we expect.


The paper's provide some practical correctives. E.g. Smith and Winkler advocate using prior information to shrink the expected value estimates. 

However, there are additional issues that are easy to lose site of 

- non-stationarities

- fatter tail distributions

and their interaction with the

- cumulative value of repeated investments


Furthermore, Berman and Heller formalise a relationship between expected value and team productivity that many managers are probably familiar with. If the expected value of team members' work is high, they will be more productive. Not only could this increase the expected value of an investment, once we consider production costs, but it could positively impact the ability of a firm to adjust strategy to non-stationarities and find investments with unusually high returns.


## Problem

A firm considers multiple alternative investments. It want's to choose the investment that maximises its return. 

"

# ╔═╡ 0ddc8008-6af9-11eb-3579-1d01d30bdca4


# ╔═╡ Cell order:
# ╠═cbeafb1c-6aa2-11eb-19e5-1544e0677bcd
# ╠═0ddc8008-6af9-11eb-3579-1d01d30bdca4

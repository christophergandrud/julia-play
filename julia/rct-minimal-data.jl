### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 2ff54132-6f53-11eb-21a0-653b9cab4e81
md"

# Reading notes for \"Randomized Controlled Trials with Minimal Data Retention\"

Christopher Gandrud, 2021-02-15


Many data science questions are about groups of people (the simplest is often A vs. B treatment exposed customers). We aren't really interested in retaining individual people's data for this. But standard approaches to analytics and A/B testing often collect the entire set of actions we are interested in and then analyse it. 

Winston Chou has an interesting recent paper--[\"Randomzed Controlled Trials with Minimal Data Retention\"](https://arxiv.org/pdf/2102.03316.pdf)--developing approaches to analysing A/B tests without needing to retain customer data, even for longer running A/B tests where we are interested in repeated behaviour.

This are my notes for the article with some simulations to help me think through the algorithms.
"

# ╔═╡ Cell order:
# ╟─2ff54132-6f53-11eb-21a0-653b9cab4e81

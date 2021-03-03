### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ 1de414b0-7b21-11eb-2d63-1d57c29456c5
md"
# Privacy first data science: the case of recursively calculating mean and variance

## A deceptively easy problem

How much time have you spent thinking about calculating the mean and variance of some sample? Probably not much. When you run an A/B test you probably run the standard `t.test` or whatever function. This does some calculations with your data that you learned in the first day of Stats 101 like the arithmetic mean (``\bar{x}``):

$$\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i$$

and variance (``\mathrm{Var}(X)``) via the sum of squared deviations (``S``):

$$S = \sum_{i=1}^{n}(x_i - \bar{x})^2$$

$$\mathrm{Var}(X) = \frac{S}{n-1}.$$

Ok, so what?

Well, we often want to understand the population (or some group in the population) level impact. We don't really want to store or dive deep on individual people. But the simple equation for the mean and sum of squares has these ``\sum_{i=1}^{n}``. They require us to have all of the ``x_i`` observations at the same time to calculate these statistics. So, we need to keep all of this data for each person ``i`` in the study up until and including when we calculate these statistics. 

## Minimum data collection and retention: a privacy principle  

A good rule of thumb for privacy first data science is that:

> we should collect and keep the absolute mimimum amount of individual's data possible. 

If we don't have a good reason--let's leave aside what 'good reason' means, but the GDPR could be a good guide--to collect the data, don't collect it. If there is a way to calculate a statistic without retaining individuals' data, use that method and don't retain the data beyond what is necessary for the method.  

Let's assume we had a good reason to find the mean and variance of some sample, *did we keep the data the absolute minimum amount of time when we used the standard formulas*?

*No.*

## Recursively calculate mean and variance



"

# ╔═╡ Cell order:
# ╠═1de414b0-7b21-11eb-2d63-1d57c29456c5

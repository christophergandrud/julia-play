### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ c18e2d8a-6573-11eb-1174-8d77b4b1fa42
begin
	# Load required packages
	using Distributions, Random, DataFrames, GLM
end

# ╔═╡ af10f252-6573-11eb-2844-09f83484799f
md" 
# Julia implementation of Vincent's \"Making Sense of Sensitivity\"

Christopher Gandrud,
2021-02-06

I want to sharpen my Julia language skills. So, this notebook is me replicating Vincent Arel-Bundock's really nice blog post on [Making Sense of Sensitivity: Extending Omitted Variable Bias](http://arelbundock.com/posts/robustness_values/) in Julia.

A lot of the text is directly from Vincet's original post, reproduced by me as a way of taking notes while I played around.
"

# ╔═╡ f1ab12da-6573-11eb-1043-95d1f6de5644
md"

## Omitted variable bias definition for simple linear regression

Imagine, we have a true model:

``
Y = \tau D + X\beta + \gamma Z + \epsilon 
``

Omitted variable bias for the linear model is given by:

``
\hat{\tau}_{r} = \hat{\tau} + \hat{\gamma}\hat{\delta}
``

where 

- ``\hat{\tau}_{r}`` is the estimate we observe, 

- ``\hat{\tau}`` is what we want to estimate, 

- ``\hat{\gamma}`` is a measure of association between the omitted ``Z`` and ``Y``, and 

- ``\hat{\delta}`` is a measure of the assocation between the omitted ``Z`` and the treatment ``D``. 

Vincent demonstrates that this captures omitted variable bias (``\hat{\tau}_{r} = \hat{\tau}_{o}``) with a simulation:
"

# ╔═╡ 3ff5fe52-6577-11eb-18ab-6df251b74660
begin
	N = 10_000
	Z = rand(Binomial(1, 0.5), N)
	D_prob = 0.8 .- 0.6 .* Z
	D = rand.(Binomial.(1, D_prob)) # Boadcast rand and Binomial across D_prob vector 
	ϵ = rand(Normal(), N)
	Y = 1 * D + 3 * Z + ϵ
	df = DataFrame(Y = Y, D = D, Z = Z)

	# Estimate models
	correct = lm(@formula(Y ~ D + Z), df)
	confounded = lm(@formula(Y ~ D), df)
	auxiliary = lm(@formula(Z ~ D), df)

	# Extract parameters
	τ̂ = coef(correct)[2]
	τ̂ₒ = coef(confounded)[2]
	γ̂ = coef(correct)[3]
	δ̂ = coef(auxiliary)[2]

	# Find omitted variable bias
	τ̂ᵣ = τ̂ + γ̂ * δ̂

	# Compare to estimate from confounded model
	τ̂ᵣ_minus_τ̂ₒ = τ̂ᵣ - τ̂ₒ

	"τ̂ᵣ - τ̂ₒ = $τ̂ᵣ_minus_τ̂ₒ"
end

# ╔═╡ 412b76d2-65fc-11eb-2940-ab253f3969e5
md"
> **Julia play notes:** It was pretty straightforward to convert Vincent's R simulation into Julia. The one thing that tripped me up was simulating values for `D`. Julia's `rand` and `Binomial` functions are not vectorised. So, when I wanted to pass a vector (a one-dimensional array) of success probabilities to `Binomial`, I got an error `MethodError: no method matching Binomial(::Int64, ::Array{Int64,1})`. The solution was pretty simple--\"broadcast\" `Binomial` and `rand` with the [Dot syntax](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) (`.`) across the vector. On the plus side, I really like being able to use the greek letters from the formula in the text to name the variables in the code. Improves the code readability. 

"

# ╔═╡ 0b35cb68-65fc-11eb-01b6-19e27f5eb0aa
md"

## Omitted variable bias sensitivity analysis using Cinelli and Hazlett (2020)

The above example helps us develop an intuition for the bias created by omitting confounders from a regression. But it isn't a practical way to asses omitted variable bias in research because (a) we often don't observe the confounders, that's why we didn't include them and (b) there are usually many confounders with non-linear confounding.

How might we measure how sensitive our models, including more complex models with non-linear relationships, to omitted confounders?

Vincent plays through [Cinelli and Hazlett's (2020)](https://doi.org/10.1111/rssb.12348) approach. They pose the question: 

> how strong do all omitted confounders need to be to overturn the conclusions from a model?

To answer this question, they reparameterise the bias in terms of partial ``R^2``:

``
|\widehat{b i a s}|=\sqrt{\left(\frac{R_{Y \sim Z \mid D, X}^{2} R_{D \sim Z \mid X}^{2}}{1-R_{D \sim Z \mid X}^{2}}\right)} \frac{s d\left(Y^{\perp X, D}\right)}{s d\left(D^{\perp X}\right)}
``

where ``R^2_{Y \sim Z|D,X}`` and so on are partial ``R^2`` values.

They pose a more practical version of the sensitivity analysis that reports a single \"robustness value\". This value is based on considering a critical case where the strength of the impact of the confounders on the outcome (effect of ``Z`` on ``Y``) and the strength of the imbalance (effect of ``Z`` on ``D``) are equal (``\gamma = \delta``). The robustness value they derive from this case is:

``
RV_q = \frac{1}{2}\{\sqrt{(f^4_q + 4f^2_q) - f^2_q}\}
``

where 

- ``q`` is the proportion of reduction ``q`` on the treatment coefficient that the researcher decides is problematic,

- ``f_q := q | f_{y\sim D|X}| `` and ``f_{y\sim D|X}``is the partial Cohen's ``f`` of the treatment with the outcome.

The interpretation of ``RV_q`` is:

> \"Confounders that explain ``RV_q``% both of the treatment and of the outcome are sufﬁciently strong to change the point estimate in problematic ways, whereas confounders with neither association greater than ``RV_q``% are not.\"

If ``RV_q`` is close to 1, then the omitted confounders would need to explain almost 100% of the treatment and outcome to be a problem for our conclusions. If it is close to 0, then it is plausible that confounders explain both the treatment and the outcome and our results.

Here is a Julia version of the function to compute ``RV_q``:
"

# ╔═╡ a25b3a1e-6642-11eb-0da8-b788c9bdb006
"""
	robustness_value(;fit::StatsModels.TableRegressionModel, 
					 treatment::String = "D", q::Int64 = 1)

Find the Cinelli and Hazlett (2020) robustness value for a generalised linear model. 
The response will be a in the range 0 and 1. Values closer to 0 indicate that 
the conclusions from the original model are highly subject to omitted variable 
bias. Values closer to 1 indicate that the original model is less likely to be 
caused by omitted variable bias.
"""
function robustness_value(;fit::StatsModels.TableRegressionModel,
						  treatment::String = "D", q::Int64 = 1)	
	# Extract coefficient table from fitted model	
	m = coeftable(fit)
	
	# find treatment parameter row in coefficient table
	treat_position = findfirst(x -> x == treatment, m.rownms)
	t_value_position = findfirst(x -> x == "t", m.colnms)
	
	
	t_value = m.cols[t_value_position][treat_position][1]
	df = dof_residual(fit)
	fq = abs(t_value / sqrt(df)) * q
	1/2 * (sqrt(fq^4 + 4 * fq^2) - fq^2)
end

# ╔═╡ 57c7f880-66b4-11eb-2c18-c3d0b0144050
robustness_value(fit = confounded, treatment = "D", q = 1)

# ╔═╡ 416962a6-66b7-11eb-0d72-efbaaf02f293
md"

The interpretation of this robustness value is that confounders that explain about 23% of both ``X`` and ``Y`` are strong enough to change the estimated treatment effect by 100%.  

"

# ╔═╡ 05b51af6-66b3-11eb-060f-455f3efc5466
md"
> **Julia play notes:** Overall the conversion from Vincent's R code to Julia was straightforward. However, two things tripped me up. First, to extract the t-value I needed to learn how to \"break into\" the regression model object. This required a bit of digging. Julia's `coeftable` is similar to R's `summary` function in that it returns the key model summaries. It returns 3 arrays with the parameter estimates (`cols`), parameter names (`colnms`), and variable names (`rownms`). I then needed to `findfirst` the row of the treatment estimates and the t-value column. Notice that these statements contains [anonymous functions](https://docs.julialang.org/en/v1/manual/functions/#man-anonymous-functions); throwaway functions declared with `->`. Using `findfirst` I could programatically find the treatment's t-value from the `cols` array. Note that I finally needed to extract the scalar value with a final `[1]`, otherwise there were problems with finding the absolute value (`abs`). Second, for practice I wanted to fully use Julia's function type checking ability, e.g. `treatment::String` ensures that the `treatment` argument value is a `String`. To do this (I think) I need declare that the arguments are [\"keyword\" arguments](https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments) rather than \"positional\" arguments. Keyword arguments are declared by placing them after a semi-colon `;`.  

"

# ╔═╡ 6b26ccdc-6849-11eb-100a-5fb61eeb6c92
md"
Vincent ends his post with a nice demonstration of a sensitivity analysis using Cinelli, Ferwerda, and Hazlett's [sensemakr](https://cran.r-project.org/web/packages/sensemakr/) R package (see [useR tutorial](https://www.youtube.com/watch?v=p3dfHj6ki68)). Well, this doesn't exist for Julia. Maybe if I have some spare time I'll play around with working on that.

"

# ╔═╡ Cell order:
# ╟─af10f252-6573-11eb-2844-09f83484799f
# ╟─f1ab12da-6573-11eb-1043-95d1f6de5644
# ╠═c18e2d8a-6573-11eb-1174-8d77b4b1fa42
# ╠═3ff5fe52-6577-11eb-18ab-6df251b74660
# ╟─412b76d2-65fc-11eb-2940-ab253f3969e5
# ╟─0b35cb68-65fc-11eb-01b6-19e27f5eb0aa
# ╠═a25b3a1e-6642-11eb-0da8-b788c9bdb006
# ╠═57c7f880-66b4-11eb-2c18-c3d0b0144050
# ╟─416962a6-66b7-11eb-0d72-efbaaf02f293
# ╟─05b51af6-66b3-11eb-060f-455f3efc5466
# ╟─6b26ccdc-6849-11eb-100a-5fb61eeb6c92

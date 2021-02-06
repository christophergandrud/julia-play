### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 75031ade-6468-11eb-30f4-31d6f825ad97
begin
	using Images
	mario = load("img/mario.jpg")
end

# ╔═╡ 0c6a6014-64a7-11eb-09ab-9758beacc6e1
using PlutoUI

# ╔═╡ 11ddd586-6468-11eb-0f2b-23488d68c9ca
md"

# Play around with images in Julia


This notebook is based on this [MIT intro to computational abstraction](https://video.cs50.io/DGojI9xcCfg).
"

# ╔═╡ d7606dda-649c-11eb-03a8-c197fe62823b
size(mario)

# ╔═╡ acd766c4-64a4-11eb-2b8d-ab4a5b55e465
head = mario[70:300, 400:700] 

# ╔═╡ d595b1a6-64a4-11eb-1d87-7fbd5e132d5e
[head, reverse(head, dims = 2)]

# ╔═╡ 977111a8-64a5-11eb-1c44-f382caf447d0
md"
## Play with broadcasting
"

# ╔═╡ a31586ba-64a5-11eb-2d31-0b6ae3b4a8ff
function greenify(colour, offset = 0)
	offset = offset / 100
	new_r = colour.r*offset
	new_b = colour.b*offset
	return RGB(new_r, colour.g, new_b)
end

# ╔═╡ ca8d542a-64a5-11eb-3946-4f6926af4f86
md" ### One off usecase"

# ╔═╡ f55cb3b2-64a5-11eb-213b-9f4c9e6aa612
begin 
	color = RGB(0.8, 0.6, 0.2)
	
	[color, greenify(color)]
end

# ╔═╡ 4c58f724-6562-11eb-1ef1-e1175f50df3f
md" ## Bunt"

# ╔═╡ 576286ea-6562-11eb-108c-05ffdf298312
function bunt()
	ranger = 0:10
	for i in ranger
		return RGB(i/100, 0.2, 0.2)
	end
end


# ╔═╡ 9dc5660e-6562-11eb-20af-cda04fabba41
bunt()

# ╔═╡ 419a9b72-64a6-11eb-24f5-eb4364160345
md"### Play with sliders"

# ╔═╡ 25b395c2-64a7-11eb-0953-f1bd3e241e7b
@bind green_factor Slider(0:100, show_value = true)

# ╔═╡ 18cdbd00-64b0-11eb-3721-63ed3b0ff457
greenify.(mario, green_factor)

# ╔═╡ e48c8006-6560-11eb-36ac-331757376180
function redify(colour, offset = 0)
	offset = offset / 100
	new_g = colour.g*offset
	new_b = colour.b*offset
	return RGB(colour.r, new_g, new_b)
end

# ╔═╡ f8c6d2c4-6560-11eb-022f-e5a1d9b99bc4
@bind redify_factor Slider(0:100, show_value = true)

# ╔═╡ 0822958c-6561-11eb-3e84-a98f615f7690
redify.(mario, redify_factor)

# ╔═╡ 79b3f45e-6561-11eb-0e14-5dcdb0def059
function blueify(colour, offset = 0)
	offset = offset / 100
	new_r = colour.r*offset
	new_g = colour.g*offset
	return RGB(new_r, new_g, colour.b)
end

# ╔═╡ 99856d10-6561-11eb-36b0-e9d71c163d14
@bind blue_factor Slider(0:100, show_value = true)

# ╔═╡ a299a0f6-6561-11eb-2957-4d9f64cb714c
blueify.(mario, blue_factor)

# ╔═╡ dff885bc-656a-11eb-3e1c-2365fa9e675d
sum(mario

# ╔═╡ Cell order:
# ╟─11ddd586-6468-11eb-0f2b-23488d68c9ca
# ╠═75031ade-6468-11eb-30f4-31d6f825ad97
# ╠═d7606dda-649c-11eb-03a8-c197fe62823b
# ╠═acd766c4-64a4-11eb-2b8d-ab4a5b55e465
# ╠═d595b1a6-64a4-11eb-1d87-7fbd5e132d5e
# ╟─977111a8-64a5-11eb-1c44-f382caf447d0
# ╠═a31586ba-64a5-11eb-2d31-0b6ae3b4a8ff
# ╟─ca8d542a-64a5-11eb-3946-4f6926af4f86
# ╠═f55cb3b2-64a5-11eb-213b-9f4c9e6aa612
# ╟─4c58f724-6562-11eb-1ef1-e1175f50df3f
# ╠═576286ea-6562-11eb-108c-05ffdf298312
# ╠═9dc5660e-6562-11eb-20af-cda04fabba41
# ╟─419a9b72-64a6-11eb-24f5-eb4364160345
# ╠═0c6a6014-64a7-11eb-09ab-9758beacc6e1
# ╠═25b395c2-64a7-11eb-0953-f1bd3e241e7b
# ╠═18cdbd00-64b0-11eb-3721-63ed3b0ff457
# ╠═e48c8006-6560-11eb-36ac-331757376180
# ╠═f8c6d2c4-6560-11eb-022f-e5a1d9b99bc4
# ╠═0822958c-6561-11eb-3e84-a98f615f7690
# ╠═79b3f45e-6561-11eb-0e14-5dcdb0def059
# ╠═99856d10-6561-11eb-36b0-e9d71c163d14
# ╠═a299a0f6-6561-11eb-2957-4d9f64cb714c
# ╠═dff885bc-656a-11eb-3e1c-2365fa9e675d

module RD
using Distributions
using Random
rng = Xoshiro(161004)

num_points = 30
x1_dist = Normal(0.0, 1.0)
x1 = rand(rng, x1_dist, num_points)
x2_dist = Normal(0.0, 2.0)
x2 = rand(rng, x2_dist, num_points)
y = @. 2 + 3 * (x2 + x1 * (1 - x2))
# which is 2 + 3 x2 + 3 x1 ( 1 - x2)
#          2 + 3 x2 + 3 x1 - 3 x1 x2

X = [x1 x2]
end # module RD

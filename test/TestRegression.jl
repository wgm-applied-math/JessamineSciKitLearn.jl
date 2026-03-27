include("RandomData.jl")

spec = Dict(
    "lambda_op" => 1e-6,
    "stop_deadline" => now() + Dates.Second(30),
    "num_islands" => 2,
)

result = regression_main(RD.X, RD.y, spec)
@show result

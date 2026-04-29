include("RandomData.jl")

prespec = Dict{String,Any}(
    "lambda_op" => 1e-6,
    "stop_deadline" => now() + Dates.Second(30),
    "num_islands" => 2,
    "op_inventory" => "Polynomial; RationalFunction"
)

result = regression_main(RD.X, RD.y, prespec)
@show result

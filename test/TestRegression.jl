include("RandomData.jl")

println("=== Baseline ===")
prespec = Dict{String,Any}(
    "lambda_op" => 1e-6,
    "stop_deadline" => now() + Dates.Second(30),
    "num_islands" => 2,
    "op_inventory" => "Polynomial; RationalFunction",
)

result = regression_main(RD.X, RD.y, prespec)
@show result.discoveries[1]

println("=== With random subset ===")
prespec = Dict{String,Any}(
    "lambda_op" => 1e-6,
    "stop_deadline" => now() + Dates.Second(30),
    "num_islands" => 2,
    "op_inventory" => "Polynomial; RationalFunction",
    "random_subset_count" => 30,
)

result = regression_main(RD.X, RD.y, prespec)
@show result.discoveries[1]

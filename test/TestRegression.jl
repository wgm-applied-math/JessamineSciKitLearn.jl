include("RandomData.jl")

result = regression_main(RD.X, RD.y)
@show result

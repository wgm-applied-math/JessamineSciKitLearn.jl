using Dates
using Random
using Test
using JessamineSciKitLearn

Random.seed!(0x30c4070874d73da0)

@testset "JessamineSciKitLearn.jl" begin
    include("TestRegression.jl")
end

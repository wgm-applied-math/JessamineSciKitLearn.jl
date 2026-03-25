using Jessamine
using Distributions
using Random

include("Config.jl")

function run_regression_island(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real}
    ;
    rng=Random.default_rng())

    arity_dist = DiscreteNonParametric([1, 2, 3], [0.25, 0.5, 0.25])
    @debug "run_regression_island: Begin random_initial_population"
    pop_init = random_initial_population(rng, spec.exploration_spec, arity_dist)
    @debug "run_regression_island: End random_initial_population"
    @debug "run_regression_island: Begin exploration stage"
    pop_after_explore = evolution_loop(
        rng, spec.exploration_spec, pop_init,
        stop_deadline = spec.stop_deadline,
        stop_channel = sepc.stop_channel,
        max_generations = spec.exploration_generations,
        discovery_channel = spec.discovery_channel)
    @debug "run_regression_island: End exploration stage"
    @debug "run_regression_island: Begin simplification stage"
    pop_after_simplify = evolution_loop(
        rng, spec.exploration_spec, pop_after_explore,
        stop_deadline = spec.stop_deadline,
        stop_channel = sepc.stop_channel,
        max_generations = spec.simplification_generations,
        discovery_channel = spec.discovery_channel)
    @debug "run_regression_island: End simplification stage"
    return pop_after_simplify
end


function run_regression_many_islands(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real}
    ;
    rng=Random.default_rng())



end

using Accessors
using Distributions
using Random

using Jessamine

include("Config.jl")

function run_island(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real}
    ;
    rng=Random.default_rng())

    arity_dist = DiscreteNonParametric([1, 2, 3], [0.25, 0.5, 0.25])

    @debug "run_island: Begin random_initial_population"
    pop_init = random_initial_population(
        rng,
        spec.exploration_spec,
        arity_dist,
        spec.exploration_spec.s_spec,
        domain_safe = true)
    @debug "run_island: End random_initial_population"
    @debug "run_island: Begin exploration stage"
    pop_after_explore = evolution_loop(
        rng,
        spec.exploration_spec,
        pop_init,
        stop_deadline = spec.stop_deadline,
        stop_channel = spec.stop_channel,
        max_generations = spec.exploration_generations,
        discovery_channel = spec.discovery_channel)
    @debug "run_island: End exploration stage"
    @debug "run_island: Begin simplification stage"
    pop_after_simplify = evolution_loop(
        rng,
        spec.exploration_spec,
        pop_after_explore,
        stop_threshold = spec.stop_threshold,
        stop_deadline = spec.stop_deadline,
        stop_channel = spec.stop_channel,
        max_generations = spec.simplification_generations,
        discovery_channel = spec.discovery_channel)
    @debug "run_island: End simplification stage"
    return pop_after_simplify
end


function run_many_islands(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real}
    ;
    rng=Random.default_rng())

    best_rating = nothing

    function filter_discoveries(c_get, c_put)
        for a in c_get
            @debug "run_many_islands/filter_discoveries: Received agent with rating $(a.rating)"
            if !isnothing(best_rating) && is_better(best_rating, a.rating)
                best_rating = a.rating
                @debug "run_regression_many_islands/filter_discoveries: New best rating $best_rating"
                put!(c_put, a)
            else
                @debug "run_many_islands/filter_discoveries: Not better than $best_rating"
            end
        end
    end



end

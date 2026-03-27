using Accessors
using Distributions
using Random

using Jessamine

include("Config.jl")

struct ExploreSimplifySearchJob
    spec::ExploreSimplifySearchSpec
    discovery_channel::Channel
end

function run_island(
    job::ExploreSimplifySearchJob,
    ;
    rng=Random.default_rng())

    arity_dist = DiscreteNonParametric([1, 2, 3], [0.25, 0.5, 0.25])

    @debug "run_island: Begin random_initial_population"
    pop_init = random_initial_population(
        rng,
        job.spec.exploration_spec,
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
        max_generations = spec.simplification_generations,
        discovery_channel = spec.discovery_channel)
    @debug "run_island: End simplification stage"
    put!(finished_channel, pop_after_simplify)
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

    filtered_channel = Channel()
    new_spec = @set spec.discovery_channel = filtered_channel
    Tasks.@spawn filter_discoveries(spec.discovery_channel, new_spec.discovery_channel)

    condition = nothing
    island_progress = Channel()

    function launch_island()
        Tasks.@spawn run_island(
            island_progress,
            new_spec,
            X,
            y;
            rng)
    end

    # Launch a bunch of islands
    for j in 1:new_spec.num_islands
        launch_island()
    end

    while true
        # Maybe stop
        if !isnothing(new_spec.stop_channel) && isready(new_spec.stop_channel) && take!(new_spec.stop_channel)
            condition = ReceivedStopMessage()
            break
        end
        if !isnothing(new_spec.stop_deadline) && now() > new_spec.stop_deadline
            condition = ReachedDeadline()
            break
        end

        # When one island finishes, launch another
        result = take!(island_progress)
        launch_island()
    end
    return condition
end

# set up the grow&rate function on the data
# build the configuration
# launch

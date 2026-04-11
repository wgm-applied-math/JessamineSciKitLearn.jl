struct ExploreSimplifySearchJob
    spec::ExploreSimplifySearchSpec
    grow_and_rate::Any
    discovery_channel::Channel{Agent}
end

function run_island(
    job::ExploreSimplifySearchJob,
    finished_channel::Channel{Population},
    ;
    stop_deadline::Union{DateTime,Nothing} = nothing,
    rng = Random.default_rng())
    @debug "run_island: Top"

    spec = job.spec
    arity_dist = DiscreteNonParametric([1, 2, 3], [0.25, 0.5, 0.25])

    explore_evolution_spec = EvolutionSpec(
        spec.genome_spec,
        spec.exploration_spec.m_spec,
        spec.exploration_spec.s_spec,
        job.grow_and_rate,
        spec.exploration_spec.max_generations,
    )
    @debug "run_island: Begin random_initial_population"
    pop_init = random_initial_population(
        rng,
        explore_evolution_spec,
        arity_dist,
        domain_safe = true,
    )
    @debug "run_island: End random_initial_population"
    @debug "run_island: Begin exploration stage"
    pop_after_explore = evolution_loop(
        rng,
        explore_evolution_spec,
        pop_init,
        stop_deadline = stop_deadline,
        discovery_channel = job.discovery_channel)
    @debug "run_island: End exploration stage"
    if isnothing(job.spec.simplification_spec)
        @debug "run_island: No simplification stage specified"
        put!(finished_channel, pop_after_explore)
    else
        simplification_evolution_spec = EvolutionSpec(
            spec.genome_spec,
            spec.simplification_spec.m_spec,
            spec.simplification_spec.s_spec,
            job.grow_and_rate,
            spec.simplification_spec.max_generations,
        )

        @debug "run_island: Begin simplification stage"
        pop_after_simplify = evolution_loop(
            rng,
            simplification_evolution_spec,
            pop_after_explore,
            stop_threshold = spec.stop_threshold,
            stop_deadline = stop_deadline,
            discovery_channel = job.discovery_channel)
        @debug "run_island: End simplification stage"
        put!(finished_channel, pop_after_simplify)
    end
end


function run_many_islands(
        spec::ExploreSimplifySearchSpec,
        grow_and_rate,
        discovery_channel::Channel{Agent},
        ;
        stop_deadline::Union{DateTime,Nothing} = nothing,
        rng = Random.default_rng())

    best_rating = nothing

    function filter_discoveries(c_get, c_put)
        for a in c_get
            @debug "run_many_islands/filter_discoveries: Received agent with rating $(a.rating)"
            if isnothing(best_rating) || a.rating < best_rating
                best_rating = a.rating
                @debug "run_regression_many_islands/filter_discoveries: New best rating $best_rating"
                put!(c_put, a)
            else
                @debug "run_many_islands/filter_discoveries: Not better than $best_rating"
            end
        end
    end

    unfiltered_channel = Channel{Agent}(2*spec.num_islands)
    Threads.@spawn begin
        try
            filter_discoveries(unfiltered_channel, discovery_channel)
        catch err
            @error "run_many_islands: Exception during ./filter_discoveries" exception=(err, catch_backtrace())
            rethrow()
        end
    end
    finished_channel = Channel{Population}(2*spec.num_islands)

    function launch_island()
        job = ExploreSimplifySearchJob(
            spec,
            grow_and_rate,
            unfiltered_channel
        )
        @debug "run_many_islands/launch_island: Launching island"
        Threads.@spawn begin
            try
                run_island(job, finished_channel; stop_deadline, rng)
            catch err
                @error "run_many_islands: Exception during run_island" exception=(err, catch_backtrace())
                rethrow()
            end
        end
    end

    # Launch a bunch of islands
    for j in 1:spec.num_islands
        launch_island()
    end

    condition = nothing
    while true
        # Maybe stop: TODO Each island needs its own stop channel
        # if !isnothing(spec.stop_channel) && isready(spec.stop_channel) && take!(spec.stop_channel)
        #     condition = ReceivedStopMessage()
        #     break
        # end
        if !isnothing(stop_deadline) && now() > stop_deadline
            condition = ReachedDeadline()
            break
        end

        @debug "run_many_islands: Waiting for island to finish"
        # When one island finishes, launch another
        result = take!(finished_channel)
        @debug "run_many_islands: Island finished; launching another"
        launch_island()
    end
    return condition
end

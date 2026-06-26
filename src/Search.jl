struct ExploreSimplifySearchJob{TX,Ty}
    spec::ExploreSimplifySearchSpec
    X::TX
    y::Ty
    random_subset_count::Union{Nothing,UInt64}
    discovery_channel::Channel{Agent}
end


function make_grow_and_rate(rng, job::ExploreSimplifySearchJob)
    spec = job.spec

    if isnothing(job.random_subset_count) || job.random_subset_count > length(job.y)
        X = job.X
        y = job.y
    else
        train_ixs = StatsBase.sample(rng, eachindex(job.y), job.random_subset_count;
                                     replace=false, ordered=true)
        X = job.X[train_ixs,:]
        y = job.y[train_ixs]
    end

    # The definition of xs should conceptually be just
    # eachcol(X).  The contortions here are for type sanity.  If
    # I don't do the collect(), then there's chaos trying to deal
    # with the columns of X when it's a DataFrame and the columns
    # can theoretically have different element types.  I don't
    # entirely understand this.  The problem manifests as
    # exceptions involving evaluating Jessamine.Multiply() with
    # an empty operand list: It can't figure out the correct type
    # of 1 to use.
    xs = [collect(c) for c in eachcol(X)]

    function grow_and_rate(rng, g_spec, genome)
        return least_squares_ridge_grow_and_rate(
            xs,
            y,
            spec.lambda_b,
            spec.lambda_p,
            spec.lambda_op,
            g_spec,
            genome,
        )
    end

    return grow_and_rate
end

function run_island(
    job::ExploreSimplifySearchJob,
    finished_channel::Channel{Tuple{Population,ExploreSimplifySearchJob}},
    ;
    stop_deadline::Union{DateTime,Nothing} = nothing,
    stop_threshold::Union{Real,Nothing} = nothing,
    rng = Random.default_rng(),
    verbosity = 1,
)
    @debug "run_island: Top"

    spec = job.spec
    arity_dist = DiscreteNonParametric([1, 2, 3], [0.25, 0.5, 0.25])

    grow_and_rate = make_grow_and_rate(rng, job)

    explore_evolution_spec = EvolutionSpec(
        spec.genome_spec,
        spec.exploration_spec.m_spec,
        spec.exploration_spec.s_spec,
        grow_and_rate,
        spec.exploration_spec.max_generations,
    )
    @debug "run_island: Begin random_initial_population"
    pop_init = random_initial_population(
        rng,
        explore_evolution_spec,
        arity_dist,
        domain_safe = true
    )
    @debug "run_island: End random_initial_population"
    # Send best so far to the discovery channel.  Sometimes the
    # problem is so easy that the best is discovered right away,
    # and if we don't send it now, it never gets sent.
    put!(job.discovery_channel, pop_init.agents[1])
    @debug "run_island: Begin exploration stage"
    pop_after_explore = evolution_loop(
        rng,
        explore_evolution_spec,
        pop_init;
        stop_deadline,
        stop_threshold,
        verbosity,
        discovery_channel = job.discovery_channel,
    )
    @debug "run_island: End exploration stage"
    final_pop = pop_after_explore
    if isnothing(job.spec.simplification_spec)
        @debug "run_island: No simplification stage specified"
    else
        simplification_evolution_spec = EvolutionSpec(
            spec.genome_spec,
            spec.simplification_spec.m_spec,
            spec.simplification_spec.s_spec,
            grow_and_rate,
            spec.simplification_spec.max_generations,
        )

        @debug "run_island: Begin evolutionary simplification stage"
        pop_after_simplify = evolution_loop(
            rng,
            simplification_evolution_spec,
            pop_after_explore,
            stop_threshold = spec.stop_threshold,
            stop_deadline = stop_deadline,
            discovery_channel = job.discovery_channel,
            verbosity = verbosity
        )
        @debug "run_island: End evolutionary simplification stage"
        final_pop = pop_after_simplify
    end
    put!(finished_channel, (final_pop, job))
end


function run_many_islands(
    X,
    y,
    discovery_channel::Channel{Agent},
    prespec::AbstractDict,
    ;
    stop_deadline::Union{DateTime,Nothing} = nothing,
    stop_threshold::Union{Real,Nothing} = nothing,
    rng = Random.default_rng(),
    verbosity = 1
)

    @debug "run_many_islands: prespec = $prespec"

    @cfield prespec random_subset_count nothing Union{Nothing,UInt64}

    n_points, input_size = size(X)
    @assert n_points == length(y)

    best_rating = nothing

    function filter_discoveries(c_get, c_put)
        for a in c_get
            @debug_or_info verbosity "run_many_islands/filter_discoveries: Received agent with rating $(a.rating)"
            if isnothing(best_rating) || a.rating < best_rating
                best_rating = a.rating
                @debug_or_info verbosity "run_many_islands/filter_discoveries: New best rating $best_rating"
                put!(c_put, a)
            else
                @debug_or_info verbosity "run_many_islands/filter_discoveries: Not better than $best_rating"
            end
        end
    end

    unfiltered_channel = Channel{Agent}(100)
    Threads.@spawn begin
        try
            filter_discoveries(unfiltered_channel, discovery_channel)
        catch err
            @error "run_many_islands: Exception during ./filter_discoveries" exception=(
                err,
                catch_backtrace(),
            )
            if verbosity > 1
                rethrow()
            end
        end
    end
    finished_channel = Channel{Tuple{Population,ExploreSimplifySearchJob}}(100)

    # Provide a source of ID numbers
    island_id_channel = Channel{Int64}(10)
    Threads.@spawn begin
        j = 1
        while true
            put!(island_id_channel, j)
            j = j+1
        end
    end

    function launch_island(job)
        @debug "run_many_islands/launch_island: Launching island"
        Threads.@spawn begin
            try
                island_id = take!(island_id_channel)
                @debug_or_info verbosity "About to launch island" island_id=island_id
                run_island(job, finished_channel; stop_deadline, stop_threshold, rng, verbosity)
            catch err
                @error "run_many_islands: Exception during run_island" exception=(
                    err,
                    catch_backtrace(),
                )
                if verbosity > 1
                    rethrow()
                end
            end
        end
    end

    g_spec = nothing

    function launch_islands(prespec)
        @debug "run_many_islands/launch_islands: prespec = $prespec"
        spec = parse_search_spec(prespec, input_size)
        @debug "run_many_islands/launch_islands: spec = $spec"
        if isnothing(g_spec)
            g_spec = spec.genome_spec
        end
        @debug "run_many_islands/launch_islands: genome_spec = $g_spec"

        job = ExploreSimplifySearchJob(spec, X, y, random_subset_count, unfiltered_channel)

        for j = 1:spec.num_islands
            @debug "run_many_islands/launch_islands: Launching island $j"
            launch_island(job)
        end
    end

    # Launch a bunch of islands
    for island_spec in explode([prespec], ["op_inventory"])
        launch_islands(island_spec)
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

        # If we've hit the desired threshold, stop.
        if (!isnothing(stop_threshold)
            && !isnothing(best_rating)
            && best_rating < stop_threshold)
            @debug "run_many_islands: Reached stop threshold; stopping"
            condition = ReachedStopThreshold()
            break
        end

        @debug "run_many_islands: Waiting for island to finish"
        # When one island finishes, launch another
        (result, job) = take!(finished_channel)
        @debug "run_many_islands: Island finished; launching another"
        launch_island(job)
    end

    return (condition, g_spec)
end

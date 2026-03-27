export regression_main


function run_regression(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real};
    stop_deadline::Union{DateTime,Nothing} = nothing,
    rng=Random.default_rng()
    )

    discovery_channel = Channel{Agent}(2*spec.num_islands)
    best_so_far = nothing
    Threads.@spawn begin
        for a in discovery_channel
            @debug "run_regression: New discovery with rating $(a.rating)"
            best_so_far = a
        end
    end

    function grow_and_rate(rng, g_spec, genome)
        return least_squares_ridge_grow_and_rate(
            [collect(c) for c in eachcol(X)],
            y,
            spec.lambda_b,
            spec.lambda_p,
            spec.lambda_op,
            g_spec,
            genome)
    end

    @debug "run_regression: Launching island jobs"
    run_many_islands(spec, grow_and_rate, discovery_channel; stop_deadline, rng)

    @debug "run_regression: Islands ended"
    return best_so_far
end


function agent_to_symbolic(g_spec, a)
    sym_res = model_basic_symbolic_output(g_spec, a)
    return sym_res.y_num
end


function regression_main(
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real},
    spec_source::Dict = Dict();
    rng = Random.default_rng()
    )
    stop_deadline = get(spec_source, "stop_deadline", nothing)
    input_size = size(X)[2]
    spec = parse_search_spec(spec_source, input_size)
    @debug "regression_main: Search spec: $spec"
    @debug "regression_main: Stop deadline: $stop_deadline"
    best_agent = run_regression(spec, X, y; stop_deadline)
    symbolic_form = agent_to_symbolic(spec.genome_spec, best_agent)
    return symbolic_form
end

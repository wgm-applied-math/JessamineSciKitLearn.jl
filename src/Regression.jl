export regression_main


function run_regression(
    spec::ExploreSimplifySearchSpec,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real};
    stop_deadline::Union{DateTime,Nothing} = nothing,
    rng=Random.default_rng()
    )

    @debug "run_regression: spec: $spec"

    discovery_channel = Channel{Agent}(2*spec.num_islands)
    best_so_far = nothing
    Threads.@spawn begin
        for a in discovery_channel
            @info "run_regression: New discovery with rating $(a.rating)"
            if isnothing(best_so_far) || a.rating < best_so_far.rating
                @info "run_regression: Keeping"
                best_so_far = a
            end
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


function regression_main(
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real},
    spec_source::AbstractDict = Dict()
    )
    @debug "regression_main: spec_source = $spec_source"
    rng = Random.default_rng()
    @cfield spec_source rng_seed 0xFEDCBA09876543210
    Random.seed!(rng, rng_seed)
    default_deadline = now() + Dates.Second(30)
    stop_deadline = get_or_parse(spec_source, "stop_deadline", default_deadline)
    @info "regression_main: stop_deadline = $stop_deadline"
    n_points, input_size = size(X)
    @assert n_points == length(y)
    spec = parse_search_spec(spec_source, input_size)
    @debug "regression_main: Search spec: $spec"
    @debug "regression_main: Stop deadline: $stop_deadline"
    best_agent = run_regression(spec, X, y; stop_deadline)
    sym_res = model_basic_symbolic_output(spec.genome_spec, best_agent)
    return to_careful_string(sym_res.y_num)
end

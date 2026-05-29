export regression_main, regression_main_detailed


function run_regression(
    X, # X::AbstractMatrix{<:Real},
    y, # y::AbstractVector{<:Real},
    prespec::AbstractDict;
    stop_deadline::Union{DateTime,Nothing} = nothing,
    rng = Random.default_rng(),
)
    @info "run_regression: prespec: $prespec"

    discovery_channel = Channel{Agent}(100)
    best_so_far = nothing
    Threads.@spawn begin
        for a in discovery_channel
            @info "run_regression: Received agent with rating $(a.rating)"
            if isnothing(best_so_far) || a.rating < best_so_far.rating
                @info "run_regression: New best rating $(a.rating):\n$(very_short_show(a))"
                best_so_far = a
            elseif !isnothing(best_so_far)
                @info "run_regression: Not better than $(best_so_far.rating)"
            end

        end
    end

    @info "run_regression: Launching island jobs"
    (condition, g_spec) =
        run_many_islands(X, y, discovery_channel, prespec; stop_deadline, rng)

    @info "run_regression: Islands ended, condition = $condition"
    @info "run_regression: best rating: $(best_so_far.rating)"
    return (best_so_far, g_spec)
end


function regression_main_detailed(
    X, # X::AbstractMatrix{<:Real},
    y, # y::AbstractVector{<:Real},
    prespec::AbstractDict{<:Any,<:Any} = Dict()
    )
    @info "regression_main: prespec = $prespec"
    # Explosions
    op_inv_pre = prespec["op_inventory"]
    op_inv_pre_seq = split_on_semicolons(op_inv_pre)
    prespec["op_inventory"] = op_inv_pre_seq
    rng = Random.default_rng()
    # scikit-learn requires a 32-bit integer for the random state.
    @cfield prespec random_state UInt32(0x76543210)
    Random.seed!(rng, random_state)
    default_deadline = now() + Dates.Second(30)
    stop_deadline = get_or_parse(prespec, "stop_deadline", default_deadline)
    @info "regression_main: stop_deadline = $stop_deadline"
    (best_agent, genome_spec) = run_regression(X, y, prespec, stop_deadline = stop_deadline)
    @info "regression_main: Best:\n$(very_short_show(best_agent))"
    sym_res = model_basic_symbolic_output(genome_spec, best_agent)
    @info "regression_main: Best (symbolic): $sym_res"
    y_num_str = to_careful_string(sym_res.y_num)
    @info "regression_main: Best (careful string): $y_num_str"
    (best_agent = best_agent,
     genome_spec = genome_spec,
     sym_res = sym_res,
     y_num_str = y_num_str)
end

function regression_main(X, y, prespec::AbstractDict{<:Any,<:Any} = Dict())
    result = regression_main_detailed(X, y, prespec)
    return result.y_num_str
end

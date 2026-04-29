export regression_main


function run_regression(
    prespec::AbstractDict,
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real};
    stop_deadline::Union{DateTime,Nothing} = nothing,
    rng=Random.default_rng()
    )
    @info "run_regression: prespec: $prespec"

    discovery_channel = Channel{Agent}(100)
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

    @info "run_regression: Launching island jobs"
    (condition, g_spec) = run_many_islands(prespec, X, y, discovery_channel; stop_deadline, rng)

    @info "run_regression: Islands ended, condition = $condition"
    @info "run_regression: best rating: $(best_so_far.rating)"
    return (best_so_far, g_spec)
end


function regression_main(
    X::AbstractMatrix{<:Real},
    y::AbstractVector{<:Real},
    prespec::AbstractDict{<:AbstractString,<:Any} = Dict()
    )
    @info "regression_main: prespec = $prespec"
    # Explosions
    op_inv_pre = prespec["op_inventory"]
    op_inv_pre_seq = split_on_semicolons(op_inv_pre)
    prespec["op_inventory"] = op_inv_pre_seq
    rng = Random.default_rng()
    @cfield prespec rng_seed 0xFEDCBA09876543210
    Random.seed!(rng, rng_seed)
    default_deadline = now() + Dates.Second(30)
    stop_deadline = get_or_parse(prespec, "stop_deadline", default_deadline)
    @info "regression_main: stop_deadline = $stop_deadline"
    (best_agent, genome_spec) = run_regression(prespec, X, y; stop_deadline)
    sym_res = model_basic_symbolic_output(genome_spec, best_agent)
    @info "regression_main: Best (symbolic): $sym_res"
    y_num_str = to_careful_string(sym_res.y_num)
    @info "regression_main: Best (careful string): $y_num_str"
    return y_num_str
end

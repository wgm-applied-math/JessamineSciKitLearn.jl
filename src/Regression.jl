export regression_main, regression_main_detailed

# This has to be initialized later.  I think it's getting
# compiled in, so the start_time being reported is the time at
# which the module was compiled.
start_time::Union{Nothing,DateTime} = nothing

function save_progress_file(progress_file, agent)
    @debug "save_progress_file: Writing" progress_file=progress_file agent=agent
    mkpath(dirname(progress_file))
    report = Dict(
        "current_time" => now(),
        "start_time" => start_time,
        "agent" => agent,
    )
    JSON.json(progress_file, report)
end

function run_regression(
    X, # X::AbstractMatrix{<:Real},
    y, # y::AbstractVector{<:Real},
    prespec::AbstractDict;
    stop_deadline::Union{DateTime,Nothing} = nothing,
    stop_threshold::Union{Real,Nothing} = nothing,
    rng = Random.default_rng(),
    new_best_agent_hook::Union{Function,Nothing} = nothing,
    verbosity = 1
)
    @debug "run_regression: prespec: $prespec"

    discovery_channel = Channel{Agent}(100)
    best_so_far = nothing
    all_discoveries = []
    Threads.@spawn begin
        for a in discovery_channel
            @debug "run_regression: Received agent with rating $(a.rating)"
            push!(all_discoveries, a)
            if isnothing(best_so_far) || a.rating < best_so_far.rating
                @debug_or_info verbosity "run_regression: New best rating $(a.rating):\n$(very_short_show(a))"
                best_so_far = a
                if !isnothing(new_best_agent_hook)
                    @debug "run_regression: Running new_best_agent_hook"
                    new_best_agent_hook(a)
                else
                    @debug "run_regression: No new_best_agent_hook"
                end
            elseif !isnothing(best_so_far)
                @debug "run_regression: Not better than $(best_so_far.rating)"
            end

        end
    end

    @debug "run_regression: Launching island jobs"
    (condition, g_spec) =
        run_many_islands(X, y, discovery_channel, prespec;
                         stop_deadline, stop_threshold, rng, verbosity)

    @debug_or_info verbosity "run_regression: Islands ended, condition = $condition"
    @debug_or_info verbosity "run_regression: best rating: $(best_so_far.rating)"
    sort!(all_discoveries)
    return (best_so_far, g_spec, all_discoveries)
end


function regression_main_detailed(
    X, # X::AbstractMatrix{<:Real},
    y, # y::AbstractVector{<:Real},
    prespec::AbstractDict{<:Any,<:Any} = Dict();
    verbosity = 1
    )
    @debug "regression_main: prespec = $prespec"
    # Explosions
    op_inv_pre = prespec["op_inventory"]
    op_inv_pre_seq = split_on_semicolons(op_inv_pre)
    prespec["op_inventory"] = op_inv_pre_seq
    rng = Random.default_rng()
    # scikit-learn requires a 32-bit integer for the random state, but I can use a UInt64 in Julia.
    # I used a default of 0xb6500bd3306fd1ca for a while
    @cfield prespec random_state nothing Union{Nothing,UInt64}
    if !isnothing(random_state)
        random_state_str = @sprintf "0x%x" random_state
        @debug "regression_main: Random state seeded with $random_state_str"
        Random.seed!(rng, random_state)
    end
    default_deadline = now() + Dates.Second(30)
    stop_deadline = get_or_parse(prespec, "stop_deadline", default_deadline)
    @debug "regression_main: stop_deadline = $stop_deadline"
    @cfield prespec stop_threshold nothing Union{Float64,Nothing}
    @debug "regression_main: stop_threshold = $stop_threshold"
    @cfield prespec progress_file nothing Union{String,Nothing}
    new_best_agent_hook = if isnothing(progress_file)
        nothing
    else
        @debug "regression_main: progress_file = $progress_file"
        agent -> save_progress_file(progress_file, agent)
    end

    global start_time = now()

    (best_agent, genome_spec, all_discoveries) = run_regression(
        X, y, prespec;
        stop_deadline, stop_threshold, new_best_agent_hook, verbosity)
    @debug_or_info verbosity "regression_main: Best:\n$(very_short_show(best_agent))"

    if !isnothing(best_agent)
        sym_res = model_basic_symbolic_output(genome_spec, best_agent)
        @debug_or_info verbosity "regression_main: Best (symbolic): $sym_res"
        y_num_str = careful_string(sym_res.y_num, PythonStyle())
        @debug_or_info verbosity "regression_main: Best (careful string): $y_num_str"
    end
    discoveries = map(all_discoveries) do agent
        sym_res = model_basic_symbolic_output(genome_spec, agent)
        y_num_str = careful_string(sym_res.y_num, PythonStyle())
        (y_num_str = y_num_str, agent = agent)
    end
    return (genome_spec = genome_spec, discoveries = discoveries)
end

function regression_main(X, y, prespec::AbstractDict{<:Any,<:Any} = Dict())
    regression_main_detailed(X, y, prespec)
end

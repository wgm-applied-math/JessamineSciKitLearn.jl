using Jessamine

function make_problem_for(input_size, opts)
    # Genome specification
    output_size = get(opts, "output_size", 4)
    scratch_size = get(opts, "scratch_size", 2)
    param_size = get(opts, "param_size", 3)
    genome_time_steps = get(opts, "genome_time_steps", 4)
    g_spec = GenomeSpec(
        output_size,
        scratch_size,
        param_size,
        input_size,
        genome_time_steps)

    # Regularization parameters
    lambda_b = get(opts, "lambda_b", 1e-10)
    lambda_p = get(opts, "lambda_p", 1e-10)
    lambda_operands = get(opts, "lambda_operand", 1e-10)

    # Operator inventory
    op_inventory_spec = get(opts, "op_inventory", "Polynomial")
    op_inventory = get_or_build_op_inventory(op_inventory_spec)
end

function get_or_build_op_inventory(op_inventory_spec)
    op_subspecs = split_symbols(op_inventory_spec)
    if isempty(op_subspecs)
        return get_op_inventory("Polynomial")
    else
        if length(op_subspecs) == 1
            op_inventory_lookup = get_op_inventory(op_subspecs[1])
            if op_inventory_lookup.found
                return op_inventory_lookup.inventory
            end
        end
        op_inventory_build = build_op_inventory(op_subspecs)
        if !isempty(op_inventory_build.unknown)
            @warn "get_or_build_op_inventory: Ignoring unrecognized operation inventory specs: $(join(op_inventory_build.unknown))"
        end
        if isempty(op_inventory_build.inventory)
            @warn "get_or_build_op_inventory: No operations specified, using default polynomial inventory"
            return get_op_inventory("Polynomial")
        end
        return op_inventory_build.inventory
    end
end

function split_symbols(s)
    [m.match for m in eachmatch(r"""[^][,'"[:space:]]+""", s)]
end

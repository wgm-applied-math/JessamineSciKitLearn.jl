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
    op_inventory_key = get(opts, "op_inventory", "Polynomial")

end

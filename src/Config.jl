using Jessamine

"""
    @cfield spec key default_value

Extract a configuration field from `spec` (a `Dict` or similar)
using `key` as the lookup key, and `default_value` if it's not
present.  The value will be parsed using `parse` and the type of
`default_value`.  Produce syntax of the form

    key = ...

suitable for inclusion as a variable assignment, field in a named
tuple, keyword argument to a function call, etc.
"""
macro cfield(spec, key, default_value)
    :(
        $(esc(key)) = get($(esc(spec)),
                          parse($(typeof(default_value)), $(string(key))),
                          $default_value)
    )
end

function parse_problem_spec(input_size, s)
    # Regularization parameters
    @cfield s lambda_b lambda_b 1e-10
    @cfield s lambda_p 1e-10
    @cfield s lambda_operand 1e-10

    # Operator inventory
    op_inv_spec = get(s, "op_inventory", "")
    op_inventory = get_or_build_op_inventory(op_inv_spec)

    # Epoch specs
end

function parse_genome_spec(s)
    GenomeSpec(
        ;
        @cfield s output_size 4,
        @cfield s scratch_size 2,
        @cfield s param_size 3,
        @cfield s genome_time_steps 4,
    )
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

function parse_mutation_spec(s, op_inventory)
    MutationSpec(
        ;
        op_inventory,
        @cfield s p_mutate_op 0.15,
        @cfield s p_mutate_index 0.15,
        @cfield s p_duplicate_index 0.015,
        @cfield s p_delete_index 0.015,
        @cfield s p_duplicate_instruction 0.003,
        @cfield s p_delete_instruction 0.003,
        @cfield s p_hop_instruction 0.015,
    )
end

function parse_selection_spec(s)
    SelectionSpec(
        ;
        @cfield s num_to_keep 25,
        @cfield s num_to_generate 75,
        @cfield s p_take_better 0.65,
        @cfield s p_take_very_best 0.25
    )
end


function parse_epoch_spec(s, op_inventory)

    # This has to be a named tuple because
    # EvolutionSpec requires a fitness function.
    g_spec = parse_genome_spec(s)
    m_spec = parse_mutation_spec(s, op_inventory)
    s_spec = parse_selection_spec(s)
end


function f(;kwargs...)
    print(kwargs)
end

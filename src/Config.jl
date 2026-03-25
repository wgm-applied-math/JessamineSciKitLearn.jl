"""
Configuration files for running jobs.
"""

using Jessamine

"""
    ExploreSimplifySearchSpec{Message}

Specifies a search process in which the exploration
`EvolutionSpec` is followed to form the initial population and to
run the bulk of the evolutionary search.  Then a simplification
`EvolutionSpec` is used if given.  The number of generations for
each of those phases is specified.  Islands are run
independently, up to `num_islands` at a time.  When one finishes,
another one is started.  When an agent with a new best rating is
found, it's sent to the `discoveries` channel.
The search continues until the deadline.
"""
@kwdef struct ExploreSimplifySearchSpec{Message}
    genome_spec::GenomeSpec
    exploration_spec::EvolutionSpec
    exploration_generations::Int64
    simplification_spec::Union{EvolutionSpec,Nothing}
    simplification_generations::Int64
    num_islands::Int64
    stop_deadline::Union{Dates.DateTime,Nothing}
    stop_channel::Channel{Any}
    discovery_channel::Channel{Message}
end


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

function parse_run_spec(s, input_size, grow_and_rate)
    # Regularization parameters
    @cfield s lambda_b lambda_b 1e-10
    @cfield s lambda_p 1e-10
    @cfield s lambda_operand 1e-10
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

"""
    split_symbols(s)

Given a string, pull out the sequences of characters that are not
whitespace, a comma, a bracket, a brace, or a quotation mark.
Return themn as an array.  This effectively splits a string of
space- or comma-delimited symbols (identifiers), with our without quotation
marks, into just the symbols.
"""
function split_symbols(s)
    [m.match for m in eachmatch(r"""[^][{},'"[:space:]]+""", s)]
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

# Not sure this is needed:
function parse_evolution_spec(s, op_inventory, grow_and_rate)
    g_spec = parse_genome_spec(s)
    m_spec = parse_mutation_spec(s, op_inventory)
    s_spec = parse_selection_spec(s)
    @cfield s max_generations 10
    EvolutionSpec(g_spec, m_spec, s_spec, grow_and_rate,
                  max_generations)
end

# Not sure if this is needed:
function parse_epoch_spec(s, op_inventory)
    EpochSpec(
        ;
        @cfield s p_mutate_op 0.15,
        @cfield s p_mutate_index 0.15,
        @cfield s p_duplicate_index 0.015,
        @cfield s p_delete_index 0.015,
        @cfield s p_duplicate_instruction 0.003,
        @cfield s p_delete_instruction 0.003,
        @cfield s p_hop_instruction 0.015,
        op_inventory,
        op_probabilities = nothing,
        @cfield s num_to_keep 25,
        @cfield s num_to_generate 75,
        @cfield s p_take_better 0.65,
        @cfield s p_take_very_best 0.25,
        @cfield s max_generations 10,
        @cfield s stop_on_innovation false,
    )
end

function f(;kwargs...)
    print(kwargs)
end

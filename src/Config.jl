"""
    EpocSpec

Configuration for one evolution epoch
"""
@kwdef struct EpochSpec
    m_spec::MutationSpec
    s_spec::SelectionSpec
    max_generations::Int64
end

"""
    ExploreSimplifySearchSpec

Specifies a search process in which the exploration
`EvolutionSpec` is followed to form the initial population and to
run the bulk of the evolutionary search.  Then a simplification
`EvolutionSpec` is used if given.
"""
@kwdef struct ExploreSimplifySearchSpec
    genome_spec::GenomeSpec
    lambda_b::Float64
    lambda_p::Float64
    lambda_op::Float64
    num_islands::Int64
    stop_threshold::Union{Float64,Nothing}
    exploration_spec::EpochSpec
    simplification_spec::Union{EpochSpec,Nothing}
end


function parse_search_spec(s=Dict(), input_size=2)
    # Regularization parameters
    @cfield s op_inventory_spec "Polynomial"
    genome_spec_override = get(s, "genome", Dict())
    genome_spec = parse_genome_spec(genome_spec_override)
    op_inventory = get_or_build_op_inventory(op_inventory_spec)
    exploration_spec_override = get(s, "exploration", Dict())
    exploration_spec = parse_epoch_spec(exploration_spec_override)
    simplification_spec_override = get(s, "simplification", nothing)
    if isnothing(simplification_spec_override)
        simplification_spec = nothing
    else
        simplification_spec = parse_epoch_spec(simplification_spec_override)
    end
    ExploreSimplifySearchSpec(
        ;
        genome_spec,
        exploration_spec,
        simplification_spec,
        @cfield s lambda_b 1e-10
        ,
        @cfield s lambda_p 1e-10
        ,
        @cfield s lambda_op 1e-10
        ,
        @cfield s num_islands 1
        ,
        @cfield s stop_threshold nothing
        ,
    )
end




function parse_epoch_spec(s=Dict())
    # Pull mutation and selection paramters from the same dictionary.
    # I'm not putting in separate selection and mutation subsections.
    m_spec = parse_mutation_spec(s)
    s_spec = parse_selection_spec(s)
    @cfield s max_generations 10
    EpochSpec(; m_spec, s_spec, max_generations)
end

function parse_genome_spec(s=Dict(), input_size=2)
    @cfield s output_size 4
    @cfield s scratch_size 2
    @cfield s parameter_size 3
    @cfield s num_time_steps 4
    GenomeSpec(
        output_size,
        scratch_size,
        parameter_size,
        input_size,
        num_time_steps
    )
end

function get_or_build_op_inventory(op_inventory_spec="")::AbstractVector{<:AbstractMultiOp}
    op_subspecs = split_symbols(op_inventory_spec)
    if isempty(op_subspecs)
        return get_op_inventory().inventory
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

function parse_mutation_spec(s = Dict(), op_inventory=get_or_build_op_inventory())
    MutationSpec(
        ;
        op_inventory,
        @cfield s p_mutate_op 0.15
        ,
        @cfield s p_mutate_index 0.15
        ,
        @cfield s p_duplicate_index 0.015
        ,
        @cfield s p_delete_index 0.015
        ,
        @cfield s p_duplicate_instruction 0.003
        ,
        @cfield s p_delete_instruction 0.003
        ,
        @cfield s p_hop_instruction 0.015
    )
end

function parse_selection_spec(s=Dict())
    SelectionSpec(
        ;
        @cfield s num_to_keep 25
        ,
        @cfield s num_to_generate 75
        ,
        @cfield s p_take_better 0.65
        ,
        @cfield s p_take_very_best 0.25
    )
end


function f(;kwargs...)
    print(kwargs)
end

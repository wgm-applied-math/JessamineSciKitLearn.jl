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


function parse_search_spec(ps::AbstractDict, input_size::Int)
    @debug "parse_search_spec: prespec: $ps"
    op_inventory_actual = begin
        @cfield ps op_inventory "Polynomial"
        get_or_build_op_inventory(op_inventory)
    end
    @debug "parse_search_spec: op_inventory_actual: $op_inventory_actual"
    genome_spec = parse_genome_spec(ps, input_size)
    exploration_spec = parse_epoch_spec(op_inventory_actual, ps)
    simplification_spec = nothing
    simplify_flag = get_or_parse(ps, "simplify", false)
    if simplify_flag
        simplification_prespec = get_or_parse(
            ps, "simplification",
            Dict("p_duplicate_instruction" => 0.0, "p_duplicate_index" => 0.0))
        simplification_prespec = merge(ps, simplification_prespec)
        simplification_spec = parse_epoch_spec(op_inventory_actual, simplification_prespec)
    end
    return ExploreSimplifySearchSpec(
        ;
        genome_spec,
        exploration_spec,
        simplification_spec,
        @cfield ps lambda_b 1e-10
        ,
        @cfield ps lambda_p 1e-10
        ,
        @cfield ps lambda_op 1e-10
        ,
        @cfield ps num_islands 1
        ,
        @cfield ps stop_threshold nothing
        ,
    )
end


function parse_epoch_spec(op_inventory, ps::AbstractDict)
    # Pull mutation and selection paramters from the same dictionary.
    # I'm not putting in separate selection and mutation subsections.
    m_spec = parse_mutation_spec(op_inventory, ps)
    s_spec = parse_selection_spec(ps)
    @cfield ps max_generations 10
    EpochSpec(; m_spec, s_spec, max_generations)
end

function parse_genome_spec(ps::AbstractDict, input_size::Int)
    @debug "parse_genome_spec: input_size: $input_size"
    @debug "parse_genome_spec: ps: $ps"
    @cfield ps output_size 4
    @cfield ps scratch_size 2
    @cfield ps parameter_size 3
    @cfield ps num_time_steps 4
    genome_spec = GenomeSpec(
        output_size,
        scratch_size,
        parameter_size,
        input_size,
        num_time_steps
    )
    @debug "parse_genome_spec: g_spec: $genome_spec"
    return genome_spec
end

"""
    split_on_semicolons(s)

Split a string into substrings on semicolons, stripping out loose
whitespace.
"""
function split_on_semicolons(s)
    split(
        s,
        r"[[:space:]]*;[[:space:]]*",
        keepempty=false)
end

function get_or_build_op_inventory(op_inventory_spec="")::Union{Missing,AbstractVector{<:AbstractMultiOp}}
    op_subspecs = split_symbols(op_inventory_spec)
    if isempty(op_subspecs)
        return missing
    else
        if length(op_subspecs) == 1
            op_inventory_lookup = get_op_inventory(op_subspecs[1])
            if op_inventory_lookup.found
                return op_inventory_lookup.inventory
            end
        end
        op_inventory_build = build_op_inventory(op_subspecs)
        if !isempty(op_inventory_build.unknown)
            @warn "get_or_build_op_inventory: Unrecognized operation inventory spec: $(join(op_inventory_build.unknown))"
        end
        if isempty(op_inventory_build.inventory)
            @warn "get_or_build_op_inventory: No operations specified by spec: $op_inventory_spec"
            return missing
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

function parse_mutation_spec(op_inventory, ps::AbstractDict = Dict())
    @debug "parse_mutation_spec: ps: $ps"
    m_spec = MutationSpec(
        ;
        op_inventory,
        @cfield ps p_mutate_op 0.15
        ,
        @cfield ps p_mutate_index 0.15
        ,
        @cfield ps p_duplicate_index 0.015
        ,
        @cfield ps p_delete_index 0.015
        ,
        @cfield ps p_duplicate_instruction 0.003
        ,
        @cfield ps p_delete_instruction 0.003
        ,
        @cfield ps p_hop_instruction 0.015
    )
    @debug "parse_mutation_spec: m_spec: $m_spec"
    return m_spec
end

function parse_selection_spec(ps::AbstractDict = Dict())
    SelectionSpec(
        ;
        @cfield ps num_to_keep 25
        ,
        @cfield ps num_to_generate 75
        ,
        @cfield ps p_take_better 0.65
        ,
        @cfield ps p_take_very_best 0.25
    )
end

function explode(prespecs::AbstractArray, explodable_fields::AbstractVector)
    if isempty(explodable_fields)
        prespecs
    else
        explode_on = explodable_fields[begin]
        so_far = mapreduce(vcat, prespecs) do prespec
            explode(prespec, explode_on)
        end
        explode(so_far, explodable_fields[2:end])
    end
end

function explode(prespec::AbstractDict, explode_on::AbstractString)
    map(prespec[explode_on]) do v_exp
        exploded = Dict{String,Any}(explode_on => v_exp)
        for (k, v) in pairs(prespec)
            if k != explode_on
                exploded[k] = v
            end
        end
        exploded
    end
end

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


# Not sure this is needed:
function parse_evolution_spec(s, op_inventory, grow_and_rate)
    g_spec = parse_genome_spec(s)
    m_spec = parse_mutation_spec(s, op_inventory)
    s_spec = parse_selection_spec(s)
    @cfield s max_generations 10
    EvolutionSpec(g_spec, m_spec, s_spec, grow_and_rate,
                  max_generations)
end

"""
  The number of generations for
each of those phases is specified.  Islands are run
independently, up to `num_islands` at a time.  When one finishes,
another one is started.  When an agent with a new best rating is
found, it's sent to the `discoveries` channel.
The search continues until the deadline.
"""

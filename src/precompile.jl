function _precompile_()
  ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
  Base.precompile(run_simulation, (SimulationParameters,))
  Base.precompile(generate_patients, (MersenneTwister, Int64))
  Base.precompile(generate_numeric_vl, (SimulationParameters,Bool,Missing))
  Base.precompile(generate_categorical_vl, (SimulationParameters,Bool,Missing))
  Base.precompile(generate_messy_vl, (SimulationParameters,Bool,Missing))
end

_precompile_()

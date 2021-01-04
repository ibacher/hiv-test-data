function _precompile_()
  ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
  Base.precompile(run_simulation, (SimulationState, SimulationParameters))
  Base.precompile(generate_patients, (MersenneTwister, Int64))
end

_precompile_()

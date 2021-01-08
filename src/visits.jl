function generate_visits(state::SimulationState,
    params::SimulationParameters, patient_idxs)
  n_pats = length(patient_idxs)

  # these are are results
  visits = DataFrame([String, Date, Union{VL, Missing}], [:id, :date, :vl], n_pats)

  last_visit_dt = Vector{Date}(undef, n_pats)
  for i in 1:n_pats
    last_visit_dt[i] = state.current_date
  end

  state.patient_pool[patient_idxs, :last_visit_dt] = last_visit_dt
  state.patient_pool[patient_idxs, :due] = zeros(Bool, n_pats)

  j = 0
  @inbounds for i in patient_idxs
    j += 1

    if rand(params.rng) <= params.p_data_missing ||
        rand(params.rng) <= params.p_missed_appts
      visits[j, :id] = ""
      continue
    end

    if ismissing(state.patient_pool[i, :first_visit_dt])
      state.patient_pool[i, :first_visit_dt] = state.current_date
    end

    viral_load = generate_vl(state, params, state.patient_pool[i, :last_vl])

    visits[j, :id] = state.patient_pool[i, :id]
    visits[j, :date] = state.current_date
    visits[j, :vl] = viral_load

    state.patient_pool[j, :last_vl] = viral_load
  end

  filter!(r -> r.id != "", visits)
end

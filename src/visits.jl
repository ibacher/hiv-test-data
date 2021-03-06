function generate_visits(state::SimulationState,
    params::SimulationParameters, patient_idxs)
  n_pats = length(patient_idxs)

  # these are are results
  visits = DataFrame([String, Date, Time, Union{String, Missing}, Union{Int, String, Missing}], [:id, :date, :time, :vl_obs_code, :vl], n_pats)

  last_visit_dt = Vector{Date}(undef, n_pats)
  for i in 1:n_pats
    last_visit_dt[i] = state.current_date
  end

  state.patient_pool[patient_idxs, :last_visit_dt] = last_visit_dt
  state.patient_pool[patient_idxs, :due] = zeros(Bool, n_pats)

  j = 0
  @inbounds for i in patient_idxs
    j += 1

    if rand(params.rng) <= params.p_data_missing
      visits[j, :id] = ""
      continue
    end

    if ismissing(state.patient_pool[i, :first_visit_dt])
      state.patient_pool[i, :first_visit_dt] = state.current_date
    end

    viral_load = generate_vl(state, params, state.patient_pool[i, :last_vl])
    vl_tuple = vl_to_tuple(viral_load)

    visits[j, :id] = state.patient_pool[i, :id]
    visits[j, :date] = state.current_date
    visits[j, :time] = params.day_start + (
      (rand(params.rng, 0:state.visit_slots_per_day) *
      params.visit_length))
    visits[j, :vl_obs_code] = vl_tuple[1]
    visits[j, :vl] = vl_tuple[2]

    state.patient_pool[i, :last_vl] = viral_load
  end

  filter!(r -> r.id != "", visits)
end

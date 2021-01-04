function generate_visits(state::SimulationState,
    params::SimulationParameters, patients)
  n_pats = nrow(patients)

  # these are are results
  visits = DataFrame([String, Date, Union{VL, Missing}], [:id, :date, :vl], n_pats)

  last_visit_dt = Vector{Date}(undef, n_pats)
  for i in 1:n_pats
    last_visit_dt[i] = state.current_date
  end

  patients.last_visit_dt = last_visit_dt
  patients.due = zeros(Bool, n_pats)

  for (i, r) in enumerate(eachrow(patients))
    if rand(state.rng) <= params.p_data_missing
      continue
    end

    if ismissing(r.first_visit_dt)
      r.first_visit_dt = state.current_date
    end

    if ismissing(r.last_vl)

    end

    visits[i, :id] = row.id
    visits[i, :date] = state.current_date
    visits[i, :vl] = missing
  end
end

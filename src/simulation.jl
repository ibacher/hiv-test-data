"""
SimulationState

This represents the state tracked by the simulator.
"""
mutable struct SimulationState
  patient_pool::DataFrame
  visits::DataFrame
  current_date::Date
  visits_per_day::Normal{Float64}
  new_patients_per_day::Normal{Float64}
  ltfu_per_week::Normal{Float64}

  SimulationState() = new()
end

"""
SimulationParameters

This structure holds various parameters the control the simulation.
These parameters are defined at the start of the simulation and do
not change.
"""
struct SimulationParameters
  output_directory::AbstractString
  calendar::HolidayCalendar
  rng::AbstractRNG
  start_date::Date
  end_date::Date
  day_start::Time
  day_end::Time
  timezone::TimeZone
  starting_pool_size::Int
  pool_growth_rate::Float64
  p_m::Float64
  p_f::Float64
  age_wgt_m::Vector{Float64}
  age_wgt_f::Vector{Float64}
  m_visits_per_day::Float64
  sd_visits_per_day::Float64
  m_new_patients_per_day::Float64
  sd_new_patients_per_day::Float64
  m_ltfu_per_week::Float64
  sd_ltfu_per_week::Float64
  period_between_visits_non_suppressed::Period
  period_between_visits_suppressed::Period
  death_prob_natural::Vector{Float64}
  p_additional_death_prob::Float64
  p_data_missing::Float64
end

"""
  run_simulation(state, params)

This is the main entry point to start a simulation, passing in a 
"""
function run_simulation(params::SimulationParameters)
  println("Starting simulation...")

  # setup the initial state
  state = SimulationState()
  initialise_state(state, params)

  println("Starting on $(state.current_date)")

  while state.current_date < params.end_date
    simulation_tick(state, params)

    old_date = state.current_date
    state.current_date = advancebdays(params.calendar, state.current_date, 1)
    # run monthly updates on month change
    if month(old_date) != month(state.current_date)
      update_dead(state, params)
      write_monthly_visits(state, params, old_date)
    end

    # run weekly updates on week change
    if week(old_date) != week(state.current_date)
      update_due(state, params)
      update_ltfu(state, params)
    end
  end

  if nrow(state.visits) > 0
    write_monthly_visits(state, params, advancebdays(
      params.calendar, state.current_date, -1))
  end

  filter(r -> r.active, state.patient_pool, view=true)[:, [:id, :name, :surname, :sex, :birthdate, :death_date]] |>
    CSV.write(joinpath(params.output_directory, "patient_pool.csv"))

  nothing
end

@inline initialize_state(state::SimulationState, params::SimulationParameters) =
  initialise_state(state, params)

function initialise_state(state::SimulationState, params::SimulationParameters)
  BusinessDays.initcache(params.calendar)
  state.visits_per_day = Distributions.Normal(params.m_visits_per_day,
    params.sd_visits_per_day)
  state.new_patients_per_day = Distributions.Normal(
    params.m_new_patients_per_day, params.sd_new_patients_per_day)
  state.ltfu_per_week = Distributions.Normal(params.m_ltfu_per_week,
    params.sd_ltfu_per_week)
  
  # we start on the business day either on or immediately after the
  # selected start date
  state.current_date = advancebdays(params.calendar, params.start_date - Day(1), 1)

  state.patient_pool = add_new_patients(state, params)
  state.visits = DataFrame()
  
  output_directory = params.output_directory
  
  if !isdir(output_directory)
    mkpath(output_directory)
  end
end

function add_new_patients(state::SimulationState, params::SimulationParameters; n = missing)
  if (ismissing(n))
    n = n_pats = params.starting_pool_size
  else
    n_pats = max(
      round(Int, params.starting_pool_size * params.pool_growth_rate),
      n
    )
  end

  # we always try to generate at least one patient
  if n_pats < 1
    n_pats = 1
  end

  ids = if isdefined(state, :patient_pool)
    state.patient_pool.id
  else
    Set()
  end

  p = generate_patients(params.rng, n_pats, base_date=state.current_date)
  # since it's possible to generate duplicate ids, we need to drop
  # duplicated patient ids
  filter!(r -> r.id ∉ ids, p)

  # ensure we always generate at least `n` valid patients
  while nrow(p) < n
    p₁ = generate_patients(params.rng, n_pats, base_date=state.current_date)
    filter!(r -> r.id ∉ ids, p₁)
    append!(p, p₁)
  end

  # add the simulation tracking parameters to the generated patients
  p[!, :alive] = ones(Bool, n)
  p[!, :death_date] = Vector{Union{Date, Missing}}(missing, n)
  p[!, :active] = zeros(Bool, n)
  p[!, :ltfu] = zeros(Bool, n)
  p[!, :due] = zeros(Bool, n)
  p[!, :first_visit_dt] = Vector{Union{Date, Missing}}(missing, n)
  p[!, :last_visit_dt] = Vector{Union{Date, Missing}}(missing, n)
  p[!, :last_vl] = Vector{Union{VL, Missing}}(missing, n)

  return p
end

function simulation_tick(state::SimulationState, params::SimulationParameters)
  n_visits = round(Int, rand(params.rng, state.visits_per_day, 1)[1])

  due_patient_idxs = Int[]
  for (i, r) in enumerate(eachrow(state.patient_pool))
    if r.due
      push!(due_patient_idxs, i)
    end
  end

  n_due = length(due_patient_idxs)

  if n_due >= n_visits
    n_new_patients = round(Int, rand(params.rng, state.new_patients_per_day, 1)[1])
  else
    n_new_patients = n_visits - n_due
  end

  n_returning_visits = n_visits - n_new_patients

  returning_patient_idxs = sample(params.rng, due_patient_idxs,
    n_returning_visits, replace=false)

  state.patient_pool[returning_patient_idxs, :due] =
    zeros(Bool, n_returning_visits)

  visits = generate_visits(state, params, returning_patient_idxs)

  n_inactive_patients = nrow(
    filter(row -> !row.active, state.patient_pool, view=true))
  
  # if we need new patients, add them
  if n_inactive_patients < n_new_patients
    append!(state.patient_pool, add_new_patients(state, params,
      n = n_new_patients - n_inactive_patients))
  end

  # inactive_patients is now the pool of potential new patients
  inactive_patient_idxs = Int[]
  for (i, r) in enumerate(eachrow(state.patient_pool))
    if !r.active && r.alive && !r.ltfu
      push!(inactive_patient_idxs, i)
    end
  end
  
  if n_new_patients > 0
    # select random set of new patients
    new_patient_idxs = sample(params.rng, inactive_patient_idxs,
      n_new_patients, replace=false)
    
    state.patient_pool[new_patient_idxs, :active] =
      ones(Bool, n_new_patients)

    visits = vcat(visits, generate_visits(state, params, new_patient_idxs))
  end
    
  state.visits = vcat(state.visits, visits)
  
  nothing
end

function update_dead(state::SimulationState, params::SimulationParameters)
  living_people = filter(row -> !row.ltfu && row.alive, state.patient_pool,
    view=true)
  
  for row in eachrow(living_people)
    age_bin = (round(Int, (state.current_date - row.birthdate).value / 365.25) -
      15) ÷ 10 + 1
    
    if age_bin > length(params.death_prob_natural)
      age_bin = length(params.death_prob_natural)
    end
    
    death_prob = params.death_prob_natural[age_bin] + params.p_additional_death_prob
    
    row.alive = sample(params.rng, [true, false],
      ProbabilityWeights([1 - death_prob, death_prob]))

    # person died this tick, so calculate the death date
    if !row.alive
      last_appearance = row.last_visit_dt
      if ismissing(last_appearance)
        last_appearance = state.current_date - Month(1)
      end

      # death date is evenly distributed between current tick and the last time
      # they appeared in the simulation
      row.death_date = state.current_date - Day(rand(params.rng,
        0:(state.current_date - last_appearance).value))

      # dead patients are no longer due
      row.due = false
    end
  end

  nothing
end

function update_due(state::SimulationState, params::SimulationParameters)
  # we filter out patients who are already due as they will remain due until either
  # they are seen, they die, or they are lost to follow-up
  active_patients = filter(row -> row.active && row.alive && !row.ltfu && !row.due,
    state.patient_pool, view=true)

  # set the due flag for patients who should have an appointment
  # these are:
  #  * active patients not yet seen
  #  * patients whose last viral load indicated they were not suppressed and have not
  #    been seen in four weeks
  #  * 3 months from their last vl
  for row in eachrow(active_patients)
    if ismissing(row.last_visit_dt)
      row.due = true
    elseif !issuppressed(row.last_vl)
      if row.last_visit_dt >= state.current_date -
          params.period_between_visits_non_suppressed
        row.due = true
      end
    else
      if row.last_visit_dt >= state.current_date -
          params.period_between_visits_suppressed
        row.due = true
      end
    end
  end

  nothing
end

function update_ltfu(state::SimulationState, params::SimulationParameters)
  # patients are only lost to follow-up when they are due
  due_patients = filter(row -> row.due, state.patient_pool, view=true)

  n_ltfu = round(Int, rand(params.rng, state.ltfu_per_week, 1)[1])
  n_due = nrow(due_patients)

  # we cannot lose more patients than are due
  n_lost = min(n_ltfu, n_due)

  if n_lost < 1
    return nothing
  end

  ltfu_patients = view(due_patients, sample(params.rng, 1:nrow(due_patients), n_lost, replace=false), :)
  ltfu_patients[:, :ltfu] = ones(Bool, n_lost)
  ltfu_patients[:, :due] = zeros(Bool, n_lost)

  nothing
end

function write_monthly_visits(state::SimulationState, params::SimulationParameters, date::Date)
  CSV.write(joinpath(params.output_directory,
    "$(Dates.format(date, dateformat"yyyy-mm"))_visits.csv"),
    state.visits)

  println("Finished $(Dates.format(date, dateformat"u yyyy"))")
  state.visits = DataFrame()
end

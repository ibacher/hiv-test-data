abstract type VL end

"""
This is the most straight-forward viral load: a simple numeric
value represent copies of the virus per mL
"""
struct NumericVL <: VL
  val::Int

  function NumericVL(v::Int)
    if v < 20 || v > 10_000_000
      throw(DomainError("NumericVL value must be > 20 and < 10,000,000"))
    end

    new(v)
  end
end

"""
This is used to represent coded viral loads entered using the default
CIEL concepts
"""
struct CategoricalVL <: VL
  val::Int

  function CategoricalVL(v::Int)
    if v ∉ [1301, 1302, 1304, 1306]
      throw(DomainError(v,
        "not a valid CategoricalVL value; " *
        "must be one of 1301, 1302, 1304, or 1306"))
    end

    new(v)
  end
end

const MESSY_VALUES = (
  "< 100", "< 200", "< 300", "< 500", "< 1000")

"""
This is used to represent suppressed viral loads, but without a clear
numerical or coded value.
"""
struct MessyVL <: VL
  val::String
end

issuppressed(::Missing) = false
issuppressed(vl::NumericVL) = vl.val < 1000.0
issuppressed(vl::CategoricalVL) = vl.val == 1306 || vl.val == 1302
issuppressed(::MessyVL) = true

Base.show(io::IO, ::MIME"text/plain", vl::NumericVL) =
  print(io, "NumericVL $(vl.v)")
  Base.show(io::IO, ::MIME"text/plain", vl::CategoricalVL) =
  print(io, "CategoricalVL $(vl.v)")
Base.show(io::IO, ::MIME"text/plain", vl::MessyVL) =
  print(io, "MessyVL $(vl.val)")

function generate_vl(state::SimulationState, params::SimulationParameters,
  last_vl::Union{VL, Missing})
  
  suppressed = if issuppressed(last_vl)
    # let's assume suppression continues in 90% of cases
    rand(params.rng) <= .9
  elseif ismissing(last_vl)
    # almost all patients will start of with a high VL
    rand(params.rng) <= .01
  else
    # everyone is on ARV's so it should be likely to move into
    # the suppressed category
    rand(params.rng) <= .67  # from Gebrezgi et. al.
  end

  # based on whether or not the result will be suppressed, we generate
  # a viral load
  f = if suppressed
    p = rand(params.rng)
    
    if p <= .85
      generate_numeric_vl
    elseif p <= .95
      generate_categorical_vl
    else
      generate_messy_vl
    end
  else
    if rand(params.rng) <= .85
      generate_numeric_vl
    else
      generate_categorical_vl
    end
  end

  f(params, suppressed, last_vl)
end

function generate_numeric_vl(params::SimulationParameters,
    suppressed::Bool, last_vl)
  if suppressed
    NumericVL(rand(params.rng, 20:999))
  else
    generate_non_suppressed_numeric_vl(params, last_vl)
  end
end

function generate_non_suppressed_numeric_vl(params::SimulationParameters, last_vl::Missing)
  NumericVL(rand(params.rng, 50_000:9_999_999))
end

function generate_non_suppressed_numeric_vl(params::SimulationParameters, last_vl::NumericVL)
  min_val = max(1_000, round(Int, last_vl.val * .5))
  max_val = max(min_val + 5_000, min(round(Int, last_vl.val * 1.1), 9_999_999))

  NumericVL(rand(params.rng, min_val:max_val))
end

function generate_non_suppressed_numeric_vl(params::SimulationParameters, last_vl)
  NumericVL(rand(params.rng, 1_000:200_000))
end

function generate_categorical_vl(params::SimulationParameters,
    suppressed::Bool, last_vl)
  if suppressed
    if rand(params.rng) <= .75
      # Not detected
      CategoricalVL(1302)
    else
      # Beyond detectable limit
      CategoricalVL(1306)
    end
  else
    if rand(params.rng) <= .9
      # Detected
      CategoricalVL(1301)
    else
      # Poor sample
      CategoricalVL(1304)
    end
  end
end

function generate_messy_vl(params::SimulationParameters,
    suppressed::Bool, last_vl)
  MessyVL(rand(params.rng, MESSY_VALUES))
end

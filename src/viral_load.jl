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

issuppressed(::Missing) = false
issuppressed(vl::NumericVL) = vl.val < 1000.0
issuppressed(vl::CategoricalVL) = vl.val == 1306 || vl.val == 1302

vl_to_tuple(::Missing) = (missing, missing)
vl_to_tuple(vl::NumericVL) = ("856AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", vl.val)
vl_to_tuple(vl::CategoricalVL) = ("1305AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "$(vl.val)AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

function generate_vl(::SimulationState, params::SimulationParameters,
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
    
    if p <= .9
      generate_numeric_vl
    else
      generate_categorical_vl
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

function generate_non_suppressed_numeric_vl(params::SimulationParameters, ::Missing)
  NumericVL(rand(params.rng, 50_000:9_999_999))
end

function generate_non_suppressed_numeric_vl(params::SimulationParameters, last_vl::NumericVL)
  min_val = max(1_000, round(Int, last_vl.val * .5))
  max_val = max(min_val + 5_000, min(round(Int, last_vl.val * 1.1), 9_999_999))

  NumericVL(rand(params.rng, min_val:max_val))
end

function generate_non_suppressed_numeric_vl(params::SimulationParameters, ::Union{VL, Missing})
  NumericVL(rand(params.rng, 1_000:200_000))
end

function generate_categorical_vl(params::SimulationParameters,
    suppressed::Bool, ::Union{VL, Missing})
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

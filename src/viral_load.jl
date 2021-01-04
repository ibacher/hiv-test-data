abstract type VL end

"""
This is the most straight-forward viral load: a simple numeric
value represent copies of the virus per mL
"""
struct NumericVL <: VL
  val::Float64

  function NumericalVL(v::Float64)
    if v < 0
      throw(DomainError("NumericalVL value must be positive"))
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

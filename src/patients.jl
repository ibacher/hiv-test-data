const first_names = jldopen("data/babynames.jld2") do file
  read(file, "babynames")
end

const first_names_m = first_names[
  (first_names.sex .== "M") .& (first_names.year .== 2017), :]
const first_names_f = first_names[
  (first_names.sex .== "F") .& (first_names.year .== 2017), :]

const surnames = jldopen("data/surnames.jld2") do file
  read(file, "surnames")
end

"""
  generate_patients([rng], n; <keyword arguments>)

Creates a data frame of randomly generated patient records. Really,
these records have only 4 elements: a name, a surname, a sex and a
birthdate. The generated values depend on the supplied parameters.

# Arguments
- `rng::AbstractRNG`: a random number generator
- `n::Int`: the number of patients to represent
- `p_m=.505`: the rough percentage of male patients in the generated
  results
- `p_f=.495`: the rough percentage of female patients in the generated
  results
- `age_wgt_m=[.217, .214, .181, .16, .119, .072, .03, .007, .001]`:
  the relative weights that a male patient will belong to a given
  age bin (see below)
- `age_wgt_f=[.203, .204, .176, .159, .123, .081, .04, .013, .001]`:
  the relative weights that a male patient will belong to a given
  age bin (see below)
- `base_date=today()`: the date to calculate the birth date from

# Age Bins and Birth Dates
In order to create birth dates, this function first determines the age
for each patient. Age is assumed to be evenly distributed across
decade-sized bins, starting from age 15, so the first number in the
age_wgt vectors is the the probability weight that someone will be
between 15-24. The bins correspond to 15-24, 25-34, 35-44, 45-54,
55-64, 65-74, 75-84, 85-94 and 95+.

Once the age bin in is calculated, the patient will be assigned a
random age within that range and then a random birth date within the
corresponding year. This year is determined relative to the `base_date`
parameter.

See also: [`generate_names`](@ref), [`generate_surnames`](@ref),
[`generate_ages`](@ref), [`generate_birthdates`](@ref)
"""
@inline generate_patients(n::Int; p_m = .505, p_f = .495,
    age_wgt_m = [.217, .214, .181, .16, .119, .072, .03, .007, .001],
    age_wgt_f = [.203, .204, .176, .159, .123, .081, .04, .013, .001],
    base_date = today()) =
  generate_patients(Random.GLOBAL_RNG, n, p_m=p_m, p_f=p_f,
    age_wgt_m=age_wgt_m, age_wgt_f=age_wgt_f, base_date=base_date)

function generate_patients(rng::AbstractRNG, n::Int; p_m = .505, p_f = .495,
    age_wgt_m = [.217, .214, .181, .16, .119, .072, .03, .007, .001],
    age_wgt_f = [.203, .204, .176, .159, .123, .081, .04, .013, .001],
    base_date = today())
  # for efficiency's sake, it's easier to compute and sort this as a
  # boolean and then map to the string value
  # this list is sorted so that the sex-dependent values (name and age)
  # are properly aligned
  sexes = map(x -> x ? "F" : "M",
    sort(sample(rng, [true, false],
      ProbabilityWeights([p_m, p_f]), n)))

  n_males = count(s -> s == "M", sexes)
  n_females = n - n_males

  male_names = generate_names(rng, n_males, "M")
  female_names = generate_names(rng, n_females, "F")

  surnames = generate_surnames(rng, n)

  male_birthdates = generate_birthdates(rng,
    generate_ages(rng, n_males, age_wgt_m), base_date=base_date)
  female_birthdates = generate_birthdates(rng,
    generate_ages(rng, n_females, age_wgt_f), base_date=base_date)
  
  ids = generate_patient_ids(rng, n)

  patients = DataFrame(
    id = ids,
    name = vcat(male_names, female_names),
    surname = surnames,
    sex = sexes,
    birthdate = vcat(male_birthdates, female_birthdates)
  )
end

"""
  generate_names([rng], n, sex)

Generates n random first names from the babynames data set supplied
with this package

# Arguments
- `rng::AbstractRNG`: a random number generator
- `n::Int`: the number of names to generate
- `sex::String`: the sex of the names to generate; either "M" or "F"
"""
@inline generate_names(n::Int, sex::String) = generate_names(Random.GLOBAL_RNG, n, sex)

function generate_names(rng::AbstractRNG, n::Int, sex::String)
  if sex == "M"
    _names = first_names_m
  elseif sex == "F"
    _names = first_names_f
  else
    throw(DomainError(sex, "is not one of either 'M' or 'F'"))
  end

  sample(rng, _names.name, ProbabilityWeights(_names.prop), n)
end

"""
  generate_surnames([rng], n)

Generates n random surnames from the surnames data set supplied with
this package

# Arguments
- `rng::AbstractRNG`: a random number generator
- `n::Int`: the number of surnames to generate
"""
@inline generate_surnames(n::Int) = generate_surnames(Random.GLOBAL_RNG, n)

@inline generate_surnames(rng::AbstractRNG, n::Int) =
  sample(rng, surnames.name, ProbabilityWeights(surnames.prop), n)

"""
  generate_ages([rng], n, age_wgt)

Generates ages for patients based on the supplied age weights

# Arguments
- `rng::AbstractRNG`: a random number generator
- `n::Int`: the number of ages to generate
- `age_weight::Vector{Float64}`: the relative weights that an age will
be in a particular age bin

See also: [`generate_patients`](@ref)
"""
@inline generate_ages(n::Int, age_wgt::Vector{Float64}) =
  generate_ages(Random.GLOBAL_RNG, n, age_wgt)

@inline generate_ages(rng::AbstractRNG, n::Int, age_wgt::Vector{Float64}) =
  sample(rng, collect(15:10:95), ProbabilityWeights(age_wgt), n) +
    rand(rng, 0:9, n)

"""
  generate_birthdates([rng], ages; base_date=today())

Generates corresponding birth dates for a vector of ages and a base
date

# Arguments
- `rng::AbstractRNG`: a random number generator
- `ages::AbstractVector{Int}`: a vector of ages
- `base_date=tody()`: the base date to calculate birth days from
"""
@inline generate_birthdates(ages; base_date = today()) = 
  generate_birthdates(Random.GLOBAL_RNG, ages, base_date=base_date)

function generate_birthdates(rng::AbstractRNG, ages;
    base_date = today())
  birthdates = Vector{Date}(undef, length(ages))
  for (i, age) in enumerate(ages)
    starting_date = base_date - Dates.Year(age)
    date_shift = rand(rng,
      0:Dates.value(starting_date - (starting_date - Dates.Year(1) + Dates.Day(1))))
    @inbounds birthdates[i] = starting_date - Dates.Day(date_shift)
  end

  birthdates
end

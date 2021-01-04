@inline generate_patient_ids(n::Int;
  base_charset = "0123456789ACDEFGHJKLMNPRTUVWXY",
  id_length = 6, min_val = 837931, max_val = 24299999) =
  generate_patient_ids(Random.GLOBAL_RNG, n; base_charset, id_length,
    min_val, max_val)

"""
  generate_patient_ids([rng], n; <keyword arguments>)

Creates n patient ids conforming to the Luhn ModN system used by the
idgen module.

# Arguments
- `rng::AbstractRNG`: a random number generator
- `n::Int`: the number of patient ids to generate
- `base_charset`: the base character set for identifier generation
- `id_length::Int`: the minimum length of an id
- `min_value::Int`: the minimum value to select ids from
- `max_value::Int`: the maximum value to select ids from

# Luhn ModN / Mod30
The default arguments for this function correspond to the default
settings for OpenMRS IDs, that is, 6 characters drawn from a 30-
character alphabet.

Internally, OpenMRS uses the Luhn ModN algorithm to convert between
a character string and an integer representation (in the default 
implementation, the integer representation is generated from a sequence
stored in the database). The `min_value` and `max_value` parameters to
this function essentially correspond to the valid ranges for this
integer value (corresponding to the id bases "10000" through "YYYYY";
the sixth character is always the Luhn check digit). Note that unlike
in the idgen module, all ids generated here are randomly selected over
the defined range and not allocated sequentially. This allows us to
not have to track allocations globally or deal with synchronisation
issues. This does, however, mean that multiple calls to this function
can generate the same id multiple times (in any individual call, the
set of ids will be unique as we sample numbers from the range without
replacement).

It is, therefore, recommended to try to generate as many patient ids
up-front as possible.

If you need more that 23 million ids, you will obviously need to tweak
these parameters. Also note that although the Luhn ModN algorithm
supports arbitrary character sets, OpenMRS is limited to those
hard-coded into the provided validators, so it is *not* recommended to
adjust the `base_charset` unless you are sure of what you are doing.
"""
function generate_patient_ids(rng::AbstractRNG, n::Int;
  base_charset = "0123456789ACDEFGHJKLMNPRTUVWXY",
  id_length = 6, min_val = 837_931, max_val = 24_299_999)

  @assert length(base_charset) >= 1
 
  generated_ids = sample(rng, min_val:max_val, n, replace = false)
 
  ids = Vector{String}(undef, n)
  for (i, id_num) in enumerate(generated_ids)
    id = convert_to_base(id_num, base_charset)

    if length(id) < id_length - 1
      @inbounds id *=
        repeat(base_charset[1], (id_length - 1 - length(id)))
    end

    @inbounds ids[i] = id * compute_check_digit(id, base_charset)
  end
 
  ids
end

function convert_to_base(i::Int, base_charset)
  n = length(base_charset)

  len = round(Int, log(n, i))
  result = Vector{Char}(undef, len)
  for idx in len:-1:1
    @inbounds result[idx] = base_charset[i % n + 1]
    i = i ÷ n
  end
  
  join(result)
end

function compute_check_digit(id, base_charset)
  n = length(base_charset)
  id_code_points = [findfirst(isequal(c), base_charset) for c in id]

  checksum = sum(((i % 2 != 0 ? 2 : 1) * cp
    for (i, cp) in enumerate(Iterators.reverse(id_code_points))))
 
  @inbounds base_charset[(n - (checksum % n)) % n + 1]
end

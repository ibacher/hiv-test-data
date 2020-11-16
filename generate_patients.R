library(tidyverse)
library(lubridate)
# Hadley Wickham's babynames package, based on US SSA data.
library(babynames)
# Used solely for surnames
library(randomNames)

data("randomNamesData")

# convert surname data to tibble
surnames <- as_tibble(randomNamesData$last_names_e5, rownames = "name") %>%
  rename(prop = value)


#' Generate random patients using some parameters
#' 
#' Note that names are derived from US SSA and Census data, which severly limits
#' the diversity of possible names
#' 
#' sex_wgt: defines the relative weight between male and females in the population
#' the default value reflects the WHO base line of 105 male births per 100 female
#' births (http://origin.searo.who.int/entity/health_situation_trends/data/chi/sex-ratio/en/)
#' 
#' 
#' age_wgt_m: defines the relative weight of ages for males
#' 
#' age_wgt_f: defines the relative weight of ages for females
#' 
#' age_wgt structures run from children (< 15 years) and from there in 10 year
#' distributions (15-24, 25-34, 35-44, 45-54, 55-64, 65-74, 75-84, 85-94, 95+)
#' the default distributions are calculated from the 2019 data from https://www.populationpyramid.net/
#' which are in turn based on these sources https://www.populationpyramid.net/sources
#' 
#' base_date: determines the date used as a baseline to determine actual birthdates
#' 
#' names_yr: must be one of the year values in the babynames tibble; it defaults
#' to the most recent year, but in theory should work for any year from 1880 - 2017
gen_pats <- function(n, sex_wgt = c(0.505, 0.495),
                     age_wgt_m = c(0, 0.217, 0.214, 0.181, 0.16, 0.119, 0.072, 0.03, 0.007, 0.001),
                     age_wgt_f = c(0, 0.203, 0.204, 0.176, 0.159, 0.123, 0.081, 0.04, 0.013, 0.001),
                     base_date = today(), names_yr = as.integer(
                       babynames %>% slice_tail %>% select(year))) {
  sampled_sexes <- as_tibble(
    sample(c("M", "F"), size = n, replace = TRUE, prob = sex_wgt)) %>%
    rename(sex = value)
  
  n_sampled_males <- as.integer(sampled_sexes %>% filter(sex == "M") %>% count)
  n_sampled_females <- as.integer(sampled_sexes %>% filter(sex == "F") %>% count)
  
  sampled_male_names <- babynames %>%
    filter(year == names_yr & sex == "M") %>%
    sample_n(n_sampled_males, replace = TRUE, weight = prop) %>%
    select(name)
  
  sampled_male_ages <- gen_ages(n_sampled_males, age_wgt_m) %>%
    gen_birthdates(base_date)
  
  sampled_female_names <- babynames %>%
    filter(year == names_yr & sex == "F") %>%
    sample_n(n_sampled_females, replace = TRUE, weight = prop) %>%
    select(name)
  
  sampled_female_ages <- gen_ages(n_sampled_females, age_wgt_f) %>%
    gen_birthdates(base_date)
  
  sampled_surnames <- surnames %>%
    sample_n(n, replace = TRUE, weight = prop) %>%
    select(name)
  
  sampled_patient_ids <- as_tibble(gen_pat_ids(n)) %>%
    rename(id = value)
  
  samples <- bind_cols(sampled_sexes, sampled_surnames, sampled_patient_ids) %>%
    rename(surname = name)
  
  bind_rows(
    bind_cols(samples %>% filter(sex == "F"), sampled_female_names, sampled_female_ages),
    bind_cols(samples %>% filter(sex == "M"), sampled_male_names, sampled_male_ages)
  ) %>%
    select(id, name, surname, sex, birth_date) %>%
    sample_n(nrow(.))
}

gen_ages <- function(n, age_wgts) {
  as_tibble(
    sample(c(0, 15, 25, 35, 45, 55, 65, 75, 85, 95), n, replace = TRUE, prob = age_wgts) +
      trunc(runif(n, min = 0, max = 9))) %>%
    rename(age = value)
}

gen_birthdates <- function(ages, base_date = today()) {
  ages %>%
    mutate(base_date = base_date - years(age)) %>%
    rowwise() %>%
    mutate(date_shift = sample.int(as.integer(base_date) - as.integer(base_date - years(1)), size = 1)) %>%
    ungroup() %>%
    mutate(birth_date = base_date - date_shift) %>%
    select(-c(base_date, date_shift))
}

#' Generate patient identifiers following the Luhn ModN algorithm used by default
#' in OpenMRS
#' 
#' I don't really know how this will interact with the OpenMRS identifier system,
#' but the aim here is to at least replicate valid OpenMRS IDs
#' 
#' Note that the default sample range min and max values are defined by the
#' numeric representations of "00000" and "YYYYY"; in other words, it should be
#' the set of all five-character identifiers which, with the check digit, means
#' we should always generate a six-character id
gen_pat_ids <- function(n, base_charset = "0123456789ACDEFGHJKLMNPRTUVWXY",
                        sample_range_min = 837926, sample_range_max = 25137925) {
    base_charset <- explode_chr(base_charset)
    
    ids_enc <- sample((sample_range_max - sample_range_min), n) %>%
      map_dbl(~ .x + sample_range_min)
    
    ids_enc %>%
      map_chr(~ convert_to_base(.x, base_charset)) %>%
      map_chr(~ paste0(.x, compute_check_digit(.x, base_charset)))
}

# converts a number to a string representation for a given alphabet
convert_from_base <- function(s, base_charset) {
  n <- length(base_charset)
  v_s <- str_split(s, "")[[1]]
  
  sum(imap_dbl(v_s, ~ ((which(base_charset == .x)) * n ^ (.y - 1)) - 1))
}

# converts a string representation to a numeric representation for a given alphabet
convert_to_base <- function(i, base_charset) {
  n <- length(base_charset)
  v_char <- c()
  
  while (i > 0) {
    v_char <- c(v_char, base_charset[(i %% n) + 1])
    i <- i %/% n
  }
  
  paste0(v_char, collapse = "")
}

# computes the Luhn ModN check digit for a given string representation and alphabet
compute_check_digit <- function(id, base_charset) {
  n <- length(base_charset)
  v_id <- str_split(id, "")[[1]]
  v_id_cp <- map_int(v_id, ~ which(base_charset == .))
  
  base_charset[sum(imap_dbl(rev(v_id_cp), ~ .x * ifelse(.y %% 2 == 0, 2, 1))) %% n]
}

explode_chr <- function(s) {
  str_split(s, "")[[1]]
}

library(tidyverse)
library(lubridate)
# business days
library(bizdays)
library(here)

source(here("generate_patients.R"))
source(here("generate_visits.R"))
source(here("generate_VLs.R"))

# our simulation calendar: just assume every day Monday - Friday is a workday
calendar <- create.calendar('SimCalendar', weekdays = c('saturday', 'sunday'))
bizdays.options$set(default.calendar='SimCalendar')

#' This list holds the parameters for the simulation and is used to track the
#' current state. For the purposes of the simulation, we only need to keep in
#' memory the last VL result and the last visit date. All other data should be
#' immediately written to files and discarded.
#' 
#' Parameters:
#' `start_date`: This is the start date of the simulation
#' `end_date`: This is the end date of the simulation
#' `current_month`: This is a simulation state tracking variable and should be
#'   `NULL`
#' `starting_pool_size`: The initial number of patients to generate for the
#'   simulation. Patients will be added to the simulation as required, but it's
#'   simpler to do as much of the generation up-front as possible. However, I
#'   really don't recommend generating more than 100,000 patients at a time.
#' `pool_growth_rate`: This is the rate (in terms of the `starting_pool_size`)
#'   at which new patients are generated. The default value of `.1` means that
#'   the pool grows by up to 10% of the `starting_pool_size` every time we run
#'   out of patients. Note that because it's possible for patients with the same
#'   ID to be generated in separate batches, the actual number of patients
#'   generated at any step might be less than the suggested number here.
#' `patient_pool`: This is the main simulation state tracking variable and
#'   should be `NULL`
#' `pct_m`: This determines the rough percentage of generated patients who are
#'   male. The numbers for this and `pct_f` reflect the WHO baseline assumption
#'   of 105 male births per 100 female births. See
#'   http://origin.searo.who.int/entity/health_situation_trends/data/chi/sex-ratio/en/
#' `pct_f`: This determines the rough percentage of generated patients who are
#'   female.
#' `age_wgt_m`: This provides weightings for different age ranges to determine
#'   the rough percentage of generated male patients that will be in each age
#'   range.
#'   
#'   The values are a little weird by correspond to the age ranges 0-14, 15-24,
#'   25-34, 35-44, 45-54, 55-64, 65-74, 75-84, 85-94, and 95+. Note that
#'   currently ages under 15 aren't properly supported, so the initial value
#'   should always be 0.
#'   
#'   The default weights are calculated from the Population Pyramid numbers for
#'   2019, which can be found here: https://www.populationpyramid.net/ and are
#'   based on the sources reported here: https://www.populationpyramid.net/sources
#' `age_wgt_f`: This provides weightings for different age ranges to determine
#'   the rough percentage of generated female patients that will be in each age
#'   range.
#' `m_visits_per_day`: This is the mean number of visits per day to generate.
#'   Actual daily visits are generated randomly by assuming that visit counts are
#'   distributed normally. The default figure is derived from AMPATH's supplied data. 
#' `sd_visits_per_day`: This is the standard deviation of the number of visit
#'   per day, which is used to calculate the normal distribution described above.
#'   The default value is likewise derived from AMPATH's data.
#' `m_new_patients_per_day`: This is the mean number of new patients seen each
#'   day. Note that in the initial 4 months of the simulation, this factor will
#'   be largely ignored, since the majority of patients should be new patients.
#'   After the initial 4-month ramp-up period, this will determine the number
#'   of new patient's added to the register every day. Again, we assume that the
#'   number of daily new patients will approximate the normal distribution. The
#'   default value for this parameter is derived from AMPATH's data.
#' `sd_new_patients_per_day`: This is the standard deviation of the number of
#'   new patients per day, which is used to calculate the normal distribution
#'   described above. The default value is likewise derived from AMPATH's data.
#' `death_prob_natural`: This is the chance a patient has of dying every year
#'   from non-HIV related causes based on their age range. The default values are
#'   calculated from the CDC NVSS for 2016.
simulation_parameters <- new.env(parent = baseenv())
simulation_parameters$start_date <- ymd("2015-01-01")
simulation_parameters$end_date <- ymd("2015-03-01")
simulation_parameters$starting_pool_size <- 2000
simulation_parameters$pool_growth_rate <- .1
simulation_parameters$pct_m <- .505
simulation_parameters$pct_f <- .495
simulation_parameters$age_wgt_m <- c(0, .217, .214, .181, .16, .119, .072, .03, .007, .001)
simulation_parameters$age_wgt_f <- c(0, .203, .204, .176, .159, .123, .081, .04, .013, .001)
simulation_parameters$m_visits_per_day <- 1433.5
simulation_parameters$sd_visits_per_day <- 240.5
simulation_parameters$m_new_patients_per_day <- 25.6
simulation_parameters$sd_new_patients_per_day <- 6.7
simulation_parameters$death_prob_natural <- c(0, .00075, .00128, .0019, .00401, .00879, .01786, .04473, .13392, .13392)
simulation_parameters$current_month <- NULL
simulation_parameters$patient_pool <- NULL

#' This is the main simulator function that takes the parameters and runs the
#' simulation. The simulation period is generally monthly, but certain factors
#' may cause patients to have visits more frequently.
run_sim <- function(sim_params) {
  sim_params$patient_pool <- add_new_patients(sim_params)
  sim_params$current_month <- sim_params$start_date
  sim_params$death_prob_natural_by_month <- sim_params$death_prob_natural / 12
  
  while (sim_params$current_month < sim_params$end_date) {
    run_sim_month(sim_params$current_month, sim_params,
                  m_visits_per_day = sim_params$m_visits_per_day,
                  sd_visits_per_day = sim_params$sd_visits_per_day,
                  m_new_patients = sim_params$m_new_patients_per_day,
                  sd_new_patients = sim_params$sd_new_patients_per_day)
    
    # here, we try to pre-generate patients if we are likely to need them
    # this basically tries to ensure that the patient pool is larger than the
    # likely number of patients that will be generated that month.
    if (nrow(sim_params$patient_pool %>% filter(alive & !active)) <
        (sim_params$m_new_patients_per_day * 31 + sim_params$sd_new_patients_per_day * 5)) {
      add_new_patients(sim_params)
    }
    
    sim_params$current_month <-
      floor_date(sim_params$current_month, unit = "month") + months(1)
  }
  
  View(sim_params$patient_pool)
}

#' adds up to `n` new patients to the simulation
#' 
#' if `n` is set to `NA`, we will determine `n` from the simulation parameters,
#' specifically the `starting_pool_size` and `pool_growth_rate` parameters
add_new_patients <- function(sim_params, n = NA) {
  # some logic for determining the default value of n
  if (is.na(n)) {
    # if we don't have a pool, n is the default pool size
    if (is.null(sim_params$patient_pool)) {
      n <- sim_params$starting_pool_size
      # otherwise, add the number of patients specified by the growth rate
      # note that the actually added number of patients will likely be less than
      # this as we don't include any duplicate identifiers
    } else {
      n <- round(sim_params$starting_pool_size * sim_params$pool_growth_rate)
    }
    
    patients <- gen_pats(n,
                         sex_wgt = c(sim_params$pct_m, sim_params$pct_f),
                         age_wgt_m = sim_params$age_wgt_m,
                         age_wgt_f = sim_params$age_wgt_f,
                         base_date = sim_params$start_date) %>%
      # add simulation tracking elements
      mutate(
        alive = TRUE,
        death_date = as.Date(NA),
        active = FALSE,
        ltfu = FALSE,
        due = FALSE,
        last_visit_dt = as.Date(NA),
        last_vl = MissingVL(),
        last_vl_dt = as.Date(NA))
    
    if (is.null(sim_params$patient_pool)) {
      sim_params$patient_pool <- patients
    } else {
      sim_params$patient_pool <- bind_rows(
        sim_params$patient_pool,
        anti_join(patients, sim_params$patient_pool, by = "id")
      )
    }
  }
}

#' Generates visits for a month from a tibble of patients
#' 
#' `month` should be an R date indicating the month and year being simulated
#' 
#' `m_visits_per_day` is the mean number of visits per day
#' `sd_visits_per_day` is the standard deviation of visits per day
#' 
#' These parameters are used to determine the number of visits per day, based
#' on the normal distribution.
#' 
#' `m_new_patients` is the mean number of new patients per day
#' `sd_new_patients` is the standard deviation of new patients per day
#' 
#' These parameters normally determine the number of new patients per day;
#' however, early in the simulation, all patients will be effectively
#' "new patients". These factors are thus mostly disregarded in the first month
#' of a simulation.
#' 
#' The defaults for these factors are calculated on the basis of data supplied
#' by AMPATH.
run_sim_month <- function(month, sim_params,
                          m_visits_per_day = 1433.5, sd_visits_per_day = 240.5,
                          m_new_patients = 25.6, sd_new_patients = 6.7) {
  start_of_month <- floor_date(month, unit = "month")
  end_of_month <- month + months(1) - days(1)
  
  if (start_of_month < sim_params$start_date) {
    start_of_month <- sim_params$start_date
  }
  
  if (end_of_month > sim_params$end_date) {
    end_of_month <- sim_params$end_date
  }
  
  n <- bizdays(start_of_month, end_of_month)
  dates <- bizseq(start_of_month, end_of_month)
  
  n_visits <- round(rnorm(n, mean = m_visits_per_day, sd = sd_visits_per_day))
  total_visits <- sum(n_visits)
  
  # remove anyone who dies from the simulation
  calculate_deaths(sim_params, start_of_month, end_of_month)
  
  # figure out which patient's are due for a recurring visit
  update_due(sim_params, start_of_month, end_of_month)
  
  n_due <- nrow(sim_params$patient_pool %>% filter(due))
  
  if (n_due > total_visits) {
    n_new_patients <- round(rnorm(1, mean = m_new_patients, sd = sd_new_patients))
  } else {
    n_new_patients <- total_visits - n_due
  }
  
  n_recurring_visits <- total_visits - n_new_patients

  recurring_patients <- sim_params$patient_pool %>%
    filter(due) %>%
    slice_sample(n = n_recurring_visits) 
  
  # if we need more new patients, add them in
  if(nrow(sim_params$patient_pool %>% filter(alive & !active))
        < n_new_patients) {
    add_new_patients(sim_params, n_new_patients)
  }
  
  new_patients <- sim_params$patient_pool %>%
    filter(alive & !active) %>%
    slice_sample(n = n_new_patients)
  
  updated_patients <- bind_rows(
    recurring_patients,
    new_patients
  ) %>%
    mutate(active = TRUE)
  
  updated_patients <- gen_visits(updated_patients, bind_cols(dates, n_visits))
  
  sim_params$patient_pool <- bind_rows(
    updated_patients,
    anti_join(sim_params$patient_pool, updated_patients, by = "id")
  )
}

calculate_deaths <- function(sim_params, start_of_month, end_of_month) {
  sim_params$patient_pool <- sim_params$patient_pool %>%
    # calculate which age group bin the patient will fall into
    mutate(age_bin = (as.integer(round((end_of_month - birth_date) / 365.25)) - 15) %/% 10 + 1) %>%
    rowwise() %>%
    # update dead patients to be not alive, but dead patients should remain dead
    # NO ZOMBIES!
    mutate(alive = ifelse(!alive, FALSE, sample(c(TRUE, FALSE), 1, prob = c(
      1 - sim_params$death_prob_natural_by_month[age_bin],
      sim_params$death_prob_natural_by_month[age_bin])))) %>%
    select(-(age_bin)) %>%
    # if someone died and we don't have a death date for them
    # since we assume no one dies in clinic, deaths either occur between the
    # last visit date or, if they have not had a visit, the start of the month
    mutate(death_date = if_else(
      !alive & is.na(death_date),
      ymd(
        end_of_month -
          sample.int(end_of_month - if_else(!is.na(last_visit_dt),
                                            last_visit_dt, start_of_month),
                     size = 1))
      , death_date)) %>%
    ungroup()
}

#' updates the `due` flag to indicate patients who are due for an appointment
#' patients who are `due` for an appointment form the group that may either be
#' seen in clinic in a given month or lost to follow-up
#' 
#' due for appointment is defined as either not having been seen in 4 months or
#' the immediate preceding VL test indicating that the patient was not suppressed
#' and at least two weeks will have passed
update_due <- function(sim_params, start_of_month, end_of_month) {
  sim_params$patient_pool <- sim_params$patient_pool %>%
    # dead patients and patients LTFU are not due
    mutate(due = alive & !ltfu & (
      # if they were due before, they're due again
      due |
        (active &
           (is.na(last_vl) | 
              (!is.suppressed(last_vl) &
                 (is.na(last_visit_dt) | last_visit_dt < (end_of_month - weeks(2)))) |
              (is.suppressed(last_vl) &
                 is.na(last_visit_dt) | last_visit_dt < (start_of_month - months(3)))))))
}

run_sim(simulation_parameters)

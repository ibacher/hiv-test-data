# HIV Test Data

This is intended to be a relatively straight-forward simulator for generating a range of data for a large population of patients. It's written in Julia primarily for reasons of execution speed (an older version, written in R could only handle data sets up to about 10,000 patients).

An example usage of the simulation engine can be found in the [run_simulation.jl](run_simulation.jl) file. As that sample should indicate, usage of this package is quite straight-forward, only relying on a single method call. There are, however, a large number of parameters that affect the course of the simulation that need to be defined.

The simulation outputs two kinds of files:

1. A file called "patient_pool.csv" which has all the demographic data for generated for patients.
1. A number of files listing "visits" and resulting VL for the visit ("visit files")

## Patient File

The patient file consists of a long list of patients who appeared for at least one appointment in the simulation. 

It has the following columns:

```csv
id,name,surname,sex,birthdate,death_date
```

Where `id` is a (hopefully) valid OpenMRS Identifier, `name` is the patient's given name, `surname` is the patient's surname, `sex` is either "M" or "F", `birthdate` represents the patients birthdate (this is used for some properties of the patient), and `death_date` is the day that the patient died, if the patient died in the course of the simulation.

## Visit Files

Visit files are written out every time the month changes, so the defined the number of visits per month. This is done so that we're not actually storing potentially millions of observations in memory at any one time.

These files have the following schema:

```csv
id,date,vl
```

Where `id` matches the id of a patient in the patient file, `date` is the date of the visit and `vl` is the VL recorded at that visit, albeit currently in a weird format (that will be fixed soon).

## Running the Simulation

If you've checked out this package and installed a suitable version of Julia (should work on Julia 1.3+, but really only tested on Julia 1.5), you should be able to download the required dependencies by running

```
julia --project=@. -e 'using Pkg;Pkg.instantiate()'
```

You can then run the sample simulation by running:

```
julia --project=@. run_simulation.jl
```

## Simulation Parameters

The simulation has a large number of definable parameters that can be used to control various aspects of it. This is an attempt to document those parameters and how they are derived.


Parameter|Meaning
-----|-----
`output_directory`|The directory in which to save the output
`calendar`|A Business Day calendar as defined by the [BusinessDays.jl](https://juliafinance.github.io/BusinessDays.jl/stable/) package. This is used to compute working days in the simulation.
`rng`|Any Julia `AbstractRNG`. This is used to provide randomness for the entire simulation. It is possible to chose whether to use a stable RNG, a secure RNG, or just the default Julia RNG (which is stable for versions of Julia).
`start_date`|The date the simulation starts. Note that the first actual visits will be on the first business day on or after the `start_date` (so if the start date is defined as a holiday in your calendar, the date of first visits will be the next business day after the `start_date`).
`end_date`|The date that the simulation ends. No visits will occur after this date.
`day_start`|Represents the start of the business day. Used to generate the time of the visit.
`day_end`|Represents the end of the business day. Used to generate the time of the visit.
`timezone`|The timezone to output datetimes in. This is largely ornamental.
`starting_pool_size`|The number of initial patients to generate. It is recommended to try and generate more patients than you will actually need upfront, as the initial generation of patients is somewhat faster than generating patients during the simulation. Nevertheless, new patients are generated as-required.
`pool_growth_rate`|This determines the size by which the patient pool is grown every time new patients need to be added. It is expressed as a percentage of the starting pool size. For instance, `.1` means that 10% of the `starting_pool_size` patients will be generated every time new patients are required.
`p_m`|This controls the (rough) percentage of patients who are assigned male sex. Note that `p_m` and `p_f` should add up to 1.
`p_f`|This controls the (rough) percentage of patients who are assigned female sex. Note that `p_m` and `p_f` should add up to 1.
`age_wgt_m`|For male patients, this determines which age bin they are initially assigned to. See the documentation on age bins below.
`age_wgt_f`|For female patients, this determines which age bin they are initially assigned to. See the documentation on age bins below.
`m_visits_per_day`|This is the mean number of visits per day. While this is expressed as a float, there will only ever be a whole number of visits for any given day.
`sd_visits_per_day`|This is the standard deviation of visits per day.
`m_new_patients_per_day`|This is the mean number of new patients seen every day. While this is expressed as a float, there will only ever be a whole number of new visits for any day. Note that at the initial stages of the simulation (when there is no existing patient base), almost all visits will be new visits. This parameter becomes more important after several simulated months.
`sd_new_patients_per_day`|This is the standard deviation of new patients per day.
`m_ltfu_per_week`|This is the mean number of patients lost to follow-up every week. Note that while this is expressed as a float, there will only ever be a whole number of patients lost to follow-up per week. As the name indicates, patients lost to follow-up is only calculated once-per-week.
`sd_ltfu_per_week`|This is the standard deviation of patients lost to follow-up per week.
`period_between_visits_non_suppressed`|This controls how soon a patient with a non-suppressed viral load will have a new visit to take their viral load. Note that this simply controls when the patient will become available for a new visit. The simulation does not guarantee that the patient will turn up after exactly this period or even at all.
`period_between_visits_suppressed`|This controls how soon a patient with a suppressed viral load will have a new visit to take their viral load. Note that this simply controls when the patient will become available for a new visit. The simulation does not guarantee that the patient will turn up after exactly this period or even at all.
`death_prob_natural`|This is the probability of death occurring for a given patient in by the age bin they are in. See the documenation on age bins below. This is termed "natural" as there is a single correction factor applied to take into account the slightly higher chance of death in the simulation population, since the simulated population is assumed to be HIV positive.
`p_additional_death_prob`|This is a correction factor used to express the higher chance of death among the population. It can be set to 0 to note use this correction. It should not be higher than 1. Note that a value of 1 will mean that *every* patient dies every time deaths are calculated, so this should probably be much closer to 0.
`p_data_missing`|This controls the percentage of patients who show up for an appointment and are regarded by the simulation as having appeared, but whose data is not recorded. This is intended to add "missing data" for visits that actually occurred but were not recorded in the system.

### Age Bins
Data to do with patient age (i.e., initial age at the point a patient is added to the simulation, the risk of death given the patients current age) are supplied via vectors of percentages corresponding to different "bins" of ages. The age bins used by this simulation are broken down by decades starting at age 15, that is, bin 1 corresponds to ages 15-24, bin 2 corresponds to ages 25-34, bin 3 corresponds to ages 35-44, bin 4 corresponds to ages 45-54, bin 5 corresponds to ages 55-64, bin 6 corresponds to ages 65-74, bin 7 corresponds to ages 75-84, bin 8 corresponds to 85-94, and bin 9 corresponds to ages 95+. Note that this means that no patient will (initially) be older than 105.

For instance, the sample `age_wgt_m` provided is `[.217, .214, .181, .16, .119, .072, .03, .007, .001]`. This corresponds to the population distributions of the US for males at those ages. 21.7% of patients will be between 15-24, 21.4% between 25-34, 18.1% between 35-44, etc. Similarly, the `death_prob_natural` sample (calculated from US mortality statistics) is `[.00075, .00128, .0019, .00401, .00879, .01786, .04473, .13392, .13392]`. This means that every month, someone who is between ages 15 and 24 has a 0.075% chance of dying, someone between the ages of 35-44 has a 0.128% chance of dying etc.

#### Birthdate Calculation
To calculate patient birthdates, first the patient's age bin is determined based on the `age_wgt` vector for their sex. Initial ages are then uniformly distributed across that age bin, so that a patient in the 25-34 age bin has the same probability of being 25 or 28. The birthdate is then calculated based on the current simulation date and that age. So if the simulation starts on Jan 1, 2015 and the patient is 28, their birthdate will be between Jan 2nd, 1986 and Jan 1st, 1987. The date selected are also determined by a uniform distribution.

#### Death date calculation
Once a month, the simulation will update the patient pool with the patients who have died. Whether or not a patient has died is determined by the `death_prob_natural` for their age in and the `p_additional_death_prob` correction. That is, the patient's current age (based on their birthdate and the simulations current date) is used to determine which age bin they fall into and the probability described by `death_prob_natural` plus the correction is used to determine whether or not they have died. For all patients who are determined to have died in the last month, we then calculate their death date. The death date is randomly selected from either (1) the days between their last visit and the current date if they have appeared at least one or (2) the days between the start of the previous month and the current day if they have not had a visit. Note that it is possible for patients to die without having been seen in the simulation at all. These patients are excluded from the resulting `patient_pool.csv`.

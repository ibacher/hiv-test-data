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
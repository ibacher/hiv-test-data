-- For documentation purposes, this is the script used to generate the data
SELECT 
	date_format(encounter_datetime,'%m-%Y') as month_year,
	MONTH(encounter_datetime) as month,
	YEAR(encounter_datetime) as year,    
  COUNT(DISTINCT `encounter_id`) AS distinct_encounters,
	COUNT(DISTINCT `visit_id`) AS distinct_visits,
	COUNT(DISTINCT if(prev_clinical_datetime_hiv is null,`person_id`,null)) AS newly_enrolled,
  COUNT(DISTINCT if(encounter_datetime >= arv_start_date,`person_id`,null)) as patients_on_arvs,
  COUNT(DISTINCT if((encounter_datetime < arv_start_date  or arv_start_date is null),`person_id`,null)) as patients_not_on_arvs,
	COUNT(DISTINCT if(vl_1 < 1000, `encounter_id` ,null)) as vl_suppressed_encounters,
  COUNT(DISTINCT if(vl_1 >= 1000, `encounter_id`,null)) as vl_failure_encouunters,
  COUNT(DISTINCT if( timestampdiff(day, if(rtc_date, rtc_date, DATE_ADD(encounter_datetime, INTERVAL 30 DAY)), endDate) > 90,  `person_id`, null)) as LTFU
FROM
    etl.dates 
JOIN etl.flat_hiv_summary_v15b  on date(encounter_datetime) <= date(endDate)
WHERE is_clinical_encounter = 1  and (next_clinical_datetime_hiv is null or date(next_clinical_datetime_hiv) > endDate) and
encounter_datetime >= timestamp(date("2015-01-01"))  #and encounter_datetime<= date('2020-03-01')
group by MONTH(encounter_datetime),  YEAR(encounter_datetime)
order by encounter_datetime desc

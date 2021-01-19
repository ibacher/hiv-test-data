-- For documentation purposes, this is the script used to generate the data
SELECT 
	date_format(endDate,'%m-%Y') as month_year,
    # Visits 
    SUM(hmsd.visit_this_month) AS `visit_this_month`,
	SUM(hmsd.scheduled_this_month) AS `scheduled_this_month`,
    SUM(hmsd.unscheduled_this_month) AS `unscheduled_this_month`,
    SUM(hmsd.enrolled_this_month) AS `enrolled_this_month`,
    
    # LTFU and active in care
    COUNT( DISTINCT `person_id` ) as distinct_patients,
    SUM(hmsd.active_in_care_this_month) AS `active_in_care_this_month`,
    AVG(hmsd.days_since_rtc_date) AS `avg_days_since_rtc_date`,
    COUNT( DISTINCT if( timestampdiff(day, if(rtc_date, rtc_date, DATE_ADD(encounter_date, INTERVAL 30 DAY)), endDate) > 90,  `person_id`, null)) as LTFU_since_2015,
    COUNT( DISTINCT if( timestampdiff(day, if(rtc_date, rtc_date, DATE_ADD(encounter_date, INTERVAL 30 DAY)), endDate) > 90  AND TIMESTAMPDIFF(DAY, encounter_date,`endDate`) <365,  `person_id`, null)) as LTFU_past_year,
    COUNT( DISTINCT if( timestampdiff(day, if(rtc_date, rtc_date, DATE_ADD(encounter_date, INTERVAL 30 DAY)), endDate) > 90  AND TIMESTAMPDIFF(DAY, encounter_date,`endDate`) <365/2,  `person_id`, null)) as LTFU_past_6months,
	SUM(  if(status="ltfu",1, 0)) AS  LTFU_this_month,
    COUNT( DISTINCT if(TIMESTAMPDIFF(DAY, death_date,`endDate`) < 30,`person_id`, null)) as deaths_this_month,
    COUNT( DISTINCT if(TIMESTAMPDIFF(DAY, death_date,`endDate`) < 365,`person_id`, null)) as deaths_past_year,
	COUNT( DISTINCT if(TIMESTAMPDIFF(DAY, transfer_out_date,`endDate`) < 30,`person_id`, null)) as transfer_out_this_month,
    COUNT( DISTINCT if(TIMESTAMPDIFF(DAY, transfer_out_date,`endDate`) < 365,`person_id`, null)) as transfer_out_past_year,
    
	# ART Status
	SUM(hmsd.art_revisit_this_month) AS `art_revisit_this_month`,
    SUM(hmsd.is_pre_art_this_month) AS `pre_art_this_month`,
	SUM(hmsd.on_art_this_month) AS `on_art_this_month`,
    SUM(hmsd.started_art_this_month) AS `started_art_this_month`,
	SUM(had_med_change_this_month) AS `had_med_change_this_month`,
    
    # Patient Care Status Transition
	SUM(  if(status="ltfu",1, 0)) AS `ltfu_this_month_cumulative`,
    SUM(  if(status="active",1, 0)) AS `active_this_month_cumulative`,
    SUM(  if(status="dead",1, 0)) AS `dead_this_month_cumulative`,
    
    
    SUM(  if(prev_status="ltfu",1, 0)) AS `ltfu_last_month_cumulative`,
    SUM(  if(prev_status="active",1, 0)) AS `active_last_month_cumulative`,
    SUM(  if(prev_status="dead",1, 0)) AS `dead_last_month_cumulative`,
    
    SUM(  if(next_status="ltfu",1, 0)) AS `ltfu_next_month_cumulative`,
    SUM(  if(next_status="active",1, 0)) AS `active_next_month_cumulative`,
    SUM(  if(next_status="dead",1, 0)) AS `dead_next_month_cumulative`,
    
    SUM(if( prev_status="ltfu" AND status="ltfu",1, 0)) AS `ltfu_to_ltfu`,
    SUM(if( prev_status=null AND status="ltfu",1, 0)) AS `null_to_ltfu`,
    SUM(if( prev_status="active" AND status="ltfu",1, 0)) AS `active_to_ltfu`,
    SUM(if( prev_status="dead" AND status="ltfu",1, 0)) AS `dead_to_ltfu`,
    
	SUM(if( prev_status="ltfu" AND status="active",1, 0)) AS `ltfu_to_active`,
    SUM(if( prev_status=null AND status="active",1, 0)) AS `null_to_active`,
    SUM(if( prev_status="active" AND status="active",1, 0)) AS `active_to_active`,
    SUM(if( prev_status="dead" AND status="active",1, 0)) AS `dead_to_active`,
    
    SUM(if( prev_status="ltfu" AND status="dead",1, 0)) AS `ltfu_to_dead`,
    SUM(if( prev_status=null AND status="dead",1, 0)) AS `null_to_dead`,
    SUM(if( prev_status="active" AND status="dead",1, 0)) AS `active_to_dead`,
    SUM(if( prev_status="dead" AND status="dead",1, 0)) AS `dead_to_dead`,
    
    
    
    
    

    
     
     # ART Line
     SUM(hmsd.on_original_first_line_this_month) AS `on_original_first_line_this_month`,
     SUM(hmsd.on_alt_first_line_this_month) AS `on_alt_first_line_this_month`,
     SUM(hmsd.on_second_line_or_higher_this_month) AS `on_second_line_or_higher_this_month`,

	# Viral Load
    COUNT( DISTINCT if(vl_1 < 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 30, `encounter_id`, null)) as vl_suppressed_encounters_this_month,
    COUNT( DISTINCT if(vl_1 >= 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 30, `encounter_id`, null)) as vl_unsuppressed_encounters_this_month,
    COUNT( DISTINCT if(vl_1 < 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 30, `person_id`, null)) as vl_suppressed_patients_this_month,
    COUNT( DISTINCT if(vl_1 >= 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 30, `person_id`, null)) as vl_unsuppressed_patients_this_month,
	COUNT( DISTINCT if(vl_1 < 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 365, `person_id`, null)) as vl_suppressed_patients_past_year,
    COUNT( DISTINCT if(vl_1 >= 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) <365, `person_id`, null)) as vl_unsuppressed_patients_past_year,
	COUNT( DISTINCT if(vl_1 < 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 365, `encounter_id`, null)) as vl_suppressed_encounters_past_year,
    COUNT( DISTINCT if(vl_1 >= 1000 AND TIMESTAMPDIFF(DAY, vl_1_date,`endDate`) < 365, `encounter_id`, null)) as vl_unsuppressed_encounters_past_year,
     
     
	SUM(hmsd.due_for_vl_this_month) AS `due_for_vl_this_month`,
	SUM(hmsd.qualifies_for_follow_up_vl) AS `qualifies_for_follow_up_vl`,
    SUM(hmsd.got_follow_up_vl_this_month) AS `got_follow_up_vl_this_month`,
    SUM(hmsd.follow_up_vl_suppressed_this_month) AS `follow_up_vl_suppressed_this_month`,
    SUM(hmsd.follow_up_vl_unsuppressed_this_month) AS `follow_up_vl_unsuppressed_this_month`,
    SUM(hmsd.follow_up_vl_suppressed_this_month) AS `follow_up_vl_unsuppressed`,
    SUM(hmsd.follow_up_vl_suppressed_this_month) AS `follow_up_vl_suppressed`,
    AVG(hmsd.num_days_to_follow_vl) AS `avg_num_days_to_follow_vl`
    
    
    

FROM
    etl.hiv_monthly_report_dataset_frozen `hmsd`
WHERE
    (endDate >= '2020-09-01')
GROUP BY endDate
order by endDate desc

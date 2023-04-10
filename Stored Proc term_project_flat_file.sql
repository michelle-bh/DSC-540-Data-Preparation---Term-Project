USE [DSC540_Data_Preparation]
GO

/****** Object:  StoredProcedure [dbo].[term_project_flat_file]    Script Date: 4/9/2023 11:03:09 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

/*
Create the Moving Starter Kit file from 10 information tables and 1 xref table
*/


-- dbo.term_project_flat_file


alter procedure [dbo].[term_project_flat_file]

AS

---------------------------
create TABLE #flat_file
       (metro_area					varchar(100) NOT NULL,
	metro_short					varchar(100) NULL,
	state						varchar(50) NULL,
	state_code					varchar(2) NULL,
	total_population				int NULL,
	anchor_city					varchar(50),
	anchor_population				int null,
	median_age					float NULL,
	male_pct					float NULL,
	female_pct					float NULL,
	white_pct					float NULL,
	black_pct					float NULL,
	asian_pct					float NULL,
	latino_pct					float NULL,
	american_indian_alaska_native_pct		float NULL,
	pacific_islander_pct				float NULL,
	mean_income					float NULL,
	employment_pct					float NULL,
	high_school_grad_rate				float NULL,
	college_degree_pct				float NULL,
	education_rank_state				int NULL,
	education_quality_rank_state			int NULL,
	airports					int NULL,
	income_tax_rate_low				float NULL,
	income_tax_rate_high				float NULL,
	state_retirement_ranking			int NULL,
	retire_affordability				int NULL,
	retire_quality_of_life				int NULL,
	retire_health_care				int NULL,
	homes_with_internet_pct				float NULL,
	homes_without_internet_pct			float NULL,
	violent_crime_2019				int NULL,
	property_crime_2019				int NULL)


create table #max_population
      (metropolis					varchar(100),
 	principal_city					varchar(50),
 	max_pop						int)

create table #num_airports
       (metropolis					varchar(100),
 	airport_cnt					int)

insert into #flat_file
(metro_area, metro_short, total_population, median_age, male_pct, 
female_pct, white_pct, black_pct, asian_pct, latino_pct, american_indian_alaska_native_pct, 
pacific_islander_pct, mean_income, employment_pct, high_school_grad_rate, 
college_degree_pct, homes_with_internet_pct, homes_without_internet_pct)
select b.metro_area, 
case when right(b.metro_area, 11) = ' Micro Area'
	 then replace(b.metro_area, ' Micro Area', '')
	 when right(b.metro_area, 11) = ' Metro Area'
	 then replace(b.metro_area, ' Metro Area', '')
	 else b.metro_area end as area,
total_population, median_age, male, female, white,
black, asian, latino, american_indian_alaska_native, 
pacific_islander, mean_income, employment employment, 
high_school, college_degree college_degree, 
homes_with_internet, homes_without_internet
from Demographics a,
Adj_Income_Metro_Micro b,
Metro_Micro_Emp_Edu c,
Internet_metro_micro d
where a.area = b.metro_area
and b.metro_area = c.metro_area
and a.area = d.metro_area
and substring(right(b.metro_area, 13), 1, 2) <> 'PR'

-- Add state code
update #flat_file
set state = mx.state,
state_code = mx.code
from metro_xref mx
where #flat_file.metro_short = mx.metropolis

-- Add Metro & Micropolitan principal city.
insert into #max_population
(metropolis, max_pop)
select metropolis, max(population) max_pop from metro_xref x,
	Population_city p
 where x.state = p.state
   and city_name = principal_city
 group by metropolis

update #max_population
set principal_city = b.principal_city
from metro_xref b,
Population_city c
where #max_population.metropolis = b.metropolis
and #max_population.max_pop = c.population
and b.state = c.state
and c.city_name = b.principal_city

update #flat_file
set anchor_city = m.principal_city,
	anchor_population = m.max_pop
from #max_population m
where #flat_file.metro_short = m.metropolis

-- Fill in missing cities with no population info
update #flat_file
set anchor_city = mx.principal_city
from metro_xref mx
where #flat_file.metro_short = mx.metropolis
and #flat_file.anchor_city is NULL

-- Add number of Airports
insert into #num_airports
(metropolis, airport_cnt)
select metropolis, airport_cnt from metro_xref a,
	(select city, state, count(*) airport_cnt 
	   from airports
     group by city, state) b
 where b.state = a.code
   and b.city = a.principal_city

update #flat_file
set airports = a.airport_cnt
from #num_airports a
where #flat_file.metro_short = a.metropolis

-- State Income Tax Rate
update #flat_file
set income_tax_rate_low = t.Lowest_Tax_Bracket,
income_tax_rate_high = t.Highest_Tax_Bracket
from State_Income_Tax_Rates t
where #flat_file.state = t.State_Name

-- Retirement Information
update #flat_file
set state_retirement_ranking = r.Retirement_Rating,
retire_affordability = r.Affordability,
retire_quality_of_life = r.Quality_of_Life,
retire_health_care = r.Health_Care
from Retirement_by_State r
where #flat_file.state = r.State

-- Education Rankings by State
update #flat_file
set education_rank_state = e.overall_rank,
education_quality_rank_state = e.quality_of_education
from education_by_state_ranked e
where #flat_file.state = e.state

-- Crime for 2019
update #flat_file
set violent_crime_2019 = c.violent_crime_2019,
property_crime_2019 = c.property_crime_2019
from crime_city_state_2019 c
where upper(#flat_file.state) = c.state
and #flat_file.anchor_city = c.city

-- Flat File Out
select * from #flat_file


GO

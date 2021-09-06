-- Covid 19 Data Exploration --

-- Data as of 07/08/21
-- data source: https://ourworldindata.org/covid-deaths

-- Using Joins, CTE's, Temp Tables, Aggreagte Functions, Windows Functions






-- Changing 'date' data type from DATETIME to DATE.

ALTER TABLE coviddeaths
ALTER COLUMN date DATE;

ALTER TABLE covidvaccinations
ALTER COLUMN date DATE;






--1. Comparing daily cases and deaths globally 

SELECT date, 
       SUM(new_cases) AS total_cases, 
       SUM(new_deaths) AS total_deaths, 
       ROUND((SUM(new_deaths)/SUM(new_cases))*100, 2) AS death_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date ASC;

-- Most records include a string value in the 'location' field corrosponding to the country, and a value in the 'continent' field listing the continent which the country belongs to.
-- Where 'continent' IS NULL represents records including summarised data with continent-wide or world-wide perview. These records include the continent or other international region name in the 'location' field instead.
-- We want to exclude these summarised records - this will be the case in most of the following queries also.






-- 2. Global summary

SELECT SUM(new_cases) AS total_cases, 
       SUM(new_deaths) AS total_deaths,
       ROUND(SUM(new_deaths)/SUM(new_cases)*100, 2) AS death_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL; 






-- 3. Death count broken down by continent

SELECT location, 
       SUM(new_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL 
AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
ORDER BY total_death_count DESC;

-- In this case, we specify records where 'continent' IS NULL such that our results are narrowed down to continet and world summary records.
-- We then further exclude records whose 'location' is not listed as a continent. We do this via exlcuding records with the location value 'World', 'European Union' and 'International'






-- 4a. Comparing countries with the highest infection rate compared to population (per 100 people)

SELECT location, 
       population, 
       MAX(total_cases) AS highest_infection_count,  
       ROUND(MAX((total_cases/population))*100, 2) as infection_rate
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, 
	 population
HAVING MAX(total_cases) IS NOT NULL
ORDER BY infection_rate DESC;


-- 4b. Further grouping by date on the previous query, showing the cumulative rise in cases proportional to population.

SELECT location, 
       population,
       date, 
       MAX(total_cases) AS highest_infection_count,  
       ROUND(MAX((total_cases/population))*100, 2) AS cases_per_hundred
FROM CovidDeaths
GROUP BY location, 
	 population,
	 date
ORDER BY location,
	 date;






--5a. Using a nested subquery to calculate the 7 day rolling average of deaths per million.

SELECT A.location, 
       A.population, 
       A.date,
       A.new_deaths, 
       ROUND((A.rolling_avg)*1000000/(A.population),2) AS deaths_per_million_7da
FROM
(
SELECT location,
       population,
       date,
       new_deaths,
       AVG(CAST(new_deaths AS DECIMAL(6,2))) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN 6 PRECEDING and CURRENT ROW) AS rolling_avg
FROM coviddeaths
WHERE continent IS NOT NULL
--AND location = 'United Kingdom'
) AS A;


-- 5b. Using a common table expression on the above SELECT query to achieve the same output.

WITH rolling_avg_cte 
AS
(
SELECT location,
       population,
       date,
       new_deaths,
       AVG(CAST(new_deaths AS DECIMAL)) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN 6 PRECEDING and CURRENT ROW) AS rolling_avg
FROM coviddeaths
WHERE continent IS NOT NULL
)
SELECT location, 
       population, 
       date, 
       new_deaths, 
       ROUND((rolling_avg * 1000000/population),2) AS deaths_per_million_7da FROM rolling_avg_cte;






-- 6a. Using a common table expression to calcaulte the total number of vaccine doses administered per 100 people

WITH doses_per_100 (continent, location, date, population, new_vaccinations, cumulative_vaccinations)
AS 
(
SELECT d.continent,
       d.location,
       d.date,
       d.population,
       v.new_vaccinations,
       SUM(CAST(v.new_vaccinations AS NUMERIC)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS cumulative_vaccinations
FROM CovidDeaths d
	  JOIN 
     CovidVaccinations v ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL
--AND d.location LIKE '%United Kingdom%'
)
SELECT *,
       ROUND(cumulative_vaccinations / population * 100, 2) AS doses_per_hundred
FROM doses_per_100
--WHERE CONVERT(DATE,date) = '2021-07-08'
ORDER BY continent,
         location,
         date;


-- 6b. Using a temp table to achieve the same result.

DROP TABLE IF EXISTS #temp_doses_per_100
CREATE TABLE #temp_doses_per_100 (
continent NVARCHAR(255),
location NVARCHAR(255),
date DATE,
population BIGINT,
new_vaccinations NUMERIC,
cumulative_vaccinations NUMERIC);

INSERT INTO #temp_doses_per_100
SELECT d.continent,
       d.location,
       d.date,
       d.population,
       v.new_vaccinations,
       SUM(CAST(v.new_vaccinations AS NUMERIC)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS cumulative_vaccinations
FROM CovidDeaths d
	  JOIN 
    CovidVaccinations v ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL
  
SELECT *,
       ROUND(cumulative_vaccinations / population * 100, 2) AS doses_per_hundred
FROM #temp_doses_per_100;
  

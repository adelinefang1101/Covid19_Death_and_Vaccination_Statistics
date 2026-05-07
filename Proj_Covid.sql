
SELECT * 
FROM covid_deaths1_pyengine
order by 3,4;

-- CHECK if any null we can fillin
SELECT location, date
FROM covid_deaths1_pyengine
WHERE location is null
OR date is null; -- none

SELECT DISTINCT location, population
FROM covid_deaths1_pyengine
WHERE population is null;
-- 1. Asia excl. China: Means Aisa except for China. Null is fine.
-- 2. England: Not an independent sovereign country. Null is fine.
-- 3. England and Wales: Null is fine
-- 4. Northern Ireland: Not an independent sovereign country. Null is fine.
-- 5. Pitcairn: British territory. Null is fine.
-- 6. Scotland: Not an independent sovereign country. Null is fine.
-- 7. Summer Olympics 2020 / Winter Olympics 2022: Null is fine.
-- 8. World excl. China, World excl. China and South Korea, World excl. China, South Korea, Japan and Singapore: Null is expected.

-- See if UK is included
SELECT COUNT(location)
FROM covid_deaths1_pyengine
WHERE location = 'united kingdom'; -- 2224 rows returned, so, yes

SELECT *
FROM covid_deaths1_pyengine
WHERE location IN ('Asia excl. China', 'England', 'England and Wales', 'Northern Ireland', 'Pitcairn', 'Scotland', 'Summer Olympics 2020', 'Winter Olympics 2022', 'World excl. China', 'World excl. China, South Korea, Japan and Singapore') ; -- There are valid values, so I will keep them as is


-- Select data that we are going to be using
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM covid_deaths1_pyengine
ORDER BY 1,2;

-- Looking at total cases vs total deaths 
-- Shows likelihood of dying if you contract covid in your country
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM covid_deaths1_pyengine
ORDER BY 1,2; -- interpreting the calculation: 3 means 3% of patients died in those cases.

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM covid_deaths1_pyengine
WHERE location = 'united states' and date = '2021-04-29';

-- Looking at total cases vs population
-- Shows what percentage of population got Covid
Select location, date, total_cases, population, (total_cases/population)*100 AS PercentPopulationInfected  
FROM covid_deaths1_pyengine
WHERE location = 'United States' and (total_cases/population)*100 > 1
ORDER BY 1,2;

-- Which country has the most cases?
SELECT location, population, MAX(total_cases) AS HighestInfectionCount 
FROM covid_deaths1_pyengine
GROUP BY location, population
ORDER BY 3 Desc; -- United States ≈ 103436829 has the most cases

-- Which country has the highest infection?
-- Breakdown: Looking at countries with the highest infection rate compare to population
SELECT location, population, MAX((total_cases/population)*100) AS PercentPopulationInfected 
FROM covid_deaths1_pyengine
GROUP BY location, population
ORDER BY 3 Desc; -- Brunei ≈ 76.98% in its population got infected

-- Showing countries with highest death count per population
SELECT location, population, MAX((total_deaths/population)*100) AS DeathPercentage
FROM covid_deaths1_pyengine
GROUP BY location, population
ORDER BY 3 DESC; -- Rank 1: Peru 

-- Let's break things down by continent
SELECT continent, MAX(population), MAX((total_deaths/population)*100) AS DeathPercentage
FROM covid_deaths1_pyengine
GROUP BY continent
ORDER BY 3 DESC; -- there goes NULL in continent

SELECT DISTINCT continent, location
FROM covid_deaths1_pyengine
WHERE continent is null; -- When continent is NULL, locations are: Africa, Asia, England, World, etc

-- If I change null 'continent' to its real continent, there will be countries been calculted more than once, so let's give them another name.

UPDATE covid_deaths1_pyengine
SET continent = 'Other'
WHERE continent IS NULL; -- All set!

-- Get back to this query
SELECT continent, MAX(population), MAX((total_deaths/population)*100) AS DeathPercentage
FROM covid_deaths1_pyengine
GROUP BY continent
ORDER BY 3 DESC; -- Seems like we don't have data of Antarctica

SELECT continent
FROM covid_deaths1_pyengine
WHERE continent = '%Antarctica%' OR location = '%Antarctica%'; -- No records, that's okay

-- Showing continents with the highest death count per population
SELECT continent, MAX((total_deaths/population)*100) AS DeathCountPerPopulation
FROM covid_deaths1_pyengine
GROUP BY continent
ORDER BY 2 DESC;

-- Global Numbers (Death percentage by date)
SELECT date, SUM(new_cases) AS TotalCases, SUM(new_deaths) AS TotalDeaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathPercentage
FROM covid_deaths1_pyengine
WHERE continent != 'Other'
GROUP BY 1
ORDER BY 1;

SELECT SUM(new_cases) AS TotalCases, SUM(new_deaths) AS TotalDeaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathPercentage
FROM covid_deaths1_pyengine
WHERE continent != 'Other';

-- Join two tables
SELECT *
FROM covid_deaths1_pyengine AS dea
JOIN covid_vaccinations1_pyengine AS vac
	ON dea.location = vac.location
    and dea.date = vac.date; -- location and date are the most granular level.

-- Looking at Total Population vs Vaccinations  
-- The below statement will cause an error because we can't select the column we just created 
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated, RollingPeopleVaccinated/population)*100
FROM covid_deaths1_pyengine AS dea
JOIN covid_vaccinations1_pyengine AS vac
	ON dea.location = vac.location
    and dea.date = vac.date
WHERE dea.continent != 'Other'
ORDER BY 2,3; 

-- Use CTE (Commom Table Expression, can be used as a temporary table)
WITH PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated) AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM covid_deaths1_pyengine AS dea
JOIN covid_vaccinations1_pyengine AS vac
	ON dea.location = vac.location
    and dea.date = vac.date
WHERE dea.continent != 'Other'
)
SELECT *, (RollingPeopleVaccinated/population)*100
FROM PopvsVac; 

-- TEMP Table
CREATE TABLE PercentPopulationVaccinated
(
continent varchar(255),
location varchar(255),
date datetime,
population bigint,
New_vaccinations bigint,
RollingPeopleVaccinated double
) 
;
INSERT INTO PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM covid_deaths1_pyengine AS dea
JOIN covid_vaccinations1_pyengine AS vac
	ON dea.location = vac.location
    and dea.date = vac.date
;




 



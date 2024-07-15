-- Select data
Select Location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject1..CovidDeaths
Where continent is not null
Order by 1,2

-- Looking at Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in the United States
Select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProject1..CovidDeaths
Where location like '%states%'
Order by 1,2 DESC

-- Looking at Total Cases vs Population
-- Shows what percentage of population got covid
Select Location, date, total_cases, population, (total_cases/population)*100 as PercentPopulationInfected
From PortfolioProject1..CovidDeaths
Where location like '%states%'
Order by 1,2 DESC

-- Looking at Countries with Highest Infection Rate compared to Population
Select Location, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 as MaxPercentPopulationInfected
From PortfolioProject1..CovidDeaths
Group By Location, Population
Order by 4 DESC

-- Breaking things down by Continent
Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
From PortfolioProject1..CovidDeaths
Where continent is not null
Group By continent
Order by 2 DESC

-- Showing Countries with Highest Death Count per Population
Select Location, MAX(cast(total_deaths as int)) as TotalDeathCount
From PortfolioProject1..CovidDeaths
Where continent is not null
Group By Location
Order by 2 DESC

-- Showing Continents with the Highest Death Count per Population
Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
From PortfolioProject1..CovidDeaths
Where continent is not null
Group By continent
Order by 2 DESC

-- Global Numbers
Select date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, SUM(new_deaths)/SUM(new_cases) as DeathPercentage
From PortfolioProject1..CovidDeaths
Where continent is not null and new_cases != 0
Group by date
Order by 1

-- Join CovidDeaths and CovidVaccinations table
-- Create CTE with rolling total of vaccinations
With PopvsVac (continent, location, date, population, new_vaccinations, VaccinationRollingTotal)
as (
Select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
SUM(cast(vaccs.new_vaccinations as float)) over
	(Partition by deaths.location
	Order by deaths.location, deaths.date)
	as VaccinationRollingTotal
From PortfolioProject1..CovidDeaths deaths
Join PortfolioProject1..CovidVaccinations vaccs
	On deaths.location = vaccs.location
	and deaths.date = vaccs.date
Where deaths.continent is not null
)
-- Looking at Total Population vs Vaccinations
Select *, (VaccinationRollingTotal/population)*100 as PercentPopulationVaccinated
From PopvsVac
Order by 2,3

-- Perform above using a Temp Table
Drop Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
VaccinationRollingTotal numeric
)
Insert into #PercentPopulationVaccinated
Select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
SUM(cast(vaccs.new_vaccinations as float)) over
	(Partition by deaths.location
	Order by deaths.location, deaths.date)
	as VaccinationRollingTotal
From PortfolioProject1..CovidDeaths deaths
Join PortfolioProject1..CovidVaccinations vaccs
	On deaths.location = vaccs.location
	and deaths.date = vaccs.date
Where deaths.continent is not null

Select *, (VaccinationRollingTotal/population)*100 as PercentPopulationVaccinated
From #PercentPopulationVaccinated
Order by 2,3

-- Creating View to store data for later visualizations
Create View PercentPopulationVaccinated as
Select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
SUM(cast(vaccs.new_vaccinations as float)) over
	(Partition by deaths.location
	Order by deaths.location, deaths.date)
	as VaccinationRollingTotal
From PortfolioProject1..CovidDeaths deaths
Join PortfolioProject1..CovidVaccinations vaccs
	On deaths.location = vaccs.location
	and deaths.date = vaccs.date
Where deaths.continent is not null

Select *
From PercentPopulationVaccinated
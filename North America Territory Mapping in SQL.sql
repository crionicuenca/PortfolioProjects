WITH

-- alias mapping tables
ca_region_mapping AS (
	SELECT
		"Zip Code" AS ca_zip,
		"Region Mapping" AS ca_region
	FROM "ca region mapping"
),

na_territory_mapping AS (
	SELECT
		"Unique ID" AS territory_id,
		"Territory" AS territory,
		"Rep" AS rep
	FROM "na territory mapping"
),

-- create randomized round robin table for mapping round robin accounts
round_robin AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS row_number
	FROM (
		SELECT DISTINCT rep
		FROM na_territory_mapping
		WHERE territory = 'Enterprise' AND rep <> 'Round Robin'
	)
),

-- alias accounts table and map letter, ca1/ca2/ent territories, and ca region
accounts AS (
	SELECT
		"Account 18 ID" AS acc_id,
		LOWER("Account Name") AS acc_name,
		LOWER("Global Ultimate Parent (ABM)") AS abm,
		"Is Top H_GU?" AS top_gu,
		"Global Ultimate # Employees" AS employees,
		"Billing State/Province" AS state,
		SUBSTRING("Billing Zip/Postal Code", 1, 5) AS zip_code,

		-- abm_letter: maps abm name to letter mapping
		CASE
			WHEN LOWER( LEFT("Global Ultimate Parent (ABM)", 1) ) BETWEEN 'a' AND 'k' THEN 'LetterMap1'
			WHEN LOWER( LEFT("Global Ultimate Parent (ABM)", 1) ) BETWEEN 'l' AND 'z' THEN 'LetterMap2'
			ELSE 'LetterMap1'
		END AS abm_letter,

		-- abm_territory: maps abm territory according to employee count
		CASE
			WHEN "Global Ultimate # Employees" BETWEEN 0 AND 250 THEN 'CA1'
			WHEN "Global Ultimate # Employees" BETWEEN 251 AND 1000 THEN 'CA2'
			WHEN "Global Ultimate # Employees" > 1000 THEN 'Enterprise'
			ELSE NULL
		END AS territory,

		-- ca_region: if state = california, return ca region, else null
		CASE
			WHEN
				LOWER("Billing State/Province") = 'ca' OR
				LOWER("Billing State/Province") = 'california'
			THEN b.ca_region
			ELSE ''
		END AS ca_region
		
	FROM accounts
	LEFT JOIN ca_region_mapping AS b
		ON SUBSTRING("Billing Zip/Postal Code", 1, 5) = b.ca_zip
),

-- CTEs for abm steps 1 & 2: finds max employees by account name/abm and top gu = 1
-- first filters all accounts by top gu = 1, then finds max among those
abm_aggregate1 AS (
	SELECT
		acc_id,
		acc_name,
		abm,
		employees,
		MAX(employees) OVER (PARTITION BY acc_name) AS max_emp_acc_name,
		MAX(employees) OVER (PARTITION BY abm) AS max_emp_abm
	FROM accounts
	WHERE top_gu = 1 ),
abm_step1 AS ( SELECT * FROM abm_aggregate1 WHERE employees = max_emp_acc_name ),
abm_step2 AS ( SELECT * FROM abm_aggregate1 WHERE employees = max_emp_abm ),

-- CTEs for abm step 3: finds max employees by abm regardless of top gu
abm_aggregate2 AS (
	SELECT
		acc_id,
		abm,
		employees,
		MAX(employees) OVER (PARTITION BY abm) AS max_emp_abm
	FROM accounts ),
abm_step3 AS ( SELECT * FROM abm_aggregate2 WHERE employees = max_emp_abm ),

-- CTE for joining abm steps and obtaining final abm_id
abm_steps_join_with_dupes AS (
	SELECT
		a.acc_id,
		a.acc_name,
		a.abm,
		abm_step1.acc_id AS abm_id1,
		abm_step2.acc_id AS abm_id2,
		abm_step3.acc_id AS abm_id3,

		-- abm_id: if step1 is null, use step2, then step3
		CASE
			WHEN abm_step1.acc_id IS NOT NULL THEN abm_step1.acc_id
			WHEN abm_step2.acc_id IS NOT NULL THEN abm_step2.acc_id
			ELSE abm_step3.acc_id
		END AS abm_id,
		
		-- assign row numbers per account id to delete duplicates
		ROW_NUMBER() OVER (PARTITION BY a.acc_id ORDER BY a.acc_id) AS rn
	FROM accounts AS a
	
	-- join abm_step1: join account name to abm
	LEFT JOIN abm_step1 ON a.abm = abm_step1.acc_name
	-- join abm_step2 and abm_step3: join abm to abm
	LEFT JOIN abm_step2 ON a.abm = abm_step2.abm
	LEFT JOIN abm_step3 ON a.abm = abm_step3.abm
),
-- CTE for deleting duplicates
abm_steps_join AS ( SELECT * FROM abm_steps_join_with_dupes WHERE rn = 1 ),

-- CTE for obtaining a unique id for mapping na territory
accounts_unique_id AS (
	SELECT
		a.acc_id,
		a.acc_name,
		a.abm AS original_abm,
		a.abm_id,
		b.acc_name AS abm_name,
		b.territory AS territory,

		-- concatenate abm info for mapping
		REPLACE ( LOWER (
			b.state ||
			b.ca_region ||
			b.abm_letter ||
			b.territory
		), ' ', '' ) AS unique_id

	FROM abm_steps_join AS a
	LEFT JOIN accounts AS b
		ON a.abm_id = b.acc_id
),

-- CTE for territory mapping and assigning random numbers to round robin accs
accounts_mapping1 AS (
	SELECT
		a.acc_id AS "Account 18 ID",
		INITCAP(a.acc_name) AS "Account Name",
		INITCAP(a.original_abm) AS "Old ABM Name",
		a.abm_id AS "ABM Account 18 ID",
		INITCAP(a.abm_name) AS "ABM Name",
		a.territory AS "Territory",
		b.rep AS "Rep",

		-- assign random number to round robin accounts
		CASE
			WHEN b.rep = 'Round Robin' THEN
			trunc(random() * ( SELECT COUNT(*) FROM round_robin ) + 1)
		END AS "Round Robin"
		
	FROM accounts_unique_id AS a
	LEFT JOIN na_territory_mapping AS b
		ON a.unique_id = b.territory_id
),

-- final CTE for mapping round robin accounts
accounts_mapping2 AS (
	SELECT
		a."Account 18 ID",
		a."Account Name",
		a."Old ABM Name",
		a."ABM Account 18 ID",
		a."ABM Name",
		a."Territory",
		
		-- map random numbers to round robin table of randomized enterprise reps
		CASE
			WHEN a."Rep" = 'Round Robin' THEN b.rep
			ELSE a."Rep"
		END AS "Rep"
		
	FROM accounts_mapping1 AS a
	LEFT JOIN round_robin AS b
		ON a."Round Robin" = b.row_number
),

-- query for pulling null mappings
null_mapping AS (
	SELECT
		a.acc_id AS "Account 18 ID",
		a.acc_name AS "Account Name",
		a.original_abm AS "Old ABM Name",
		a.abm_id AS "ABM Account 18 ID",
		a.abm_name AS "ABM Name",
		c.employees AS "Employees",
		c.state AS "State",
		c.zip_code AS "Zip Code",
		c.ca_region AS "CA Region",
		a.territory AS "Territory",
		b.rep AS "Rep",
		a.unique_id
		
	FROM accounts_unique_id AS a
	LEFT JOIN na_territory_mapping AS b ON a.unique_id = b.territory_id
	LEFT JOIN accounts AS c ON a.abm_id = c.acc_id
	WHERE b.rep IS NULL
)

SELECT * FROM accounts_mapping2 ORDER BY "ABM Name";
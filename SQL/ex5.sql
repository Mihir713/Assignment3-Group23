-- SE 3309 Assignment 3, Group 23 - talentmkt
-- ex5.sql: seven SELECT queries
USE talentmkt;

-- Q1 (simple selection): open markets that close before June 2027, soonest first.
SELECT slug, metric, threshold_pct, closes_at
FROM Market
WHERE status = 'open' AND closes_at < TIMESTAMP '2027-06-01 00:00:00'
ORDER BY closes_at;

-- Q2 (join + GROUP BY + HAVING): per university, verified students, completed-course rows and
-- average courses per student; only schools with at least 150 students.
SELECT s.university_name,
       COUNT(DISTINCT s.handle)                                AS students,
       COUNT(c.handle)                                         AS completed_rows,
       ROUND(COUNT(c.handle) / COUNT(DISTINCT s.handle), 1)    AS avg_courses
FROM Student s LEFT JOIN Completed c ON c.handle = s.handle
GROUP BY s.university_name
HAVING COUNT(DISTINCT s.handle) >= 150
ORDER BY students DESC;

-- Q3 (relational division with double NOT EXISTS): Western students who have completed EVERY
-- Western course that develops 'Machine Learning'.
SELECT s.handle, s.program, s.grad_year
FROM Student s
WHERE s.university_name = 'Western University'
  AND NOT EXISTS (SELECT *
                  FROM Develops d
                  WHERE d.university_name = s.university_name
                    AND d.skill_label = 'Machine Learning'
                    AND NOT EXISTS (SELECT * FROM Completed c
                                    WHERE c.handle = s.handle
                                      AND c.subject = d.subject AND c.number = d.number))
ORDER BY s.grad_year, s.handle;

-- Q4 (correlated subqueries + CASE): resolution audit. For every resolved market, recompute the share
-- of snapshot members whose LATEST report before the deadline meets the rule, and compare the
-- recomputed outcome with the stored one (A1 "Market Resolution and Payout").
SELECT m.slug, m.threshold_pct, x.members, x.hits,
       ROUND(100 * x.hits / x.members, 1) AS pct,
       CASE WHEN 100 * x.hits / x.members >= m.threshold_pct THEN 'yes' ELSE 'no' END AS recomputed,
       m.outcome AS stored_outcome
FROM Market m
JOIN (SELECT mk.slug, COUNT(*) AS members,
             SUM(CASE WHEN r.status = mk.metric
                       AND (mk.rule_region IS NULL OR r.job_region = mk.rule_region)
                       AND (mk.rule_field  IS NULL OR r.job_field  = mk.rule_field)
                       AND (mk.rule_salary_band IS NULL OR
                            (CASE r.salary_band WHEN '<60k' THEN 1 WHEN '60-80k' THEN 2 WHEN '80-100k' THEN 3 WHEN '100-130k' THEN 4 WHEN '130k+' THEN 5 END)
                         >= (CASE mk.rule_salary_band WHEN '<60k' THEN 1 WHEN '60-80k' THEN 2 WHEN '80-100k' THEN 3 WHEN '100-130k' THEN 4 WHEN '130k+' THEN 5 END))
                      THEN 1 ELSE 0 END) AS hits
      FROM Market mk
      JOIN FrozenMember f ON f.cohort_title = mk.cohort_title AND f.frozen_at = mk.frozen_at
      LEFT JOIN OutcomeReport r
             ON r.handle = f.handle
            AND r.reported_at = (SELECT MAX(r2.reported_at) FROM OutcomeReport r2
                                 WHERE r2.handle = f.handle AND r2.reported_at < mk.deadline)
      WHERE mk.status = 'resolved'
      GROUP BY mk.slug) x ON x.slug = m.slug
ORDER BY m.deadline, m.slug;

-- Q5 (WITH + window function): leaderboard (A1 "Portfolio and Leaderboard"). Net worth = ledger balance
-- + current value of shares held in open/closed markets at the latest traded YES price. Top 10.
WITH last_price AS (
    SELECT t.market_slug, t.price_after AS yes_price
    FROM Trade t
    WHERE t.created_at = (SELECT MAX(t2.created_at) FROM Trade t2 WHERE t2.market_slug = t.market_slug)
),
bal AS (
    SELECT handle, SUM(amount) AS balance FROM LedgerEntry GROUP BY handle
),
holdings AS (
    SELECT p.handle, SUM(p.yes_shares * lp.yes_price + p.no_shares * (1 - lp.yes_price)) AS open_value
    FROM Position p
         JOIN Market m      ON m.slug = p.market_slug AND m.status IN ('open', 'closed')
         JOIN last_price lp ON lp.market_slug = p.market_slug
    GROUP BY p.handle
),
ranked AS (
    SELECT b.handle, b.balance, COALESCE(h.open_value, 0) AS open_value,
           b.balance + COALESCE(h.open_value, 0) AS net_worth,
           RANK() OVER (ORDER BY b.balance + COALESCE(h.open_value, 0) DESC) AS rnk
    FROM bal b LEFT JOIN holdings h ON h.handle = b.handle
)
SELECT rnk, handle, balance, ROUND(open_value, 2) AS open_value, ROUND(net_worth, 2) AS net_worth
FROM ranked
WHERE rnk <= 10
ORDER BY rnk, handle;

-- Q6 (derived table + multi-way join + aggregation): Skill Signal Insights (A1). For each skill,
-- the average current YES price and total volume of open markets on cohorts that require it,
-- split by what the market measures.
SELECT r.skill_label, m.metric,
       COUNT(DISTINCT m.slug)    AS open_markets,
       ROUND(AVG(v.yes_price), 3) AS avg_yes_price,
       SUM(v.volume)             AS volume
FROM Requires r
     JOIN Market m ON m.cohort_title = r.cohort_title AND m.status = 'open'
     JOIN (SELECT t.market_slug,
                  SUM(t.cost) AS volume,
                  MAX(CASE WHEN t.created_at = (SELECT MAX(t2.created_at) FROM Trade t2
                                                 WHERE t2.market_slug = t.market_slug)
                           THEN t.price_after END) AS yes_price
           FROM Trade t
           GROUP BY t.market_slug) v ON v.market_slug = m.slug
GROUP BY r.skill_label, m.metric
HAVING SUM(v.volume) > 2000
ORDER BY volume DESC;

-- Q7 (set operation INTERSECT + IN): students who sit in at least one frozen cohort snapshot AND
-- trade (always in other cohorts' markets, the insider trigger guarantees that), counted per program.
SELECT s.program, COUNT(*) AS students_who_bet_on_other_cohorts
FROM Student s
WHERE s.handle IN (SELECT handle FROM FrozenMember
                   INTERSECT
                   SELECT handle FROM Trade)
GROUP BY s.program
ORDER BY 2 DESC;

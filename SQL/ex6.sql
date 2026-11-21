-- SE 3309 Assignment 3, Group 23 - talentmkt
-- ex6.sql: data modification commands (run after ex3.sql)
USE talentmkt;

-- 6.1 UPDATE several tuples with a correlated subquery: activate every proposed cohort that now has
-- at least 25 members (A2 2.6: a cohort becomes active at 25 members, and activated_at is set then).
SELECT c.title, c.status, c.activated_at,
       (SELECT COUNT(*) FROM MemberOf mo WHERE mo.cohort_title = c.title) AS members
FROM Cohort c WHERE c.status = 'proposed' ORDER BY c.title;

UPDATE Cohort
SET status = 'active', activated_at = CURRENT_TIMESTAMP(6)
WHERE status = 'proposed'
  AND (SELECT COUNT(*) FROM MemberOf mo WHERE mo.cohort_title = Cohort.title) >= 25;

SELECT c.title, c.status, c.activated_at,
       (SELECT COUNT(*) FROM MemberOf mo WHERE mo.cohort_title = c.title) AS members
FROM Cohort c WHERE c.title IN ('Business Analytics 2026', 'Data Platform Engineers 2027', 'Early ML Track 2029',
                                'Quant Track 2026', 'Security Track 2028')
ORDER BY c.title;

-- 6.2 UPDATE several tuples with a computed value: resolve every closed market whose deadline has passed.
-- The outcome is computed in the UPDATE itself from the snapshot's members and each member's latest
-- OutcomeReport before the deadline (A1 "Market Resolution and Payout").
SELECT slug, status, outcome, threshold_pct, deadline FROM Market WHERE status = 'closed' ORDER BY slug;

UPDATE Market
SET status = 'resolved',
    outcome = CASE WHEN
        (SELECT 100 * SUM(CASE WHEN r.status = Market.metric
                                AND (Market.rule_region IS NULL OR r.job_region = Market.rule_region)
                                AND (Market.rule_field  IS NULL OR r.job_field  = Market.rule_field)
                                AND (Market.rule_salary_band IS NULL OR
                                     (CASE r.salary_band WHEN '<60k' THEN 1 WHEN '60-80k' THEN 2 WHEN '80-100k' THEN 3
                                                         WHEN '100-130k' THEN 4 WHEN '130k+' THEN 5 END)
                                  >= (CASE Market.rule_salary_band WHEN '<60k' THEN 1 WHEN '60-80k' THEN 2 WHEN '80-100k' THEN 3
                                                         WHEN '100-130k' THEN 4 WHEN '130k+' THEN 5 END))
                               THEN 1 ELSE 0 END) / COUNT(*)
         FROM FrozenMember f
              LEFT JOIN OutcomeReport r
                     ON r.handle = f.handle
                    AND r.reported_at = (SELECT MAX(r2.reported_at) FROM OutcomeReport r2
                                         WHERE r2.handle = f.handle AND r2.reported_at < Market.deadline)
         WHERE f.cohort_title = Market.cohort_title AND f.frozen_at = Market.frozen_at)
        >= threshold_pct THEN 'yes' ELSE 'no' END
WHERE status = 'closed' AND deadline < CURRENT_DATE;

SELECT slug, status, outcome, threshold_pct, deadline FROM Market
WHERE status = 'resolved' AND deadline = DATE '2026-10-01' ORDER BY slug;

-- 6.3 INSERT the result of a query: pay out the markets resolved in 6.2. Every position holding winning
-- shares gets one payout LedgerEntry worth 1 credit per share. entry_no continues each user's own
-- numbering; ROW_NUMBER() keeps it unique when one user wins in several markets at once.
-- NOT EXISTS makes the statement safe to run twice (markets already paid out are skipped).
INSERT INTO LedgerEntry (handle, entry_no, amount, kind, created_at, payout_market_slug)
SELECT p.handle,
       (SELECT MAX(l.entry_no) FROM LedgerEntry l WHERE l.handle = p.handle)
         + ROW_NUMBER() OVER (PARTITION BY p.handle ORDER BY p.market_slug),
       CASE WHEN m.outcome = 'yes' THEN p.yes_shares ELSE p.no_shares END,
       'payout', CURRENT_TIMESTAMP(6), m.slug
FROM Position p JOIN Market m ON m.slug = p.market_slug
WHERE m.status = 'resolved'
  AND CASE WHEN m.outcome = 'yes' THEN p.yes_shares ELSE p.no_shares END > 0
  AND NOT EXISTS (SELECT * FROM LedgerEntry l2 WHERE l2.payout_market_slug = m.slug);

SELECT payout_market_slug, COUNT(*) AS payouts, SUM(amount) AS credits_paid
FROM LedgerEntry
WHERE kind = 'payout' AND payout_market_slug IN
      (SELECT slug FROM Market WHERE status = 'resolved' AND deadline = DATE '2026-10-01')
GROUP BY payout_market_slug ORDER BY payout_market_slug;

-- 6.4 (constraint demo) The ledger is append-only, so a set-oriented DELETE is rejected by the trigger.
DELETE FROM LedgerEntry WHERE kind = 'fee' AND amount > -0.10;

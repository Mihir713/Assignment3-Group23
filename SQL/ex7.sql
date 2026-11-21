-- SE 3309 Assignment 3, Group 23 - talentmkt
-- ex7.sql: two views, a query on each, and update attempts
USE talentmkt;

-- View 1: per-market statistics shown on the browse page (A1 "Market Search and Browse").
-- yes_price and volume are the derived attributes from A2 that we never store.
CREATE VIEW MarketStats (slug, status, cohort_title, closes_at, trades, traders, volume, yes_price) AS
SELECT m.slug, m.status, m.cohort_title, m.closes_at,
       COUNT(t.handle), COUNT(DISTINCT t.handle), COALESCE(SUM(t.cost), 0),
       (SELECT MAX(t2.price_after) FROM Trade t2
        WHERE t2.market_slug = m.slug
          AND t2.created_at = (SELECT MAX(t3.created_at) FROM Trade t3 WHERE t3.market_slug = m.slug))
FROM Market m LEFT JOIN Trade t ON t.market_slug = m.slug
GROUP BY m.slug, m.status, m.cohort_title, m.closes_at;

-- View 2: the open markets traders can bet on. Simple selection over one table, WITH CHECK OPTION.
CREATE VIEW OpenMarket AS
SELECT slug, question, metric, threshold_pct, rule_region, rule_field, rule_salary_band,
       deadline, opens_at, closes_at, status, cohort_title, frozen_at
FROM Market
WHERE status = 'open'
WITH CHECK OPTION;

-- Query on View 1: open markets with above-average volume, busiest first.
SELECT slug, trades, traders, volume, yes_price
FROM MarketStats
WHERE status = 'open'
  AND volume > (SELECT AVG(volume) FROM MarketStats WHERE status = 'open')
ORDER BY volume DESC;

-- Query on View 2: how many open markets each cohort has, and the nearest closing date.
SELECT cohort_title, COUNT(*) AS open_markets, MIN(closes_at) AS next_close
FROM OpenMarket
GROUP BY cohort_title
ORDER BY open_markets DESC, cohort_title;

-- Modifying View 1 (fails: it has GROUP BY, aggregates and a subquery in the select list).
INSERT INTO MarketStats (slug, status, cohort_title, closes_at, trades, traders, volume, yes_price)
VALUES ('fake-market', 'open', 'ML Engineers 2027', TIMESTAMP '2027-08-01 00:00:00', 0, 0, 0, 0.5);
UPDATE MarketStats SET volume = 0 WHERE slug = 'ml-engineers-2026-employed-41-2026';

-- Modifying View 2 (works: one base table, no aggregates, every NOT NULL column of Market without a
-- default is in the view; outcome is left NULL).
INSERT INTO OpenMarket (slug, question, metric, threshold_pct, rule_region, rule_field, rule_salary_band,
                        deadline, opens_at, closes_at, status, cohort_title, frozen_at)
VALUES ('ml-engineers-2027-employed-toronto-35-2027',
        'Will at least 35% of ML Engineers 2027 be employed in Toronto by Sep 1, 2027?',
        'employed', 35, 'Toronto', NULL, NULL, DATE '2027-09-01',
        TIMESTAMP '2026-11-21 09:00:00', TIMESTAMP '2027-08-01 00:00:00', 'open',
        'ML Engineers 2027', TIMESTAMP '2026-09-21 12:20:15');
SELECT slug, status, outcome FROM Market WHERE slug = 'ml-engineers-2027-employed-toronto-35-2027';

-- ...but WITH CHECK OPTION rejects a row the view could not show, and an update that moves a row out of it.
INSERT INTO OpenMarket (slug, question, metric, threshold_pct, rule_region, rule_field, rule_salary_band,
                        deadline, opens_at, closes_at, status, cohort_title, frozen_at)
VALUES ('ml-engineers-2027-grad-school-10-2027',
        'Will at least 10% of ML Engineers 2027 be in grad school by Sep 1, 2027?',
        'grad_school', 10, NULL, NULL, NULL, DATE '2027-09-01',
        TIMESTAMP '2026-11-21 09:00:00', TIMESTAMP '2027-08-01 00:00:00', 'closed',
        'ML Engineers 2027', TIMESTAMP '2026-09-21 12:20:15');
UPDATE OpenMarket SET status = 'closed' WHERE slug = 'ml-engineers-2027-employed-toronto-35-2027';

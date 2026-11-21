-- SE 3309 Assignment 3, Group 23 - talentmkt
-- ex3.sql: three different kinds of INSERT into one relation (MemberOf).
-- Cohort 'Data Platform Engineers 2027' was loaded as a proposed cohort with its Requires and
-- CohortGradYear rows but no members, so these inserts build its membership.
USE talentmkt;

-- 3.1 Single-row INSERT with an explicit column list (an admin adds one student by hand).
INSERT INTO MemberOf (handle, cohort_title, computed_at)
VALUES ('alex37', 'Data Platform Engineers 2027', TIMESTAMP '2026-11-20 21:00:00');

-- 3.2 Multi-row INSERT, columns in a different order, timestamp taken from the session clock.
INSERT INTO MemberOf (cohort_title, handle, computed_at)
VALUES ('Data Platform Engineers 2027', 'alex788',     CURRENT_TIMESTAMP(6)),
       ('Data Platform Engineers 2027', 'alex_chen',   CURRENT_TIMESTAMP(6)),
       ('Data Platform Engineers 2027', 'alpha_alpha', CURRENT_TIMESTAMP(6));

-- 3.3 INSERT ... SELECT: the real membership rule (A1 "Cohort Creation and Membership").
-- A student qualifies when their grad year is one of the cohort's grad years and, for EVERY skill the
-- cohort requires, the sum of Develops.weight over their completed courses reaches min_weighted_courses.
-- Completed has no university column (A2 4.1.4), so the school comes from Student.
-- Students added by 3.1 and 3.2 are skipped with NOT EXISTS.
INSERT INTO MemberOf (handle, cohort_title, computed_at)
SELECT s.handle, r.cohort_title, CURRENT_TIMESTAMP(6)
FROM Student s
     JOIN CohortGradYear g ON g.grad_year = s.grad_year
     JOIN Requires r       ON r.cohort_title = g.cohort_title
     LEFT JOIN (SELECT c.handle, d.skill_label, SUM(d.weight) AS total
                FROM Completed c
                     JOIN Student st ON st.handle = c.handle
                     JOIN Develops d ON d.university_name = st.university_name
                                    AND d.subject = c.subject AND d.number = c.number
                GROUP BY c.handle, d.skill_label) t
            ON t.handle = s.handle AND t.skill_label = r.skill_label
WHERE r.cohort_title = 'Data Platform Engineers 2027'
  AND NOT EXISTS (SELECT * FROM MemberOf mo
                  WHERE mo.handle = s.handle AND mo.cohort_title = r.cohort_title)
GROUP BY s.handle, r.cohort_title
HAVING SUM(CASE WHEN t.total >= r.min_weighted_courses THEN 1 ELSE 0 END)
       = (SELECT COUNT(*) FROM Requires r2 WHERE r2.cohort_title = r.cohort_title);

-- Resulting relation (MemberOf has ~5,700 rows in total, so we show this cohort's part of it).
SELECT * FROM MemberOf WHERE cohort_title = 'Data Platform Engineers 2027' ORDER BY computed_at, handle;
SELECT COUNT(*) AS memberof_rows FROM MemberOf;

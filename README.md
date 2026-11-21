# SE 3309 Assignment 3 – Group 23 (talentmkt)

- `DESC/` – report with every statement and the server's response
- `SQL/` – ex2.sql (schema, indexes, triggers, DESCRIBEs), ex3.sql, ex5.sql, ex6.sql, ex7.sql
- `SRC/` – generate_data.py (data fabricator), talentmkt_data.sql (its output), ex3_candidates.txt
- `DUMP/` – talentmkt_dump.sql (export right after the bulk load)

Run order (MySQL 8.0.16+):
```
mysql -u root -p < SQL/ex2.sql
mysql -u root -p talentmkt < SRC/talentmkt_data.sql     # or: mysql -u root -p < DUMP/talentmkt_dump.sql
mysql -u root -p < SQL/ex3.sql
mysql -u root -p < SQL/ex5.sql
mysql -u root -p < SQL/ex6.sql
mysql -u root -p < SQL/ex7.sql
```
Regenerate data: `cd SRC && python3 generate_data.py talentmkt_data.sql`

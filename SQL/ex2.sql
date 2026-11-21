-- SE 3309 Assignment 3, Group 23 - talentmkt
-- ex2.sql: database schema (final BCNF schema from Assignment 2, Section 4.1.6)
-- 20 relations + constraints, indexes and triggers. Target: MySQL 8.0.16+ (CHECK constraints enforced).

DROP DATABASE IF EXISTS talentmkt;
CREATE DATABASE talentmkt;
USE talentmkt;

-- ---------------------------------------------------------------- Users
CREATE TABLE User (
    handle        VARCHAR(30)  NOT NULL,
    email_local   VARCHAR(64)  NOT NULL,
    email_domain  VARCHAR(64)  NOT NULL,
    created_at    DATETIME(6)  NOT NULL,
    CONSTRAINT pk_user PRIMARY KEY (handle),
    CONSTRAINT ak_user_email UNIQUE (email_local, email_domain),
    CONSTRAINT ck_user_handle CHECK (CHAR_LENGTH(handle) >= 3)
);

CREATE TABLE University (
    name      VARCHAR(80) NOT NULL,
    city      VARCHAR(50) NOT NULL,
    province  CHAR(2)     NOT NULL,
    CONSTRAINT pk_university PRIMARY KEY (name),
    CONSTRAINT ck_university_province CHECK (province IN
        ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT'))
);

CREATE TABLE UniversityDomain (
    email_domain     VARCHAR(64) NOT NULL,
    university_name  VARCHAR(80) NOT NULL,
    CONSTRAINT pk_universitydomain PRIMARY KEY (email_domain),
    CONSTRAINT fk_ud_university FOREIGN KEY (university_name)
        REFERENCES University (name) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Student (
    handle           VARCHAR(30)  NOT NULL,
    program          VARCHAR(60)  NOT NULL,
    grad_year        SMALLINT     NOT NULL,
    verified_at      DATETIME(6)  NOT NULL,
    consent_at       DATETIME(6)  NOT NULL,
    university_name  VARCHAR(80)  NOT NULL,
    CONSTRAINT pk_student PRIMARY KEY (handle),
    CONSTRAINT fk_student_user FOREIGN KEY (handle)
        REFERENCES User (handle) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_student_university FOREIGN KEY (university_name)
        REFERENCES University (name) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_student_gradyear CHECK (grad_year BETWEEN 2000 AND 2040),
    CONSTRAINT ck_student_consent CHECK (consent_at >= verified_at)
);

CREATE TABLE Admin (
    handle      VARCHAR(30) NOT NULL,
    granted_at  DATETIME(6) NOT NULL,
    CONSTRAINT pk_admin PRIMARY KEY (handle),
    CONSTRAINT fk_admin_user FOREIGN KEY (handle)
        REFERENCES User (handle) ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------- Academic side
CREATE TABLE Course (
    university_name  VARCHAR(80)  NOT NULL,
    subject          VARCHAR(8)   NOT NULL,
    number           CHAR(4)      NOT NULL,
    title            VARCHAR(100) NOT NULL,
    CONSTRAINT pk_course PRIMARY KEY (university_name, subject, number),
    CONSTRAINT fk_course_university FOREIGN KEY (university_name)
        REFERENCES University (name) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_course_number CHECK (number BETWEEN '1000' AND '9999')
);

CREATE TABLE SkillTag (
    label     VARCHAR(40) NOT NULL,
    category  VARCHAR(30) NOT NULL DEFAULT 'general',
    CONSTRAINT pk_skilltag PRIMARY KEY (label)
);

CREATE TABLE Completed (
    handle      VARCHAR(30) NOT NULL,
    subject     VARCHAR(8)  NOT NULL,
    number      CHAR(4)     NOT NULL,
    term        CHAR(5)     NOT NULL,          -- e.g. 2025F, 2026W, 2026S
    grade_band  VARCHAR(2)  NOT NULL,
    CONSTRAINT pk_completed PRIMARY KEY (handle, subject, number),
    CONSTRAINT fk_completed_student FOREIGN KEY (handle)
        REFERENCES Student (handle) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_completed_grade CHECK (grade_band IN ('A+','A','B','C','D','F')),
    CONSTRAINT ck_completed_term CHECK (SUBSTRING(term, 5, 1) IN ('F','W','S'))
);

CREATE TABLE Develops (
    university_name  VARCHAR(80)  NOT NULL,
    subject          VARCHAR(8)   NOT NULL,
    number           CHAR(4)      NOT NULL,
    skill_label      VARCHAR(40)  NOT NULL,
    weight           DECIMAL(3,2) NOT NULL,
    CONSTRAINT pk_develops PRIMARY KEY (university_name, subject, number, skill_label),
    CONSTRAINT fk_develops_course FOREIGN KEY (university_name, subject, number)
        REFERENCES Course (university_name, subject, number) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_develops_skill FOREIGN KEY (skill_label)
        REFERENCES SkillTag (label) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_develops_weight CHECK (weight > 0 AND weight <= 1)
);

-- ---------------------------------------------------------------- Cohorts
CREATE TABLE Cohort (
    title         VARCHAR(80) NOT NULL,
    status        VARCHAR(10) NOT NULL DEFAULT 'proposed',
    activated_at  DATETIME(6) NULL,
    defined_by    VARCHAR(30) NOT NULL,
    CONSTRAINT pk_cohort PRIMARY KEY (title),
    CONSTRAINT fk_cohort_admin FOREIGN KEY (defined_by)
        REFERENCES Admin (handle) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_cohort_status CHECK (status IN ('proposed','active','retired')),
    CONSTRAINT ck_cohort_activated CHECK ((status = 'proposed' AND activated_at IS NULL)
                                       OR (status <> 'proposed' AND activated_at IS NOT NULL))
);

CREATE TABLE CohortGradYear (
    cohort_title  VARCHAR(80) NOT NULL,
    grad_year     SMALLINT    NOT NULL,
    CONSTRAINT pk_cohortgradyear PRIMARY KEY (cohort_title, grad_year),
    CONSTRAINT fk_cgy_cohort FOREIGN KEY (cohort_title)
        REFERENCES Cohort (title) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_cgy_year CHECK (grad_year BETWEEN 2000 AND 2040)
);

CREATE TABLE Requires (
    cohort_title          VARCHAR(80)  NOT NULL,
    skill_label           VARCHAR(40)  NOT NULL,
    min_weighted_courses  DECIMAL(4,2) NOT NULL,
    CONSTRAINT pk_requires PRIMARY KEY (cohort_title, skill_label),
    CONSTRAINT fk_requires_cohort FOREIGN KEY (cohort_title)
        REFERENCES Cohort (title) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_requires_skill FOREIGN KEY (skill_label)
        REFERENCES SkillTag (label) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_requires_min CHECK (min_weighted_courses > 0)
);

CREATE TABLE MemberOf (
    handle        VARCHAR(30) NOT NULL,
    cohort_title  VARCHAR(80) NOT NULL,
    computed_at   DATETIME(6) NOT NULL,
    CONSTRAINT pk_memberof PRIMARY KEY (handle, cohort_title),
    CONSTRAINT fk_memberof_student FOREIGN KEY (handle)
        REFERENCES Student (handle) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_memberof_cohort FOREIGN KEY (cohort_title)
        REFERENCES Cohort (title) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE CohortSnapshot (
    cohort_title  VARCHAR(80) NOT NULL,
    frozen_at     DATETIME(6) NOT NULL,
    member_count  INT         NOT NULL,
    CONSTRAINT pk_cohortsnapshot PRIMARY KEY (cohort_title, frozen_at),
    CONSTRAINT fk_snapshot_cohort FOREIGN KEY (cohort_title)
        REFERENCES Cohort (title) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_snapshot_size CHECK (member_count >= 25)
);

CREATE TABLE FrozenMember (
    cohort_title  VARCHAR(80) NOT NULL,
    frozen_at     DATETIME(6) NOT NULL,
    handle        VARCHAR(30) NOT NULL,
    member_no     INT         NOT NULL,
    CONSTRAINT pk_frozenmember PRIMARY KEY (cohort_title, frozen_at, handle),
    CONSTRAINT ak_frozenmember_no UNIQUE (cohort_title, frozen_at, member_no),
    CONSTRAINT fk_fm_snapshot FOREIGN KEY (cohort_title, frozen_at)
        REFERENCES CohortSnapshot (cohort_title, frozen_at) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_fm_student FOREIGN KEY (handle)
        REFERENCES Student (handle) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_fm_no CHECK (member_no >= 1)
);

-- ---------------------------------------------------------------- Market side
CREATE TABLE Market (
    slug              VARCHAR(60)  NOT NULL,
    question          VARCHAR(200) NOT NULL,
    metric            VARCHAR(12)  NOT NULL,
    threshold_pct     DECIMAL(5,2) NOT NULL,
    rule_region       VARCHAR(40)  NULL,
    rule_field        VARCHAR(40)  NULL,
    rule_salary_band  VARCHAR(10)  NULL,
    deadline          DATE         NOT NULL,
    opens_at          DATETIME(6)  NOT NULL,
    closes_at         DATETIME(6)  NOT NULL,
    status            VARCHAR(10)  NOT NULL DEFAULT 'open',
    outcome           VARCHAR(3)   NULL,
    cohort_title      VARCHAR(80)  NOT NULL,
    frozen_at         DATETIME(6)  NOT NULL,
    CONSTRAINT pk_market PRIMARY KEY (slug),
    CONSTRAINT fk_market_snapshot FOREIGN KEY (cohort_title, frozen_at)
        REFERENCES CohortSnapshot (cohort_title, frozen_at) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_market_metric CHECK (metric IN ('employed','grad_school','searching')),
    CONSTRAINT ck_market_threshold CHECK (threshold_pct > 0 AND threshold_pct <= 100),
    CONSTRAINT ck_market_salary CHECK (rule_salary_band IS NULL
        OR rule_salary_band IN ('<60k','60-80k','80-100k','100-130k','130k+')),
    CONSTRAINT ck_market_schedule CHECK (closes_at > opens_at),
    CONSTRAINT ck_market_status CHECK (status IN ('open','closed','resolved','voided')),
    CONSTRAINT ck_market_outcome CHECK ((status = 'resolved' AND outcome IN ('yes','no'))
                                     OR (status <> 'resolved' AND outcome IS NULL))
);

CREATE TABLE Trade (
    handle       VARCHAR(30)   NOT NULL,
    market_slug  VARCHAR(60)   NOT NULL,
    created_at   DATETIME(6)   NOT NULL,
    side         VARCHAR(3)    NOT NULL,
    action       VARCHAR(4)    NOT NULL,
    shares       DECIMAL(10,2) NOT NULL,
    cost         DECIMAL(10,2) NOT NULL,   -- credits paid (buy) or received (sell), before fee
    fee          DECIMAL(10,2) NOT NULL,
    price_after  DECIMAL(5,4)  NOT NULL,   -- YES price after the trade
    CONSTRAINT pk_trade PRIMARY KEY (handle, market_slug, created_at),
    CONSTRAINT fk_trade_user FOREIGN KEY (handle)
        REFERENCES User (handle) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trade_market FOREIGN KEY (market_slug)
        REFERENCES Market (slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_trade_side CHECK (side IN ('yes','no')),
    CONSTRAINT ck_trade_action CHECK (action IN ('buy','sell')),
    CONSTRAINT ck_trade_shares CHECK (shares > 0),
    CONSTRAINT ck_trade_cost CHECK (cost >= 0 AND fee >= 0),
    CONSTRAINT ck_trade_price CHECK (price_after > 0 AND price_after < 1)
);

CREATE TABLE OutcomeReport (
    handle       VARCHAR(30) NOT NULL,
    reported_at  DATETIME(6) NOT NULL,
    status       VARCHAR(12) NOT NULL,
    job_region   VARCHAR(40) NULL,
    job_field    VARCHAR(40) NULL,
    salary_band  VARCHAR(10) NULL,
    CONSTRAINT pk_outcomereport PRIMARY KEY (handle, reported_at),
    CONSTRAINT fk_report_student FOREIGN KEY (handle)
        REFERENCES Student (handle) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_report_status CHECK (status IN ('employed','searching','grad_school','other')),
    CONSTRAINT ck_report_salary CHECK (salary_band IS NULL
        OR (status = 'employed' AND salary_band IN ('<60k','60-80k','80-100k','100-130k','130k+')))
);

CREATE TABLE LedgerEntry (
    handle              VARCHAR(30)   NOT NULL,
    entry_no            INT           NOT NULL,
    amount              DECIMAL(12,2) NOT NULL,
    kind                VARCHAR(7)    NOT NULL,
    created_at          DATETIME(6)   NOT NULL,
    trade_market_slug   VARCHAR(60)   NULL,
    trade_created_at    DATETIME(6)   NULL,
    payout_market_slug  VARCHAR(60)   NULL,
    CONSTRAINT pk_ledgerentry PRIMARY KEY (handle, entry_no),
    CONSTRAINT fk_ledger_user FOREIGN KEY (handle)
        REFERENCES User (handle) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ledger_trade FOREIGN KEY (handle, trade_market_slug, trade_created_at)
        REFERENCES Trade (handle, market_slug, created_at) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ledger_payout FOREIGN KEY (payout_market_slug)
        REFERENCES Market (slug) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_ledger_entryno CHECK (entry_no >= 1),
    CONSTRAINT ck_ledger_kind CHECK (kind IN ('signup','trade','fee','payout','refund')),
    -- the kind decides which links are filled (promised in A2, Section 4.1.1)
    CONSTRAINT ck_ledger_links CHECK (
        (kind IN ('signup','refund') AND trade_market_slug IS NULL AND trade_created_at IS NULL
                                     AND payout_market_slug IS NULL)
     OR (kind IN ('trade','fee')     AND trade_market_slug IS NOT NULL AND trade_created_at IS NOT NULL
                                     AND payout_market_slug IS NULL)
     OR (kind = 'payout'             AND trade_market_slug IS NULL AND trade_created_at IS NULL
                                     AND payout_market_slug IS NOT NULL)),
    CONSTRAINT ck_ledger_sign CHECK (
        (kind = 'signup' AND amount = 1000) OR (kind = 'fee' AND amount <= 0)
     OR (kind IN ('payout','refund') AND amount > 0) OR kind = 'trade')
);

CREATE TABLE Position (
    handle        VARCHAR(30)   NOT NULL,
    market_slug   VARCHAR(60)   NOT NULL,
    yes_shares    DECIMAL(10,2) NOT NULL DEFAULT 0,
    no_shares     DECIMAL(10,2) NOT NULL DEFAULT 0,
    cost_basis    DECIMAL(12,2) NOT NULL DEFAULT 0,
    realized_pnl  DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT pk_position PRIMARY KEY (handle, market_slug),
    CONSTRAINT fk_position_user FOREIGN KEY (handle)
        REFERENCES User (handle) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_position_market FOREIGN KEY (market_slug)
        REFERENCES Market (slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_position_shares CHECK (yes_shares >= 0 AND no_shares >= 0 AND cost_basis >= 0)
);

-- ---------------------------------------------------------------- Secondary indexes
-- Reverse lookups that the primary keys don't cover.
CREATE INDEX ix_student_university ON Student (university_name);
CREATE INDEX ix_develops_skill     ON Develops (skill_label);
CREATE INDEX ix_memberof_cohort    ON MemberOf (cohort_title);
CREATE INDEX ix_fm_handle          ON FrozenMember (handle);
CREATE INDEX ix_market_status      ON Market (status, closes_at);
CREATE INDEX ix_trade_market_time  ON Trade (market_slug, created_at);
CREATE INDEX ix_report_status      ON OutcomeReport (status, job_region);

-- ---------------------------------------------------------------- Triggers
DELIMITER //

-- A2 4.1.4: Completed lost its FK to Course, so check (Student.university_name, subject, number) exists.
CREATE TRIGGER trg_completed_course_ins BEFORE INSERT ON Completed
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT * FROM Student s JOIN Course c ON c.university_name = s.university_name
                   WHERE s.handle = NEW.handle AND c.subject = NEW.subject AND c.number = NEW.number) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Completed: course is not offered by the student''s university';
    END IF;
END//

CREATE TRIGGER trg_completed_course_upd BEFORE UPDATE ON Completed
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT * FROM Student s JOIN Course c ON c.university_name = s.university_name
                   WHERE s.handle = NEW.handle AND c.subject = NEW.subject AND c.number = NEW.number) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Completed: course is not offered by the student''s university';
    END IF;
END//

-- Trade rules from A1 "Trade Execution": inside the market's schedule, insider rule, enough balance,
-- and you can't sell shares you don't hold.
CREATE TRIGGER trg_trade_check BEFORE INSERT ON Trade
FOR EACH ROW
BEGIN
    DECLARE v_opens DATETIME(6);
    DECLARE v_closes DATETIME(6);
    DECLARE v_status VARCHAR(10);
    DECLARE v_held DECIMAL(10,2);

    SELECT opens_at, closes_at, status INTO v_opens, v_closes, v_status
    FROM Market WHERE slug = NEW.market_slug;

    IF v_status = 'voided' OR NEW.created_at < v_opens OR NEW.created_at > v_closes THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trade: market is not open for trading at this time';
    END IF;

    IF EXISTS (SELECT * FROM FrozenMember f JOIN Market m
                 ON m.cohort_title = f.cohort_title AND m.frozen_at = f.frozen_at
               WHERE m.slug = NEW.market_slug AND f.handle = NEW.handle) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trade: insider rule - trader is in this market''s cohort snapshot';
    END IF;

    IF NEW.action = 'buy' AND
       (SELECT COALESCE(SUM(amount), 0) FROM LedgerEntry WHERE handle = NEW.handle) < NEW.cost + NEW.fee THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trade: insufficient balance';
    END IF;

    IF NEW.action = 'sell' THEN
        SELECT CASE WHEN NEW.side = 'yes' THEN yes_shares ELSE no_shares END INTO v_held
        FROM Position WHERE handle = NEW.handle AND market_slug = NEW.market_slug;
        IF v_held IS NULL OR v_held < NEW.shares THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trade: cannot sell more shares than held';
        END IF;
    END IF;
END//

-- A2 4.1.1 / A1: Position and the trade + fee ledger entries are written in the same transaction as the Trade.
CREATE TRIGGER trg_trade_apply AFTER INSERT ON Trade
FOR EACH ROW
BEGIN
    DECLARE v_next INT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_basis DECIMAL(12,2);
    DECLARE v_removed DECIMAL(12,2);

    IF NOT EXISTS (SELECT * FROM Position WHERE handle = NEW.handle AND market_slug = NEW.market_slug) THEN
        INSERT INTO Position (handle, market_slug) VALUES (NEW.handle, NEW.market_slug);
    END IF;

    IF NEW.action = 'buy' THEN
        UPDATE Position
        SET yes_shares = yes_shares + CASE WHEN NEW.side = 'yes' THEN NEW.shares ELSE 0 END,
            no_shares  = no_shares  + CASE WHEN NEW.side = 'no'  THEN NEW.shares ELSE 0 END,
            cost_basis = cost_basis + NEW.cost
        WHERE handle = NEW.handle AND market_slug = NEW.market_slug;
    ELSE
        -- average-cost accounting: the sold shares take their share of the cost basis with them
        SELECT yes_shares + no_shares, cost_basis INTO v_total, v_basis
        FROM Position WHERE handle = NEW.handle AND market_slug = NEW.market_slug;
        SET v_removed = ROUND(v_basis * NEW.shares / v_total, 2);
        UPDATE Position
        SET yes_shares   = yes_shares - CASE WHEN NEW.side = 'yes' THEN NEW.shares ELSE 0 END,
            no_shares    = no_shares  - CASE WHEN NEW.side = 'no'  THEN NEW.shares ELSE 0 END,
            cost_basis   = cost_basis - v_removed,
            realized_pnl = realized_pnl + NEW.cost - v_removed
        WHERE handle = NEW.handle AND market_slug = NEW.market_slug;
    END IF;

    SELECT COALESCE(MAX(entry_no), 0) + 1 INTO v_next FROM LedgerEntry WHERE handle = NEW.handle;

    INSERT INTO LedgerEntry (handle, entry_no, amount, kind, created_at, trade_market_slug, trade_created_at)
    VALUES (NEW.handle, v_next,
            CASE WHEN NEW.action = 'buy' THEN -NEW.cost ELSE NEW.cost END,
            'trade', NEW.created_at, NEW.market_slug, NEW.created_at);

    IF NEW.fee > 0 THEN
        INSERT INTO LedgerEntry (handle, entry_no, amount, kind, created_at, trade_market_slug, trade_created_at)
        VALUES (NEW.handle, v_next + 1, -NEW.fee, 'fee', NEW.created_at, NEW.market_slug, NEW.created_at);
    END IF;
END//

-- A1: the ledger is append-only. No updates, no deletes.
CREATE TRIGGER trg_ledger_no_update BEFORE UPDATE ON LedgerEntry
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LedgerEntry is append-only (UPDATE not allowed)';
END//

CREATE TRIGGER trg_ledger_no_delete BEFORE DELETE ON LedgerEntry
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LedgerEntry is append-only (DELETE not allowed)';
END//

-- A2: CohortSnapshot.member_count is stored on purpose; make sure it can never disagree with FrozenMember.
-- Snapshots are frozen: no FrozenMember rows can be added once the count is reached.
CREATE TRIGGER trg_frozenmember_cap BEFORE INSERT ON FrozenMember
FOR EACH ROW
BEGIN
    IF NEW.member_no > (SELECT member_count FROM CohortSnapshot
                        WHERE cohort_title = NEW.cohort_title AND frozen_at = NEW.frozen_at) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FrozenMember: snapshot is already full';
    END IF;
END//

DELIMITER ;

-- DESCRIBE every relation
DESCRIBE User;
DESCRIBE Student;
DESCRIBE Admin;
DESCRIBE University;
DESCRIBE UniversityDomain;
DESCRIBE Course;
DESCRIBE SkillTag;
DESCRIBE Completed;
DESCRIBE Develops;
DESCRIBE Cohort;
DESCRIBE CohortGradYear;
DESCRIBE Requires;
DESCRIBE MemberOf;
DESCRIBE CohortSnapshot;
DESCRIBE FrozenMember;
DESCRIBE Market;
DESCRIBE Trade;
DESCRIBE OutcomeReport;
DESCRIBE LedgerEntry;
DESCRIBE Position;

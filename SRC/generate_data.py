#!/usr/bin/env python3
"""
SE 3309 Assignment 3, Group 23 - talentmkt data fabricator.

Writes SRC/talentmkt_data.sql, a script of INSERT statements that loads every relation
of the schema in SQL/ex2.sql. Deterministic (fixed random seed), so every run produces the same data.

How joinability is guaranteed: parent keys are generated first and kept in Python lists/dicts,
and child rows only ever pick keys from those lists (e.g. Completed picks from the courses
of the student's own university, Trade picks traders that are not in the market's snapshot).

Rules enforced by the triggers in ex2.sql are simulated here so the load never fails:
balance >= cost + fee for buys, no selling more than you hold, trades inside the market
schedule, insider rule. Position rows and trade/fee LedgerEntry rows are NOT generated here,
because the AFTER INSERT trigger on Trade writes them. The script mirrors the trigger's
entry_no numbering so the payout/refund ledger rows it writes at the end line up.

Usage:  python3 generate_data.py  [output_path]
"""
import random, sys, re
from datetime import datetime, timedelta, date
from decimal import Decimal, ROUND_HALF_UP

random.seed(3309)
NOW = datetime(2026, 11, 20, 12, 0, 0)
OUT = sys.argv[1] if len(sys.argv) > 1 else "talentmkt_data.sql"
D2 = Decimal("0.01")

def q(v):
    """SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, (int, Decimal)):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, datetime):
        return "'" + v.strftime("%Y-%m-%d %H:%M:%S.%f") + "'"
    if isinstance(v, date):
        return "'" + v.isoformat() + "'"
    return "'" + str(v).replace("'", "''") + "'"

def rand_dt(a, b):
    span = (b - a).total_seconds()
    return a + timedelta(seconds=random.random() * span)

out_lines = ["-- talentmkt generated data (SRC/generate_data.py, seed 3309)", "USE talentmkt;", "SET autocommit = 0;"]

def emit(table, cols, rows, batch=500):
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        vals = ",\n".join("(" + ",".join(q(v) for v in r) + ")" for r in chunk)
        out_lines.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n{vals};")
    out_lines.append("COMMIT;")
    counts[table] = counts.get(table, 0) + len(rows)

counts = {}

# ------------------------------------------------------------------ universities
UNIS = [
    ("Western University", "London", "ON", ["uwo.ca", "westernu.ca"], {"se": "SE", "cs": "CS", "ece": "ECE", "stat": "STATS", "math": "MATH", "bus": "BUS"}),
    ("University of Waterloo", "Waterloo", "ON", ["uwaterloo.ca"], {"se": "SE", "cs": "CS", "ece": "ECE", "stat": "STAT", "math": "MATH", "bus": "AFM"}),
    ("University of Toronto", "Toronto", "ON", ["utoronto.ca", "mail.utoronto.ca"], {"se": "CSC", "cs": "CSC", "ece": "ECE", "stat": "STA", "math": "MAT", "bus": "RSM"}),
    ("McMaster University", "Hamilton", "ON", ["mcmaster.ca"], {"se": "SFWRENG", "cs": "COMPSCI", "ece": "ELECENG", "stat": "STATS", "math": "MATH", "bus": "COMMERCE"}),
    ("Queen's University", "Kingston", "ON", ["queensu.ca"], {"se": "CISC", "cs": "CISC", "ece": "ELEC", "stat": "STAT", "math": "MATH", "bus": "COMM"}),
    ("University of Ottawa", "Ottawa", "ON", ["uottawa.ca"], {"se": "SEG", "cs": "CSI", "ece": "ELG", "stat": "MAT", "math": "MAT", "bus": "ADM"}),
    ("Carleton University", "Ottawa", "ON", ["carleton.ca", "cmail.carleton.ca"], {"se": "SYSC", "cs": "COMP", "ece": "ELEC", "stat": "STAT", "math": "MATH", "bus": "BUSI"}),
    ("York University", "Toronto", "ON", ["yorku.ca", "my.yorku.ca"], {"se": "EECS", "cs": "EECS", "ece": "EECS", "stat": "MATH", "math": "MATH", "bus": "ADMS"}),
    ("Toronto Metropolitan University", "Toronto", "ON", ["torontomu.ca"], {"se": "CPS", "cs": "CPS", "ece": "ELE", "stat": "MTH", "math": "MTH", "bus": "BUS"}),
    ("University of Guelph", "Guelph", "ON", ["uoguelph.ca"], {"se": "CIS", "cs": "CIS", "ece": "ENGG", "stat": "STAT", "math": "MATH", "bus": "ACCT"}),
    ("University of Windsor", "Windsor", "ON", ["uwindsor.ca"], {"se": "COMP", "cs": "COMP", "ece": "ELEC", "stat": "STAT", "math": "MATH", "bus": "BUSA"}),
    ("University of British Columbia", "Vancouver", "BC", ["ubc.ca", "student.ubc.ca"], {"se": "CPSC", "cs": "CPSC", "ece": "ELEC", "stat": "STAT", "math": "MATH", "bus": "COMM"}),
    ("Simon Fraser University", "Burnaby", "BC", ["sfu.ca"], {"se": "CMPT", "cs": "CMPT", "ece": "ENSC", "stat": "STAT", "math": "MATH", "bus": "BUS"}),
    ("McGill University", "Montreal", "QC", ["mcgill.ca", "mail.mcgill.ca"], {"se": "ECSE", "cs": "COMP", "ece": "ECSE", "stat": "MATH", "math": "MATH", "bus": "MGCR"}),
    ("Concordia University", "Montreal", "QC", ["concordia.ca"], {"se": "SOEN", "cs": "COMP", "ece": "COEN", "stat": "STAT", "math": "MATH", "bus": "COMM"}),
    ("University of Calgary", "Calgary", "AB", ["ucalgary.ca"], {"se": "SENG", "cs": "CPSC", "ece": "ENEL", "stat": "STAT", "math": "MATH", "bus": "ACCT"}),
    ("University of Alberta", "Edmonton", "AB", ["ualberta.ca"], {"se": "ECE", "cs": "CMPUT", "ece": "ECE", "stat": "STAT", "math": "MATH", "bus": "BUS"}),
    ("Dalhousie University", "Halifax", "NS", ["dal.ca"], {"se": "CSCI", "cs": "CSCI", "ece": "ECED", "stat": "STAT", "math": "MATH", "bus": "COMM"}),
]
emit("University", ["name", "city", "province"], [(u[0], u[1], u[2]) for u in UNIS])
emit("UniversityDomain", ["email_domain", "university_name"], [(d, u[0]) for u in UNIS for d in u[3]])

# ------------------------------------------------------------------ skills
SKILLS = {
    "Python": "programming", "Java": "programming", "C++": "programming", "JavaScript": "programming",
    "SQL": "data", "Databases": "data", "Data Analysis": "data", "Statistics": "data",
    "Machine Learning": "ai", "Deep Learning": "ai", "NLP": "ai",
    "Operating Systems": "systems", "Networking": "systems", "Distributed Systems": "systems",
    "Cloud Computing": "systems", "Security": "systems",
    "Software Design": "software", "Testing": "software", "Requirements": "software",
    "Project Management": "software", "Web Development": "web", "Mobile Development": "web",
    "UI Design": "web", "Algorithms": "theory", "Linear Algebra": "math", "Probability": "math",
    "Embedded Systems": "hardware", "Digital Logic": "hardware", "Signal Processing": "hardware",
    "Finance": "business", "Accounting": "business", "Marketing": "business",
}
emit("SkillTag", ["label", "category"], list(SKILLS.items()))

# ------------------------------------------------------------------ course archetypes
# (dept, base number, title, {skill: weight}, programs that usually take it)
A = [
    ("cs", 1026, "Intro to Programming", {"Python": 0.8}, "ALL"),
    ("cs", 1027, "Programming Fundamentals II", {"Java": 0.7, "Algorithms": 0.3}, "SE CS CE DS"),
    ("cs", 2210, "Data Structures and Algorithms", {"Algorithms": 0.9, "Java": 0.3}, "SE CS CE DS"),
    ("cs", 2209, "Discrete Structures", {"Algorithms": 0.5, "Probability": 0.2}, "SE CS DS MATH"),
    ("se", 2203, "Software Design", {"Software Design": 0.9, "Java": 0.4}, "SE CS"),
    ("se", 2250, "Software Construction", {"Software Design": 0.5, "Testing": 0.5, "C++": 0.4}, "SE CE"),
    ("se", 3309, "Database Management Systems", {"SQL": 0.9, "Databases": 0.9}, "SE CS DS"),
    ("se", 3310, "Theoretical Foundations of SE", {"Algorithms": 0.6}, "SE"),
    ("se", 3316, "Web Technologies", {"Web Development": 0.9, "JavaScript": 0.8}, "SE CS"),
    ("se", 3350, "Software Engineering Design I", {"Software Design": 0.8, "Testing": 0.4}, "SE"),
    ("se", 3351, "Software Project Management", {"Project Management": 0.9}, "SE BUS"),
    ("se", 3352, "Software Requirements", {"Requirements": 0.9, "UI Design": 0.3}, "SE"),
    ("se", 3353, "Human-Computer Interaction", {"UI Design": 0.9}, "SE CS"),
    ("se", 4455, "Cloud Computing", {"Cloud Computing": 0.9, "Distributed Systems": 0.5}, "SE CS CE"),
    ("se", 4472, "Software Testing", {"Testing": 0.9}, "SE"),
    ("se", 4458, "Mobile App Development", {"Mobile Development": 0.9, "JavaScript": 0.3}, "SE CS"),
    ("cs", 3305, "Operating Systems", {"Operating Systems": 0.9, "C++": 0.5}, "SE CS CE"),
    ("cs", 3357, "Computer Networks", {"Networking": 0.9}, "CS CE EE"),
    ("cs", 3340, "Analysis of Algorithms", {"Algorithms": 0.9}, "CS DS"),
    ("cs", 4442, "Artificial Intelligence", {"Machine Learning": 0.6, "Python": 0.4}, "CS SE DS"),
    ("cs", 4452, "Machine Learning", {"Machine Learning": 1.0, "Python": 0.5, "Linear Algebra": 0.3}, "CS DS SE"),
    ("cs", 4453, "Deep Learning", {"Deep Learning": 1.0, "Machine Learning": 0.5}, "CS DS"),
    ("cs", 4460, "Natural Language Processing", {"NLP": 1.0, "Machine Learning": 0.4}, "CS DS"),
    ("cs", 4402, "Distributed Systems", {"Distributed Systems": 1.0, "Networking": 0.3}, "CS SE"),
    ("cs", 4430, "Computer Security", {"Security": 1.0, "Networking": 0.3}, "CS CE SE"),
    ("ece", 2277, "Digital Logic Systems", {"Digital Logic": 0.9}, "CE EE"),
    ("ece", 3375, "Microprocessors and Embedded Systems", {"Embedded Systems": 0.9, "C++": 0.4}, "CE EE"),
    ("ece", 3330, "Signals and Systems", {"Signal Processing": 0.9, "Linear Algebra": 0.3}, "EE CE"),
    ("ece", 4436, "Networking Principles", {"Networking": 0.8, "Security": 0.3}, "CE SE EE"),
    ("ece", 4438, "Embedded Machine Learning", {"Machine Learning": 0.6, "Embedded Systems": 0.6}, "CE EE"),
    ("stat", 2244, "Probability and Statistics", {"Statistics": 0.8, "Probability": 0.7}, "ALL"),
    ("stat", 3860, "Regression Analysis", {"Statistics": 0.9, "Data Analysis": 0.6}, "DS MATH"),
    ("stat", 3850, "Data Analysis with R", {"Data Analysis": 0.9, "Statistics": 0.4}, "DS MATH BUS"),
    ("stat", 4864, "Statistical Learning", {"Machine Learning": 0.7, "Statistics": 0.6}, "DS MATH"),
    ("math", 1600, "Linear Algebra I", {"Linear Algebra": 0.9}, "ALL"),
    ("math", 2155, "Mathematical Structures", {"Algorithms": 0.3, "Probability": 0.3}, "MATH CS"),
    ("bus", 2257, "Accounting and Business Analysis", {"Accounting": 0.9}, "BUS"),
    ("bus", 3301, "Corporate Finance", {"Finance": 1.0}, "BUS MATH"),
    ("bus", 3323, "Marketing Management", {"Marketing": 0.9}, "BUS"),
    ("bus", 3399, "Business Analytics", {"Data Analysis": 0.7, "SQL": 0.4}, "BUS DS"),
]
PROGRAMS = {
    "SE": "Software Engineering", "CS": "Computer Science", "CE": "Computer Engineering",
    "EE": "Electrical Engineering", "DS": "Data Science", "MATH": "Mathematics", "BUS": "Business Administration",
}
PROGRAM_WEIGHTS = [("SE", 26), ("CS", 30), ("CE", 14), ("EE", 7), ("DS", 12), ("MATH", 5), ("BUS", 6)]

courses = []          # (uni, subject, number, title)
uni_courses = {}      # uni -> list of (subject, number, archetype)
develops = []
for u in UNIS:
    name, smap = u[0], u[4]
    used = set()
    lst = []
    for arch in A:
        if random.random() < 0.12:           # each school skips a few courses
            continue
        subj = smap[arch[0]]
        base = arch[1]
        num = base
        if name != "Western University":       # other schools number courses differently, same year level
            num = (base // 1000) * 1000 + random.randint(0, 999)
        while (subj, num) in used:
            num = (base // 1000) * 1000 + random.randint(0, 999)
        used.add((subj, num))
        title = arch[2]
        courses.append((name, subj, str(num), title))
        lst.append((subj, str(num), arch))
        for sk, w in arch[3].items():
            w2 = max(0.1, min(1.0, w + random.choice([-0.1, 0, 0, 0.1])))
            develops.append((name, subj, str(num), sk, Decimal(str(round(w2, 2)))))
    uni_courses[name] = lst
emit("Course", ["university_name", "subject", "number", "title"], courses)
emit("Develops", ["university_name", "subject", "number", "skill_label", "weight"], develops)
dev_index = {}  # (uni, subj, num) -> {skill: weight}
for d in develops:
    dev_index.setdefault((d[0], d[1], d[2]), {})[d[3]] = d[4]

# ------------------------------------------------------------------ users
FIRST = ["alex", "sam", "jordan", "taylor", "maya", "arjun", "priya", "li", "wei", "omar", "fatima", "noah", "emma",
         "liam", "olivia", "ethan", "ava", "lucas", "mia", "aiden", "zara", "ravi", "nina", "kai", "leo", "sara",
         "hana", "yusuf", "chloe", "ben", "isha", "dev", "tara", "max", "ivy", "raj", "elena", "marco", "jin", "amir"]
LAST = ["patel", "smith", "nguyen", "chen", "singh", "brown", "khan", "wilson", "li", "garcia", "martin", "kim",
        "tremblay", "roy", "gagnon", "wong", "lee", "sharma", "ali", "taylor", "white", "lopez", "park", "das"]
WORDS = ["byte", "quant", "alpha", "delta", "sigma", "pixel", "node", "lambda", "vector", "tensor", "cache", "kernel",
         "orbit", "maple", "north", "lake", "river", "stack", "heap", "query"]
PERSONAL = ["gmail.com", "outlook.com", "proton.me", "yahoo.ca", "icloud.com"]

N_STUDENTS, N_TRADERS, N_ADMINS = 2600, 640, 8
handles, users = set(), []
def new_handle():
    while True:
        h = random.choice([f"{random.choice(FIRST)}_{random.choice(LAST)}",
                           f"{random.choice(WORDS)}{random.choice(FIRST)}",
                           f"{random.choice(FIRST)}{random.randint(1, 999)}",
                           f"{random.choice(WORDS)}_{random.choice(WORDS)}"])
        h = h + str(random.randint(10, 99)) if h in handles else h
        if h not in handles and len(h) <= 30:
            handles.add(h)
            return h

emails = set()
def new_email(handle, domain):
    local = re.sub(r"[^a-z0-9]", "", handle)[:12] + str(random.randint(1, 9999))
    while (local, domain) in emails:
        local += str(random.randint(0, 9))
    emails.add((local, domain))
    return local, domain

students = []   # dicts
user_rows, student_rows, admin_rows = [], [], []
uni_weights = [8, 9, 9, 6, 5, 5, 5, 6, 5, 4, 3, 8, 5, 6, 5, 5, 5, 3]
for i in range(N_STUDENTS):
    h = new_handle()
    u = random.choices(UNIS, weights=uni_weights)[0]
    dom = random.choice(u[3])
    created = rand_dt(datetime(2023, 9, 1), datetime(2026, 10, 31))
    verified = created + timedelta(minutes=random.randint(2, 600))
    consent = verified + timedelta(seconds=random.randint(5, 300))
    prog = random.choices([p for p, _ in PROGRAM_WEIGHTS], weights=[w for _, w in PROGRAM_WEIGHTS])[0]
    gy = random.choices([2024, 2025, 2026, 2027, 2028, 2029], weights=[8, 18, 22, 22, 18, 12])[0]
    users.append(h)
    user_rows.append((h, *new_email(h, dom), created))
    student_rows.append((h, PROGRAMS[prog], gy, verified, consent, u[0]))
    students.append({"h": h, "uni": u[0], "prog": prog, "gy": gy, "verified": verified, "created": created})
traders = []
for i in range(N_TRADERS):
    h = new_handle()
    created = rand_dt(datetime(2023, 9, 1), datetime(2026, 9, 30))
    users.append(h)
    traders.append(h)
    user_rows.append((h, *new_email(h, random.choice(PERSONAL)), created))
admins = []
for i in range(N_ADMINS):
    h = "admin_" + random.choice(WORDS) + str(i + 1)
    handles.add(h)
    created = datetime(2023, 8, 1) + timedelta(days=i * 3, hours=9)
    users.append(h)
    admins.append(h)
    user_rows.append((h, *new_email(h, "talentmkt.ca"), created))
    admin_rows.append((h, created + timedelta(hours=1)))
user_created = {r[0]: r[3] for r in user_rows}

emit("User", ["handle", "email_local", "email_domain", "created_at"], user_rows)
emit("Student", ["handle", "program", "grad_year", "verified_at", "consent_at", "university_name"], student_rows)
emit("Admin", ["handle", "granted_at"], admin_rows)

# signup ledger entries (entry_no 1 for everyone)
entry_no = {h: 1 for h in users}
balance = {h: Decimal("1000.00") for h in users}
emit("LedgerEntry", ["handle", "entry_no", "amount", "kind", "created_at"],
     [(h, 1, Decimal("1000.00"), "signup", user_created[h]) for h in users])

# ------------------------------------------------------------------ completed courses
def year_levels_done(gy):
    # how many academic years of courses a student has finished by Nov 2026
    return max(1, min(4, 4 - (gy - 2027)))

completed_rows = []
skill_totals = {}   # handle -> {skill: weighted total}
for s in students:
    lst = uni_courses[s["uni"]]
    done = year_levels_done(s["gy"])
    picks = []
    for subj, num, arch in lst:
        level = int(num[0])
        if level > done:
            continue
        progs = arch[4]
        p = 0.85 if (progs == "ALL" or s["prog"] in progs.split()) else 0.07
        if random.random() < p:
            picks.append((subj, num, level))
    for subj, num, level in picks:
        start_year = s["gy"] - 4 + level - 1
        term = f"{start_year}F" if random.random() < 0.5 else f"{start_year + 1}W"
        if random.random() < 0.05:
            term = f"{start_year + 1}S"
        grade = random.choices(["A+", "A", "B", "C", "D", "F"], weights=[10, 28, 32, 18, 8, 4])[0]
        completed_rows.append((s["h"], subj, num, term, grade))
emit("Completed", ["handle", "subject", "number", "term", "grade_band"], completed_rows)
# weighted skill totals per student (same rule as the SQL in ex3.sql: sum of Develops.weight over completed courses)
skill_totals = {}
student_by_h = {s["h"]: s for s in students}
for (h, subj, num, term, grade) in completed_rows:
    tot = skill_totals.setdefault(h, {})
    for sk, w in dev_index[(student_by_h[h]["uni"], subj, num)].items():
        tot[sk] = tot.get(sk, Decimal(0)) + w

# ------------------------------------------------------------------ outcome reports
REGIONS = ["Toronto", "Waterloo Region", "SF Bay Area", "Seattle", "New York", "Vancouver", "Montreal",
           "Ottawa", "Calgary", "Remote"]
FIELDS = {"SE": "Software", "CS": "Software", "CE": "Hardware", "EE": "Hardware", "DS": "Data Science",
          "MATH": "Finance", "BUS": "Consulting"}
BANDS = ["<60k", "60-80k", "80-100k", "100-130k", "130k+"]
report_rows = []
reports = {}  # handle -> list of (reported_at, status, region, field, band)
for s in students:
    if s["gy"] > 2026 or random.random() > 0.88:
        continue
    grad = datetime(s["gy"], 5, 1)
    start = max(s["verified"], grad - timedelta(days=120))
    if start >= NOW:
        continue
    n = random.choices([1, 2, 3], weights=[50, 35, 15])[0]
    times = sorted(rand_dt(start, NOW - timedelta(days=3)) for _ in range(n))
    lst = []
    for t in times:
        months_out = (t - grad).days / 30
        p_emp = min(0.88, 0.35 + 0.05 * max(0, months_out))
        st = random.choices(["employed", "searching", "grad_school", "other"],
                            weights=[p_emp, max(0.05, 0.55 - p_emp + 0.25), 0.12, 0.04])[0]
        if st == "employed":
            reg = random.choices(REGIONS, weights=[30, 10, 9, 7, 6, 12, 8, 7, 5, 6])[0]
            fld = FIELDS[s["prog"]] if random.random() < 0.7 else random.choice(
                ["Software", "Data Science", "Product", "Research", "Finance", "Consulting", "Hardware"])
            band = random.choices(BANDS, weights=[10, 25, 30, 23, 12 if reg not in ("SF Bay Area", "Seattle", "New York") else 40])[0]
        elif st == "grad_school":
            reg, fld, band = random.choice(REGIONS[:8]), "Research", None
        else:
            reg, fld, band = None, None, None
        report_rows.append((s["h"], t, st, reg, fld, band))
        lst.append((t, st, reg, fld, band))
    reports[s["h"]] = lst
emit("OutcomeReport", ["handle", "reported_at", "status", "job_region", "job_field", "salary_band"], report_rows)

# ------------------------------------------------------------------ cohorts
COHORT_DEFS = [
    # title, {skill: min}, grad years
    ("ML Engineers 2025", {"Machine Learning": "1.0", "Python": "1.0"}, [2024, 2025]),
    ("ML Engineers 2026", {"Machine Learning": "1.0", "Python": "1.0"}, [2026]),
    ("ML Engineers 2027", {"Machine Learning": "1.0", "Python": "1.0"}, [2027]),
    ("Deep Learning 2026", {"Deep Learning": "0.8", "Linear Algebra": "0.8"}, [2025, 2026]),
    ("NLP Specialists 2026", {"NLP": "0.8", "Machine Learning": "1.0"}, [2025, 2026]),
    ("Database Builders 2025", {"SQL": "0.8", "Databases": "0.8"}, [2024, 2025]),
    ("Database Builders 2026", {"SQL": "0.8", "Databases": "0.8"}, [2026]),
    ("Database Builders 2027", {"SQL": "0.8", "Databases": "0.8"}, [2027]),
    ("Full-Stack Web 2025", {"Web Development": "0.8", "JavaScript": "0.8"}, [2024, 2025]),
    ("Full-Stack Web 2026", {"Web Development": "0.8", "JavaScript": "0.8", "SQL": "0.5"}, [2026]),
    ("Full-Stack Web 2028", {"Web Development": "0.8", "JavaScript": "0.8"}, [2028]),
    ("Systems Programmers 2025", {"Operating Systems": "0.8", "C++": "0.8"}, [2024, 2025]),
    ("Systems Programmers 2026", {"Operating Systems": "0.8", "C++": "0.8"}, [2026]),
    ("Systems Programmers 2027", {"Operating Systems": "0.8", "C++": "0.8"}, [2027]),
    ("Cloud and Distributed 2026", {"Cloud Computing": "0.8", "Distributed Systems": "1.0"}, [2025, 2026]),
    ("Cloud and Distributed 2027", {"Cloud Computing": "0.8", "Distributed Systems": "1.0"}, [2027]),
    ("Security Track 2026", {"Security": "0.8", "Networking": "0.8"}, [2025, 2026]),
    ("Security Track 2028", {"Security": "0.8", "Networking": "0.8"}, [2028]),
    ("Embedded Engineers 2026", {"Embedded Systems": "0.8", "Digital Logic": "0.8"}, [2025, 2026]),
    ("Embedded Engineers 2027", {"Embedded Systems": "0.8", "Digital Logic": "0.8"}, [2027]),
    ("Data Analysts 2025", {"Data Analysis": "0.8", "Statistics": "1.2"}, [2024, 2025]),
    ("Data Analysts 2026", {"Data Analysis": "0.8", "Statistics": "1.2"}, [2026]),
    ("Data Analysts 2027", {"Data Analysis": "0.8", "Statistics": "1.2", "SQL": "0.3"}, [2027]),
    ("Software Designers 2026", {"Software Design": "1.2", "Testing": "0.8"}, [2025, 2026]),
    ("Software Designers 2027", {"Software Design": "1.2", "Testing": "0.8", "Requirements": "0.8"}, [2027]),
    ("Product-Minded Engineers 2027", {"Requirements": "0.8", "UI Design": "0.8", "Project Management": "0.8"}, [2027, 2028]),
    ("Mobile Developers 2027", {"Mobile Development": "0.8", "JavaScript": "0.5"}, [2027, 2028]),
    ("Quant Track 2026", {"Probability": "1.0", "Statistics": "1.0", "Finance": "0.5"}, [2025, 2026]),
    ("Algorithms Heavy 2027", {"Algorithms": "2.5", "Probability": "0.5"}, [2027]),
    ("Signal Processing 2027", {"Signal Processing": "0.8", "Linear Algebra": "0.8"}, [2027, 2028]),
    ("Early ML Track 2029", {"Machine Learning": "1.0"}, [2029]),
    ("Business Analytics 2026", {"Accounting": "0.8", "Data Analysis": "0.6", "Marketing": "0.8"}, [2025, 2026]),
]
# ex3.sql inserts MemberOf rows for this cohort by hand, so the generator leaves its membership empty.
EX3_COHORT = ("Data Platform Engineers 2027", {"Databases": "0.8", "Cloud Computing": "0.8"}, [2027, 2028])

def qualifies(h, rules, years):
    s = student_by_h[h]
    if s["gy"] not in years:
        return False
    tot = skill_totals.get(h, {})
    return all(tot.get(sk, Decimal(0)) >= Decimal(m) for sk, m in rules.items())

cohort_rows, cgy_rows, req_rows, member_rows = [], [], [], []
cohorts = []
for i, (title, rules, years) in enumerate(COHORT_DEFS + [EX3_COHORT]):
    admin = admins[i % len(admins)]
    mem = [s["h"] for s in students if qualifies(s["h"], rules, years)]
    if title == EX3_COHORT[0]:
        cohort_rows.append((title, "proposed", None, admin))
        ex3_members = mem
    elif len(mem) >= 25:
        mem_sorted = sorted(mem, key=lambda h: student_by_h[h]["verified"])
        activated = student_by_h[mem_sorted[24]]["verified"] + timedelta(minutes=random.randint(1, 90))
        status = "retired" if title in ("ML Engineers 2025", "Full-Stack Web 2025") else "active"
        cohort_rows.append((title, status, activated, admin))
        cohorts.append({"title": title, "rules": rules, "years": years, "members": mem_sorted, "activated": activated, "status": status})
    else:
        cohort_rows.append((title, "proposed", None, admin))
    for y in years:
        cgy_rows.append((title, y))
    for sk, m in rules.items():
        req_rows.append((title, sk, Decimal(m)))
    if title != EX3_COHORT[0]:
        comp_at = datetime(2026, 11, 15, 3, 0, 0) + timedelta(seconds=random.randint(0, 3000))
        for h in mem:
            member_rows.append((h, title, comp_at))
emit("Cohort", ["title", "status", "activated_at", "defined_by"], cohort_rows)
emit("CohortGradYear", ["cohort_title", "grad_year"], cgy_rows)
emit("Requires", ["cohort_title", "skill_label", "min_weighted_courses"], req_rows)
emit("MemberOf", ["handle", "cohort_title", "computed_at"], member_rows)

# ------------------------------------------------------------------ snapshots + markets
snap_rows, fm_rows, market_rows = [], [], []
markets = []
slugs = set()
def slugify(t):
    return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")

def latest_report_before(h, cutoff):
    best = None
    for r in reports.get(h, []):
        if r[0] < cutoff and (best is None or r[0] > best[0]):
            best = r
    return best

def meets(rep, m):
    if rep is None or rep[1] != m["metric"]:
        return False
    if m["region"] and rep[2] != m["region"]:
        return False
    if m["field"] and rep[3] != m["field"]:
        return False
    if m["band"] and (rep[4] is None or BANDS.index(rep[4]) < BANDS.index(m["band"])):
        return False
    return True

for c in cohorts:
    G = max(c["years"])
    n_snaps = 1 if random.random() < 0.6 else 2
    snap_times = []
    for k in range(n_snaps):
        latest_ok = min(NOW - timedelta(days=20), datetime(G, 3, 1) if G <= 2026 else NOW - timedelta(days=20))
        earliest = c["activated"] + timedelta(days=5)
        if earliest >= latest_ok:
            continue
        snap_times.append(rand_dt(earliest, latest_ok).replace(microsecond=0))
    for ft in sorted(set(snap_times)):
        frozen = [h for h in c["members"] if student_by_h[h]["verified"] <= ft]
        if len(frozen) < 25:
            continue
        snap_rows.append((c["title"], ft, len(frozen)))
        for no, h in enumerate(frozen, 1):
            fm_rows.append((c["title"], ft, h, no))
        fset = set(frozen)
        for k in range(random.randint(1, 4)):
            metric = random.choices(["employed", "grad_school", "searching"], weights=[75, 15, 10])[0]
            region = field = band = None
            if metric == "employed":
                kind = random.choice(["any", "region", "field", "band", "region"])
                if kind == "region":
                    region = random.choice(["SF Bay Area", "Toronto", "Seattle", "Vancouver", "New York", "Waterloo Region"])
                elif kind == "field":
                    field = random.choice(["Software", "Data Science", "Hardware", "Finance"])
                elif kind == "band":
                    band = random.choice(["80-100k", "100-130k", "130k+"])
            # deadline and schedule
            if G <= 2025:
                deadline = random.choice([date(G, 12, 31), date(G + 1, 6, 1), date(G + 1, 9, 1)])
            elif G == 2026:
                deadline = random.choice([date(2026, 9, 1), date(2026, 10, 1), date(2027, 3, 1), date(2027, 9, 1)])
            else:
                deadline = date(G, 9, 1) if random.random() < 0.6 else date(G + 1, 5, 1)
            opens = ft + timedelta(hours=random.randint(1, 72), seconds=random.randint(0, 59))
            closes = datetime(deadline.year, deadline.month, deadline.day) - timedelta(days=random.choice([1, 7, 14, 30]))
            if closes <= opens + timedelta(days=10):
                continue
            m = {"metric": metric, "region": region, "field": field, "band": band, "deadline": deadline}
            dl = datetime(deadline.year, deadline.month, deadline.day)
            if dl < NOW:
                pct = 100 * sum(meets(latest_report_before(h, dl), m) for h in frozen) / len(frozen)
                thr = max(5, min(95, round(pct + random.uniform(-15, 15))))
            else:
                thr = random.choice([10, 20, 25, 30, 40, 50, 60, 70, 75, 80]) if metric == "employed" else random.choice([10, 15, 20, 25])
            # question text
            what = {"employed": "be employed", "grad_school": "be in grad school", "searching": "still be job searching"}[metric]
            if region:
                what += f" in {region}" if region != "Remote" else " remotely"
            if field:
                what += f" in {field}"
            if band:
                what += f" earning {band}"
            question = f"Will at least {thr}% of {c['title']} {what} by {deadline.strftime('%b')} {deadline.day}, {deadline.year}?"
            base = slugify(f"{c['title']} {metric} {region or field or band or ''} {thr} {deadline.year}")[:56]
            slug = base
            n = 2
            while slug in slugs:
                slug = f"{base[:54]}-{n}"
                n += 1
            slugs.add(slug)
            # final status (applied after trades are loaded)
            if dl < NOW and dl < datetime(2026, 9, 2) or (dl < NOW and random.random() < 0.5):
                final = "resolved"
            elif closes < NOW:
                final = "closed"
            else:
                final = "open"
            if final == "resolved" and random.random() < 0.06:
                final = "voided"
            m.update({"slug": slug, "question": question, "thr": thr, "opens": opens, "closes": closes,
                      "cohort": c["title"], "frozen_at": ft, "insiders": fset, "final": final, "dl": dl})
            if final == "resolved":
                pct = 100 * sum(meets(latest_report_before(h, dl), m) for h in frozen) / len(frozen)
                m["outcome"] = "yes" if pct >= thr else "no"
            else:
                m["outcome"] = None
            markets.append(m)
            market_rows.append((slug, question, metric, Decimal(thr), region, field, band, deadline,
                                opens, closes, "open", None, c["title"], ft))
emit("CohortSnapshot", ["cohort_title", "frozen_at", "member_count"], snap_rows)
emit("FrozenMember", ["cohort_title", "frozen_at", "handle", "member_no"], fm_rows)
emit("Market", ["slug", "question", "metric", "threshold_pct", "rule_region", "rule_field", "rule_salary_band",
                "deadline", "opens_at", "closes_at", "status", "outcome", "cohort_title", "frozen_at"], market_rows)

# ------------------------------------------------------------------ trades (simulated in time order)
active_traders = random.sample(users[:-N_ADMINS], 900)   # a smaller group does most of the trading
events = []
for m in markets:
    end = min(m["closes"], NOW - timedelta(hours=1))
    n = random.randint(30, 130)
    for _ in range(n):
        events.append((rand_dt(m["opens"], end), m))
events.sort(key=lambda e: e[0])
price = {m["slug"]: Decimal("0.5000") for m in markets}
pos = {}   # (h, slug) -> [yes, no]
trade_rows = []
used_ts = set()
for t, m in events:
    slug = m["slug"]
    pool = active_traders if random.random() < 0.8 else users[:-N_ADMINS]
    h = random.choice(pool)
    if h in m["insiders"] or user_created[h] > t:
        continue
    p = price[slug]
    key = (h, slug)
    held = pos.get(key, [0, 0])
    target = Decimal("0.5")
    if m["final"] == "resolved":
        frac = Decimal(str((t - m["opens"]).total_seconds() / max(1, (m["closes"] - m["opens"]).total_seconds())))
        target = Decimal("0.5") + (Decimal("0.4") if m["outcome"] == "yes" else Decimal("-0.4")) * frac
    if (held[0] > 0 or held[1] > 0) and random.random() < 0.25:
        action = "sell"
        side = "yes" if held[0] >= held[1] else "no"
        shares = max(1, int(Decimal(held[0] if side == "yes" else held[1]) * Decimal(random.choice([0.25, 0.5, 1]))))
    else:
        action = "buy"
        lean_yes = 0.5 + float(target - p) * 1.5
        side = "yes" if random.random() < max(0.1, min(0.9, lean_yes)) else "no"
        shares = random.randint(2, 60)
    unit = p if side == "yes" else (1 - p)
    cost = (unit * shares).quantize(D2, ROUND_HALF_UP)
    fee = (cost * Decimal("0.02")).quantize(D2, ROUND_HALF_UP)
    if cost <= 0:
        continue
    if action == "buy" and balance[h] < cost + fee:
        continue
    impact = Decimal(shares) * Decimal("0.0012") * (1 if (side == "yes") == (action == "buy") else -1)
    newp = p + impact + Decimal(str(random.uniform(-0.01, 0.01)))
    newp = max(Decimal("0.0200"), min(Decimal("0.9800"), newp)).quantize(Decimal("0.0001"))
    ts = t.replace(microsecond=random.randint(0, 999999))
    if (h, slug, ts) in used_ts:
        continue
    used_ts.add((h, slug, ts))
    if action == "buy":
        balance[h] -= cost + fee
        held = [held[0] + (shares if side == "yes" else 0), held[1] + (shares if side == "no" else 0)]
    else:
        balance[h] += cost - fee
        held = [held[0] - (shares if side == "yes" else 0), held[1] - (shares if side == "no" else 0)]
    pos[key] = held
    entry_no[h] += 1 + (1 if fee > 0 else 0)     # mirrors trg_trade_apply
    price[slug] = newp
    trade_rows.append((h, slug, ts, side, action, Decimal(shares), cost, fee, newp))
emit("Trade", ["handle", "market_slug", "created_at", "side", "action", "shares", "cost", "fee", "price_after"],
     trade_rows, batch=200)

# ------------------------------------------------------------------ final market status, payouts, refunds
for st in ("closed", "voided"):
    sl = [m["slug"] for m in markets if m["final"] == st]
    if sl:
        out_lines.append(f"UPDATE Market SET status = '{st}' WHERE slug IN ({', '.join(q(s) for s in sl)});")
for oc in ("yes", "no"):
    sl = [m["slug"] for m in markets if m["final"] == "resolved" and m["outcome"] == oc]
    if sl:
        out_lines.append(f"UPDATE Market SET status = 'resolved', outcome = '{oc}' WHERE slug IN ({', '.join(q(s) for s in sl)});")
out_lines.append("COMMIT;")

payout_rows = []
cost_basis = {}
for (h, slug, ts, side, action, shares, cost, fee, newp) in trade_rows:
    cost_basis.setdefault((h, slug), []).append((action, cost))
mk = {m["slug"]: m for m in markets}
for (h, slug), held in sorted(pos.items(), key=lambda kv: (mk[kv[0][1]]["dl"], kv[0][0], kv[0][1])):
    m = mk[slug]
    if m["final"] == "resolved":
        win = held[0] if m["outcome"] == "yes" else held[1]
        if win > 0:
            entry_no[h] += 1
            payout_rows.append((h, entry_no[h], Decimal(win).quantize(D2), "payout",
                                m["dl"] + timedelta(hours=6, seconds=random.randint(0, 3600)), slug))
for (h, slug), held in sorted(pos.items()):
    m = mk[slug]
    if m["final"] == "voided":
        spent = sum((c for a, c in cost_basis[(h, slug)] if a == "buy"), Decimal(0)) - \
                sum((c for a, c in cost_basis[(h, slug)] if a == "sell"), Decimal(0))
        if spent > 0:
            entry_no[h] += 1
            payout_rows.append((h, entry_no[h], spent.quantize(D2), "refund",
                                m["closes"] + timedelta(days=2), None))
pay = [r for r in payout_rows if r[3] == "payout"]
ref = [(r[0], r[1], r[2], r[3], r[4]) for r in payout_rows if r[3] == "refund"]
emit("LedgerEntry", ["handle", "entry_no", "amount", "kind", "created_at", "payout_market_slug"], pay)
if ref:
    emit("LedgerEntry", ["handle", "entry_no", "amount", "kind", "created_at"], ref)

out_lines.append("SET autocommit = 1;")
with open(OUT, "w") as f:
    f.write("\n".join(out_lines) + "\n")

with open("ex3_candidates.txt", "w") as f:
    f.write("\n".join(sorted(ex3_members)) + "\n")

print("rows generated per relation (Position and trade/fee ledger rows come from triggers):")
for k, v in counts.items():
    print(f"  {k:18s} {v:6d}")
print(f"  ex3 cohort qualifiers: {len(ex3_members)}")
print("markets by final status:", {s: sum(1 for m in markets if m['final'] == s) for s in ('open', 'closed', 'resolved', 'voided')})

/*
--------------------------------------------------------------------------------
Project Title: HR Analytics – Attrition & Performance Monitoring
Client Delivery Script (SQL Server Compatible)
Prepared By: [Durgesh / LBA Analytics & AI]
Date: 30 July 2025
--------------------------------------------------------------------------------

OBJECTIVE:
To analyze employee attrition, performance, pay structure, and behavior patterns.
Demonstrates proficiency in:
✔ Joins
✔ CTEs
✔ Window Functions
✔ Subqueries
✔ CASE Statements
✔ Date and KPI Calculations
--------------------------------------------------------------------------------
*/

/* Sample Table Structure Assumed:
employees(emp_id, full_name, department, gender, age, hire_date, resignation_date, salary, performance_score, is_active)
attendance(emp_id, login_date, status) -- status: Present, Absent, Late
*/

-- 1. Attrition Count and Rate Over the Years
SELECT
    YEAR(resignation_date) AS resignation_year,
    COUNT(*) AS attrition_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*)
    FROM employees), 2) AS attrition_rate_pct
FROM employees
WHERE resignation_date IS NOT NULL
GROUP BY YEAR(resignation_date)
ORDER BY resignation_year;

-- 2. Average Tenure by Department
SELECT
    department,
    ROUND(AVG(DATEDIFF(DAY, hire_date, ISNULL(resignation_date, GETDATE())))/365.0, 2) AS avg_tenure_years
FROM employees
GROUP BY department
ORDER BY avg_tenure_years DESC;

-- 3. Current Headcount by Department and Gender
SELECT
    department,
    gender,
    COUNT(*) AS employee_count
FROM employees
WHERE is_active = 1
GROUP BY department, gender
ORDER BY department;

-- 4. Performance Score Distribution by Department
SELECT
    department,
    performance_score,
    COUNT(*) AS count_by_score
FROM employees
WHERE is_active = 1
GROUP BY department, performance_score
ORDER BY department, performance_score;

-- 5. Average Salary by Department
SELECT
    department,
    ROUND(AVG(salary), 2) AS avg_salary
FROM employees
WHERE is_active = 1
GROUP BY department
ORDER BY avg_salary DESC;

-- 6. Pay Gap: Male vs Female in Each Department
SELECT
    department,
    ROUND(AVG(CASE WHEN gender = 'Male' THEN salary END), 2) AS avg_male_salary,
    ROUND(AVG(CASE WHEN gender = 'Female' THEN salary END), 2) AS avg_female_salary,
    ROUND(AVG(CASE WHEN gender = 'Male' THEN salary END) - AVG(CASE WHEN gender = 'Female' THEN salary END), 2) AS pay_gap
FROM employees
WHERE is_active = 1
GROUP BY department;

-- 7. Identify Top 5 Employees by Salary in Each Department (Using Window Function)
WITH
    RankedSalaries
    AS
    (
        SELECT *,
            RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
        FROM employees
        WHERE is_active = 1
    )
SELECT emp_id, full_name, department, salary, rank_in_dept
FROM RankedSalaries
WHERE rank_in_dept <= 5
ORDER BY department, rank_in_dept;

-- 8. Average Age of Employees by Performance Level
SELECT
    performance_score,
    ROUND(AVG(age), 1) AS avg_age
FROM employees
WHERE is_active = 1
GROUP BY performance_score;

-- 9. Monthly Attendance Summary (Present Count)
SELECT
    emp_id,
    FORMAT(login_date, 'yyyy-MM') AS month,
    COUNT(*) AS present_days
FROM attendance
WHERE status = 'Present'
GROUP BY emp_id, FORMAT(login_date, 'yyyy-MM')
ORDER BY emp_id, month;

-- 10. Late Attendance Frequency per Employee
SELECT
    emp_id,
    COUNT(*) AS late_days
FROM attendance
WHERE status = 'Late'
GROUP BY emp_id
ORDER BY late_days DESC;

-- 11. Identify Employees at Risk of Attrition (High Salary, Low Performance, Frequent Absence)
SELECT
    e.emp_id,
    e.full_name,
    e.salary,
    e.performance_score,
    absent.absence_days
FROM employees e
    LEFT JOIN (
  SELECT emp_id, COUNT(*) AS absence_days
    FROM attendance
    WHERE status = 'Absent'
    GROUP BY emp_id
) absent ON e.emp_id = absent.emp_id
WHERE e.is_active = 1
    AND e.performance_score <= 2
    AND e.salary >= (SELECT AVG(salary)
    FROM employees)
    AND absent.absence_days >= 10;

-- 12. Hiring Trend Over Time
SELECT
    YEAR(hire_date) AS hire_year,
    COUNT(*) AS hires
FROM employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;

-- 13. Resignation Rate by Department
SELECT
    department,
    COUNT(CASE WHEN resignation_date IS NOT NULL THEN 1 END) AS resigned_count,
    COUNT(*) AS total_count,
    ROUND(100.0 * COUNT(CASE WHEN resignation_date IS NOT NULL THEN 1 END)/COUNT(*), 2) AS resignation_rate_pct
FROM employees
GROUP BY department
ORDER BY resignation_rate_pct DESC;

-- 14. High-Level Analysis: Time Series View of Monthly Attrition
WITH
    monthly_attrition
    AS
    (
        SELECT
            FORMAT(resignation_date, 'yyyy-MM') AS resign_month,
            COUNT(*) AS resignations
        FROM employees
        WHERE resignation_date IS NOT NULL
        GROUP BY FORMAT(resignation_date, 'yyyy-MM')
    ),
    monthly_hires
    AS
    (
        SELECT
            FORMAT(hire_date, 'yyyy-MM') AS hire_month,
            COUNT(*) AS hires
        FROM employees
        GROUP BY FORMAT(hire_date, 'yyyy-MM')
    )
SELECT
    COALESCE(ma.resign_month, mh.hire_month) AS month,
    ISNULL(mh.hires, 0) AS hires,
    ISNULL(ma.resignations, 0) AS resignations
FROM monthly_attrition ma
    FULL OUTER JOIN monthly_hires mh ON ma.resign_month = mh.hire_month
ORDER BY month;

-- 15. High-Level Analysis: Identify Departmental Performance Issues
WITH
    perf_cte
    AS
    (
        SELECT
            department,
            AVG(performance_score) AS avg_perf,
            COUNT(*) AS total_employees,
            AVG(salary) AS avg_salary
        FROM employees
        WHERE is_active = 1
        GROUP BY department
    )
SELECT *,
    CASE 
    WHEN avg_perf < 3 THEN 'Needs Improvement'
    WHEN avg_perf BETWEEN 3 AND 4 THEN 'Average'
    ELSE 'Excellent'
  END AS perf_status
FROM perf_cte
ORDER BY avg_perf;

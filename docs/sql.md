Basic SQL Cheat Sheet

1. SELECT Statements
	•	Select all columns from a table:

SELECT * FROM table_name;


	•	Select specific columns:

SELECT column1, column2 FROM table_name;


	•	Select distinct values:

SELECT DISTINCT column_name FROM table_name;



2. WHERE Clause
	•	Filter rows based on conditions:

SELECT * FROM table_name WHERE condition;

Examples:
	•	Equals: WHERE column = value
	•	Not equals: WHERE column != value
	•	Greater/Less than: WHERE column > value, WHERE column < value
	•	IN: WHERE column IN (value1, value2, value3)
	•	LIKE (pattern matching): WHERE column LIKE 'pattern%'
	•	NULL check: WHERE column IS NULL, WHERE column IS NOT NULL

3. Logical Operators
	•	Combine multiple conditions:

SELECT * FROM table_name WHERE condition1 AND condition2;
SELECT * FROM table_name WHERE condition1 OR condition2;
SELECT * FROM table_name WHERE NOT condition;



4. ORDER BY Clause
	•	Sort results:

SELECT * FROM table_name ORDER BY column_name ASC;  -- Ascending
SELECT * FROM table_name ORDER BY column_name DESC; -- Descending



5. LIMIT and OFFSET
	•	Limit the number of rows returned:

SELECT * FROM table_name LIMIT 10; -- First 10 rows
SELECT * FROM table_name LIMIT 10 OFFSET 5; -- Skip first 5 rows, then return 10 rows



6. INSERT Statement
	•	Insert data into a table:

INSERT INTO table_name (column1, column2) VALUES (value1, value2);



7. UPDATE Statement
	•	Update existing data:

UPDATE table_name SET column1 = value1, column2 = value2 WHERE condition;



8. DELETE Statement
	•	Delete data:

DELETE FROM table_name WHERE condition;



9. Aggregate Functions
	•	Perform calculations on data:

SELECT COUNT(column_name) FROM table_name; -- Count rows
SELECT AVG(column_name) FROM table_name;  -- Average value
SELECT SUM(column_name) FROM table_name;  -- Total sum
SELECT MAX(column_name) FROM table_name;  -- Maximum value
SELECT MIN(column_name) FROM table_name;  -- Minimum value



10. GROUP BY and HAVING
	•	Group data and apply aggregate functions:

SELECT column1, COUNT(*) FROM table_name GROUP BY column1;


	•	Filter grouped data:

SELECT column1, COUNT(*) FROM table_name GROUP BY column1 HAVING COUNT(*) > 1;



11. JOINs
	•	Combine data from multiple tables:
	•	Inner Join:

SELECT * FROM table1 INNER JOIN table2 ON table1.column = table2.column;


	•	Left Join:

SELECT * FROM table1 LEFT JOIN table2 ON table1.column = table2.column;


	•	Right Join:

SELECT * FROM table1 RIGHT JOIN table2 ON table1.column = table2.column;


	•	Full Join:

SELECT * FROM table1 FULL OUTER JOIN table2 ON table1.column = table2.column;



12. Subqueries
	•	Nested queries:

SELECT * FROM table_name WHERE column_name = (SELECT MAX(column_name) FROM table_name);



13. CREATE TABLE
	•	Create a new table:

CREATE TABLE table_name (
    column1 datatype,
    column2 datatype,
    column3 datatype
);



14. ALTER TABLE
	•	Add a new column:

ALTER TABLE table_name ADD column_name datatype;


	•	Modify a column:

ALTER TABLE table_name MODIFY column_name new_datatype;


	•	Drop a column:

ALTER TABLE table_name DROP COLUMN column_name;



15. DROP and TRUNCATE
	•	Drop a table:

DROP TABLE table_name;


	•	Remove all rows (reset the table):

TRUNCATE TABLE table_name;



16. Indexing
	•	Create an index:

CREATE INDEX index_name ON table_name (column_name);


	•	Drop an index:

DROP INDEX index_name;



17. Views
	•	Create a view:

CREATE VIEW view_name AS SELECT column1, column2 FROM table_name WHERE condition;


	•	Drop a view:

DROP VIEW view_name;



18. Useful Keywords
	•	DISTINCT, NULL, IS NOT NULL
	•	CASE (conditional logic):

SELECT column1,
       CASE 
         WHEN condition THEN result1
         ELSE result2
       END AS alias_name
FROM table_name;



This covers most of the basic SQL commands you’ll use!

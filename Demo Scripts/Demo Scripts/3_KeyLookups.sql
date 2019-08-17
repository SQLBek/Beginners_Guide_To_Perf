/*-------------------------------------------------------------------
-- 3 - Covering Indexes
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
GO
DBCC FREEPROCCACHE
GO


-----
-- Setup
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_LastName_Demo')
	DROP INDEX Customer.IX_Customer_LastName_Demo
GO
CREATE NONCLUSTERED INDEX IX_Customer_LastName_Demo ON Customer (
	LastName, FirstName, ZipCode
);
GO








-----
-- First, let's see what indexes we have
-- Ctrl-M: Turn off Actual Execution Plan
EXEC sp_SQLskills_helpindex 'dbo.Customer';
GO








-----
-- Example
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	LastName,
	FirstName,
	ZipCode
FROM dbo.Customer
WHERE LastName = 'Smith';
GO
-- Logical Reads:








-----
-- Hey, we need to add a new column to this query!
SELECT 
	LastName,
	FirstName,
	ZipCode,
	Email
FROM dbo.Customer
WHERE LastName = 'Smith';
GO
-- Logical Reads:




-----
-- Why huge jump?








-----
-- No predicate?
-- Index covers
SELECT TOP 200000
	LastName,
	FirstName,
	ZipCode
FROM dbo.Customer;
GO


-- Index does not cover
SELECT TOP 200000
	LastName,
	FirstName,
	ZipCode,
	Email
FROM dbo.Customer;
GO
-- Logical Reads:








-----
-- Modify existing index
CREATE NONCLUSTERED INDEX IX_Customer_LastName_Demo ON Customer (
	LastName, FirstName, ZipCode
)
INCLUDE (
	Email
)
WITH (
	DROP_EXISTING = ON
);
GO




-----
-- Re-run
SELECT 
	LastName,
	FirstName,
	ZipCode,
	Email
FROM dbo.Customer
WHERE LastName = 'Smith';
GO


-- No predicate
SELECT TOP 200000
	LastName,
	FirstName,
	ZipCode,
	Email
FROM dbo.Customer;
GO








-----
-- How to find?
--
-- Ctrl-M: Turn off Actual Execution Plan
-- Setup
DBCC FREEPROCCACHE
GO
SELECT 
	LastName,
	FirstName,
	City, State
FROM dbo.Customer
WHERE LastName = 'Jones';
GO 15

-- Ctrl-L: Show Estimated Execution Plan








-----
-- Author: Jonathan Kehayias
-- https://www.sqlskills.com/blogs/jonathan/finding-key-lookups-inside-the-plan-cache/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH XMLNAMESPACES
	(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
	n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
	n.query('.'),
	i.value('(@PhysicalOp)[1]', 'VARCHAR(128)') AS PhysicalOp,
	i.value('(./IndexScan/Object/@Database)[1]', 'VARCHAR(128)') AS DatabaseName,
	i.value('(./IndexScan/Object/@Schema)[1]', 'VARCHAR(128)') AS SchemaName,
	i.value('(./IndexScan/Object/@Table)[1]', 'VARCHAR(128)') AS TableName,
	i.value('(./IndexScan/Object/@Index)[1]', 'VARCHAR(128)') as IndexName,
	i.query('.'),
	STUFF(
		(SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
		FROM i.nodes('./OutputList/ColumnReference') AS t(cg)
		FOR XML PATH('')
	),1,2,'') AS output_columns,
	STUFF(
		(SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
		FROM i.nodes('./IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS t(cg)
		FOR XML PATH('')
	),1,2,'') AS seek_columns,
	i.value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)') as Predicate,
	cp.usecounts,
	query_plan
FROM (
	SELECT plan_handle, query_plan
	FROM (
		SELECT DISTINCT plan_handle
        FROM sys.dm_exec_query_stats WITH(NOLOCK)
	) AS qs
	OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp
) as tab (plan_handle, query_plan)
INNER JOIN sys.dm_exec_cached_plans AS cp 
	ON tab.plan_handle = cp.plan_handle
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/*') AS q(n)
CROSS APPLY n.nodes('.//RelOp[IndexScan[@Lookup="1"] and IndexScan/Object[@Schema!="[sys]"]]') as s(i)
OPTION(RECOMPILE, MAXDOP 1);
GO

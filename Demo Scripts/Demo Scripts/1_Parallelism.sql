/*-------------------------------------------------------------------
-- 1 - Parallelism
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO







-----
-- What kind of plans do we get out of these two examples?
-- Ctrl-M: Turn on Actual Execution Plan
SELECT *
FROM dbo.InventoryFlat
WHERE VIN LIKE 'JT2N%';
GO
-- Estimated subtree cost: 


--
SELECT *
FROM dbo.InventoryFlat
WHERE VIN LIKE 'JT2N%'
OPTION(MAXDOP 1);
GO
-- Estimated subtree cost: 




--
-- Clustered Index Scan -> Properties (F4) -> View Number of rows read 
-- 








-----
-- What's on this server?
SELECT 
	cpu_count,
	hyperthread_ratio,
	socket_count,
	cores_per_socket,
	numa_node_count
FROM sys.dm_os_sys_info;
GO








-----
-- Check sys.configurations
SELECT 
	name, value, value_in_use
FROM sys.configurations
WHERE name IN (
	'cost threshold for parallelism', 
	'max degree of parallelism'
);
GO




-----
-- Change parallelism & re-run parallel query
EXEC sp_configure 'cost threshold for parallelism', 50
GO
RECONFIGURE
GO








-----
-- Reset CTFP
EXEC sp_configure 'cost threshold for parallelism', 5
GO
RECONFIGURE
GO








-----
-- Example #2
-- Clean up if needed
IF EXISTS(SELECT 1 FROM tempdb.sys.objects WHERE name LIKE '#tmpSerial%')
	DROP TABLE #tmpSerial;

IF EXISTS(SELECT 1 FROM tempdb.sys.objects WHERE name LIKE '#tmpParallel%')
	DROP TABLE #tmpParallel;

-----
-- What kind of plan does this give?
SELECT TOP 1000000 SalesHistory.*
INTO #tmpParallel
FROM dbo.Inventory
INNER JOIN dbo.SalesHistory
	ON Inventory.InventoryID = SalesHistory.InventoryID
WHERE Inventory.VIN LIKE 'JT2%';
GO
-- SQL Server Execution Times: 
-- Logical Reads: 




-----
-- Force this to go serial
SELECT TOP 1000000 SalesHistory.*
INTO #tmpSerial
FROM dbo.Inventory
INNER JOIN dbo.SalesHistory
	ON Inventory.InventoryID = SalesHistory.InventoryID
WHERE Inventory.VIN LIKE 'JT2%'
OPTION(MAXDOP 1);
GO
-- SQL Server Execution Times: 
-- Logical Reads: 








-----
-- Think from a workload perspective
-- Execute these each in new windows - look at Properties -> Connection Elapsed Time
/*
EXEC AutoDealershipDemo.demo.sp_InventoryFlat_Fast_Serial
GO 50

EXEC AutoDealershipDemo.demo.sp_InventoryFlat_Fast_Parallel
GO 50
*/







-----
-- Search the plan cache
-- Author: Jonathan Kehayias
-- https://www.sqlskills.com/blogs/jonathan/tuning-cost-threshold-for-parallelism-from-the-plan-cache/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
WITH XMLNAMESPACES   
(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')  
SELECT  
     query_plan AS CompleteQueryPlan, 
     n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS StatementText, 
     n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS StatementOptimizationLevel, 
     n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS StatementSubTreeCost, 
     n.query('.') AS ParallelSubTreeXML,  
     ecp.usecounts, 
     ecp.size_in_bytes 
FROM sys.dm_exec_cached_plans AS ecp 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS eqp 
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n) 
WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1;
GO


/*
Jonathan:
I look at the high use count plans, and see if there is a missing index associated with those queries that is driving the cost up.  
If I can tune the high execution queries to reduce their cost, I have a win either way.  
However, if you run this query, you will note that there are some really high cost queries that you may not get below the five value.  
If you can fix the high use plans to reduce their cost, and then increase the ‘cost threshold for parallelism’ based on the cost of 
your larger queries that may benefit from parallelism, having a couple of low use count plans that use parallelism doesn’t have as 
much of an impact to the server overall, at least based on my own personal experiences.
*/
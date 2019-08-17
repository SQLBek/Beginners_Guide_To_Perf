/*-------------------------------------------------------------------
-- 4 - TempDB Spooling
-- 
-- Summary: 
-- Ensure that all SalesHistory indexes are disabled
-- ALTER INDEX IX_SalesHistory_TransactionDate ON SalesHistory DISABLE
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/
USE AutoDealershipDemo
GO
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO








-----
-- Get all SalesHistory records, where the sale was higher
-- than each SalesPerson's average sell price
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory 
WHERE SalesHistory.SellPrice > (
	SELECT AVG(SalesHistoryAvg.SellPrice)
	FROM dbo.SalesHistory AS SalesHistoryAvg
	WHERE SalesHistoryAvg.SalesPersonID = SalesHistory.SalesPersonID
)
ORDER BY SalesPersonID, TransactionDate DESC;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-- Note Scan Count
SELECT COUNT(DISTINCT SalesPersonID) 
FROM dbo.SalesHistory;
GO

-- Why?  
-- Ctrl-L: Estimated Execution Plan








-----
-- First, let's see what indexes we have
-- Ctrl-M: Turn off Actual Execution Plan
EXEC sp_SQLskills_helpindex 'dbo.SalesHistory';
GO








-----
-- Let's create a covering index to help this query
-- Ctrl-M: Turn on Actual Execution Plan
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_TransactionDate_Covering')
	DROP INDEX SalesHistory.IX_SalesHistory_TransactionDate_Covering
GO
CREATE NONCLUSTERED INDEX IX_SalesHistory_TransactionDate_Covering ON dbo.SalesHistory (
	SalesPersonID, SellPrice, TransactionDate DESC
)
INCLUDE (InventoryID);
GO




-----
-- Re-run example
SELECT 
	SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory 
WHERE SalesHistory.SellPrice > (
	SELECT AVG(SalesHistoryAvg.SellPrice)
	FROM dbo.SalesHistory AS SalesHistoryAvg
	WHERE SalesHistoryAvg.SalesPersonID = SalesHistory.SalesPersonID
)
ORDER BY SalesPersonID, TransactionDate DESC;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- BONUS 1
-- Disable Parallelism
SELECT 
	SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory 
WHERE SalesHistory.SellPrice > (
	SELECT AVG(SalesHistoryAvg.SellPrice)
	FROM dbo.SalesHistory AS SalesHistoryAvg
	WHERE SalesHistoryAvg.SalesPersonID = SalesHistory.SalesPersonID
)
ORDER BY SalesPersonID, TransactionDate DESC
OPTION(MAXDOP 1);
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- BONUS 2
-- Added an additional predicate
SELECT 
	SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory 
WHERE SalesHistory.SellPrice > (
	SELECT AVG(SalesHistoryAvg.SellPrice)
	FROM dbo.SalesHistory AS SalesHistoryAvg
	WHERE SalesHistoryAvg.SalesPersonID = SalesHistory.SalesPersonID
)
	AND SalesPersonID < 140		-- Limit output to about 1/2 total recordset
ORDER BY SalesPersonID, TransactionDate DESC;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- How to really rewrite this?
-- 1: CTE?
WITH AvgSellPrice_CTE AS (
	SELECT 
		SalesPersonID,
		AVG(SalesHistory.SellPrice) AS AvgSellPrice
	FROM dbo.SalesHistory
	WHERE SalesPersonID < 140
	GROUP BY SalesPersonID
)
SELECT 
	SalesHistory.SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory
INNER JOIN AvgSellPrice_CTE
	ON SalesHistory.SalesPersonID = AvgSellPrice_CTE.SalesPersonID
WHERE SellPrice > AvgSellPrice
ORDER BY SalesHistory.SalesPersonID, TransactionDate DESC;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- 2: Windowing Function?
WITH AvgSellPrice_CTE AS (
	SELECT 
		SalesPersonID,
		TransactionDate,
		SellPrice,
		SalesHistoryID,
		InventoryID,
		AVG(SalesHistory.SellPrice) OVER(PARTITION BY SalesPersonID) AS AvgSellPrice
	FROM dbo.SalesHistory
	WHERE SalesPersonID < 140
)
SELECT 
	SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM AvgSellPrice_CTE
WHERE SellPrice > AvgSellPrice
ORDER BY SalesPersonID, TransactionDate DESC;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- 3: Break it up into multiple steps
IF EXISTS(SELECT 1 FROM tempdb.sys.objects WHERE name LIKE '#tmpAvgPrice%')
	DROP TABLE #tmpAvgPrice;

CREATE TABLE #tmpAvgPrice (
	SalesPersonID INT PRIMARY KEY CLUSTERED,
	AvgSellPrice MONEY
);

INSERT INTO #tmpAvgPrice (
	SalesPersonID,
	AvgSellPrice
)
SELECT 
	SalesPersonID,
	AVG(SalesHistory.SellPrice) AS AvgSellPrice
FROM dbo.SalesHistory
GROUP BY SalesPersonID;

SELECT 
	SalesHistory.SalesPersonID,
	TransactionDate,
	SellPrice,
	SalesHistoryID,
	InventoryID
FROM dbo.SalesHistory
INNER JOIN #tmpAvgPrice
	ON SalesHistory.SalesPersonID = #tmpAvgPrice.SalesPersonID 
WHERE SalesHistory.SalesPersonID < 140
	AND SalesHistory.SellPrice > #tmpAvgPrice.AvgSellPrice;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- Reset
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_TransactionDate_Covering')
	DROP INDEX SalesHistory.IX_SalesHistory_TransactionDate_Covering
GO



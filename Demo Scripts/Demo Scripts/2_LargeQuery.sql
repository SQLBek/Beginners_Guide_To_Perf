/*-------------------------------------------------------------------
-- 2 - Large Queries
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
-- Example #1
--
-- Query Requirement:
--
-- Per SalesPerson
-- between two arbitrary dates
--
-- # of transactions
-- average net profit
-- total net profit
-- total commission
--
-- rank each sales person from top to bottom 
-- by number of transactions & average net profit
--








-----
-- Example of one design pattern I've seen before: 
-- CTEs for all tables!
-- Reasoning? Breaking up problem into smaller queries for the optimizer!
-- Also easier to read
--
WITH SalesHistory_CTE AS (
	SELECT 
		SalesHistoryID,
		InventoryID,
		SalesPersonID,
		SellPrice
	FROM dbo.SalesHistory
	WHERE (
		SalesHistory.TransactionDate >= '2015-01-01'
		AND SalesHistory.TransactionDate < '2016-01-01'
	)
),
SalesPerson_CTE AS (
	SELECT
		SalesPersonID,
		LastName,
		FirstName,
		CommissionRate
	FROM dbo.SalesPerson
),
Inventory_CTE AS (
	SELECT 
		InventoryID,
		Inventory.TrueCost
	FROM dbo.Inventory
),
TotalSales_CTE AS (
	SELECT 
		SalesPersonID,
		COUNT(SalesHistoryID) AS TotalTransactions
	FROM SalesHistory_CTE
	GROUP BY SalesPersonID
),
Profit_CTE AS (
	SELECT 
		SalesHistory_CTE.SalesHistoryID,
		SalesHistory_CTE.SellPrice - Inventory_CTE.TrueCost AS NetProfit
	FROM SalesHistory_CTE
	INNER JOIN Inventory_CTE
		ON SalesHistory_CTE.InventoryID = Inventory_CTE.InventoryID

),
Commission_CTE AS (
	SELECT
		SalesPerson_CTE.SalesPersonID,
		SalesHistory_CTE.SalesHistoryID,
		Profit_CTE.NetProfit * SalesPerson_CTE.CommissionRate AS Commission 
	FROM SalesHistory_CTE
	INNER JOIN Profit_CTE
		ON Profit_CTE.SalesHistoryID = SalesHistory_CTE.SalesHistoryID
	INNER JOIN SalesPerson_CTE
		ON SalesPerson_CTE.SalesPersonID = SalesHistory_CTE.SalesPersonID
),
Final_CTE AS (
	SELECT
		SalesPerson_CTE.LastName,
		SalesPerson_CTE.FirstName,
		Profit_CTE.NetProfit,
		Commission_CTE.Commission,
		SalesHistory_CTE.SalesHistoryID,
		SalesPerson_CTE.SalesPersonID
	FROM SalesHistory_CTE
	INNER JOIN SalesPerson_CTE
		ON SalesPerson_CTE.SalesPersonID = SalesHistory_CTE.SalesPersonID
	INNER JOIN Profit_CTE
		ON Profit_CTE.SalesHistoryID = SalesHistory_CTE.SalesHistoryID
	INNER JOIN Commission_CTE
		ON Commission_CTE.SalesHistoryID = SalesHistory_CTE.SalesHistoryID
),
Aggregated_CTE AS (
	SELECT
		Final_CTE.LastName,
		Final_CTE.FirstName,
		COUNT(Final_CTE.SalesHistoryID) AS TotalTransactions,
		AVG(Final_CTE.NetProfit) AS AvgNetProfit,
		SUM(Final_CTE.NetProfit) AS TotalNetProfit,
		SUM(Final_CTE.Commission) AS TotalCommission
	FROM Final_CTE
	GROUP BY 
		Final_CTE.LastName,
		Final_CTE.FirstName
)
SELECT
	ROW_NUMBER() OVER(ORDER BY 
		TotalTransactions DESC,
		AvgNetProfit DESC
	) AS Rank,
	LastName,
	FirstName,
	TotalTransactions,
	AvgNetProfit,
	TotalNetProfit,
	TotalCommission
FROM Aggregated_CTE
ORDER BY 
	TotalTransactions DESC, 
	AvgNetProfit DESC,
	LastName, 
	FirstName;
GO


-- Ctrl-M: Turn On Actual Execution Plan
-- Execute above
-- Logical Reads:
-- SQL Server Execution Times:
-- Query Cost: 








-----
-- Revised query - execute
SELECT 
	ROW_NUMBER() OVER(ORDER BY 
		COUNT(SalesHistory.SalesHistoryID) DESC,
		AVG(SalesHistory.SellPrice - Inventory.TrueCost) DESC
	) AS Rank,
	SalesPerson.LastName,
	SalesPerson.FirstName,
	COUNT(SalesHistory.SalesHistoryID) AS TotalTransactions,
	AVG(SalesHistory.SellPrice - Inventory.TrueCost) AS AvgNetProfit,
	SUM(SalesHistory.SellPrice - Inventory.TrueCost) AS TotalNetProfit,
	SUM((SalesHistory.SellPrice - Inventory.TrueCost) * SalesPerson.CommissionRate) AS TotalCommission
FROM dbo.SalesPerson
INNER JOIN dbo.SalesHistory
	ON SalesPerson.SalesPersonID = SalesHistory.SalesPersonID
INNER JOIN dbo.Inventory
	ON SalesHistory.InventoryID = Inventory.InventoryID
WHERE SalesHistory.TransactionDate >= '2015-01-01'
	AND SalesHistory.TransactionDate < '2016-01-01'
GROUP BY 
	LastName, 
	FirstName
ORDER BY 
	TotalTransactions DESC, 
	AvgNetProfit DESC,
	LastName, 
	FirstName;
GO

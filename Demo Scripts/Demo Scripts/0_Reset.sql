USE AutoDealershipDemo
GO

/**********************************************
ENSURE TARGET VM HAS 2 SOCKETS & 2 CORES PER
**********************************************/
-- What's on this server?
SELECT 
	cpu_count,
	hyperthread_ratio,
	socket_count,
	cores_per_socket,
	numa_node_count
FROM sys.dm_os_sys_info
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_LastName_Demo')
	DROP INDEX Customer.IX_Customer_LastName_Demo
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_TransactionDate_Covering')
	DROP INDEX SalesHistory.IX_SalesHistory_TransactionDate_Covering
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesHistory_TransactionDate' AND object_id = OBJECT_ID(N'SalesHistory'))
	ALTER INDEX IX_SalesHistory_TransactionDate ON SalesHistory DISABLE
GO


-- Pre-Cache data
SELECT *
INTO #tmpInventoryFlat
FROM dbo.InventoryFlat
GO
DROP TABLE #tmpInventoryFlat;
GO

SELECT *
INTO #tmpSalesHistory
FROM dbo.SalesHistory
GO
DROP TABLE #tmpSalesHistory;
GO

SELECT *
INTO #tmpInventory
FROM dbo.Inventory
GO
DROP TABLE #tmpInventory;
GO

DBCC FREEPROCCACHE
GO


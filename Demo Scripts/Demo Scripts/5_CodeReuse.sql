/*-------------------------------------------------------------------
-- 5 - Code Reuse
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
DBCC FREEPROCCACHE
GO








-----
-- Scalar User Defined Functions (UDFs)
SELECT TOP 100000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN)
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- What's really inside dbo.udf_CalcNetProfit?
CREATE OR ALTER FUNCTION dbo.udf_CalcNetProfit (  
	@VIN CHAR(17)  
)  
RETURNS money  
AS  
BEGIN  
	DECLARE @NetProfit MONEY;  
  
	SELECT @NetProfit = SalesHistory.SellPrice - Inventory.InvoicePrice   
	FROM dbo.BaseVw_SalesHistory AS SalesHistory  
	INNER JOIN dbo.BaseVw_Inventory AS Inventory  
		ON SalesHistory.InventoryID = Inventory.InventoryID  
	WHERE Inventory.VIN = @VIN;  
  
	RETURN @NetProfit;  
END  
GO




-----
-- What's really happening?
-- Ctrl-L: Estimated Execution Plan
SELECT TOP 100000
	Inventory.InventoryID,
	Inventory.VIN,
	dbo.udf_CalcNetProfit(Inventory.VIN)
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO








-----
-- sys.dm_exec_function_stats
-- SQL SERVER 2016 & higher
SELECT OBJECT_NAME(object_id) AS function_name,
	type_desc,
	execution_count,
	total_logical_reads,
	-- last_logical_reads, min_logical_reads, max_logical_reads
	total_worker_time,
	-- last_worker_time, min_worker_time, max_worker_time,
	total_elapsed_time,
	-- last_elapsed_time, min_elapsed_time, max_elapsed_time
	cached_time
FROM sys.dm_exec_function_stats
WHERE object_name(object_id) IS NOT NULL;
GO









-----
-- Break-out Code
-- Write a situation specific, focused query.
SELECT TOP 100000
	Inventory.InventoryID,
	Inventory.VIN,
	SalesHistory.SellPrice - Inventory.InvoicePrice   
FROM dbo.Inventory
INNER JOIN SalesHistory
	ON SalesHistory.InventoryID = Inventory.InventoryID;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- Views
-- Ctrl-M: Turn on Actual Execution Plan
SELECT
	FirstName,
	LastName,
	YearSold,
	DealerNetProfit,
	Commission,
	AnnualNumOfSales
FROM dbo.vw_SalesPerson_AnnualProfit
WHERE YearSold = 2016
	AND LastName = 'Gilbert'
ORDER BY 
	LastName,
	YearSold;
GO
-- Logical Reads:
-- SQL Server Execution Times:








-----
-- This is what this query really looks like 
-- How many SELECT statements are buried in here?
SELECT 
	FirstName,
	LastName,
	YearSold,
	DealerNetProfit,
	Commission,
	AnnualNumOfSales
FROM (
	SELECT 
		SalesPerson.FirstName,
		SalesPerson.LastName,
		AnnualNumOfSales.YearSold,
		SUM(SalesHistory.SellPrice - vw_AllSoldInventory.InvoicePrice) AS DealerNetProfit,
		SUM(CASE
			WHEN (SalesHistory.SellPrice - vw_AllSoldInventory.InvoicePrice) > 0
			THEN (SalesHistory.SellPrice - vw_AllSoldInventory.InvoicePrice) * SalesPerson.CommissionRate
			WHEN (SalesHistory.SellPrice - vw_AllSoldInventory.InvoicePrice) <= 0
			THEN 0
		END) AS Commission,
		AnnualNumOfSales.AnnualNumOfSales
	FROM (
		SELECT   
			Inventory.VIN,
			VehicleBaseModel.MakeName,
			VehicleBaseModel.ModelName,
			VehicleBaseModel.ColorName,
			Package.PackageName,
			Inventory.InvoicePrice,
			Inventory.MSRP,
			SalesHistory.SellPrice,
			Inventory.DateReceived,
			SalesHistory.TransactionDate,
			Inventory.InventoryID,
			SalesHistory.SalesHistoryID
		FROM (
			SELECT 
				InventoryID,
				VIN,
				BaseModelID,
				PackageID,
				TrueCost,
				InvoicePrice,
				MSRP,
				DateReceived
			FROM dbo.Inventory
		-- ) AS dbo.BaseVW_Inventory 
		) AS Inventory  
		INNER JOIN (
			SELECT     
				BaseVw_BaseModel.BaseModelID,    
				BaseVw_Make.MakeName,    
				BaseVw_Model.ModelName,    
				BaseVw_Color.ColorName,    
				BaseVw_Color.ColorCode    
			FROM (
				SELECT 
					BaseModel.BaseModelID,  
					BaseModel.MakeID,  
					BaseModel.ModelID,  
					BaseModel.ColorID,  
					BaseModel.TrueCost,  
					BaseModel.InvoicePrice,  
					BaseModel.MSRP  
				FROM Vehicle.BaseModel 
			) AS BaseVw_BaseModel    
			INNER JOIN (
				SELECT 
					Make.MakeID,  
					Make.MakeName  
				FROM Vehicle.Make
			) AS BaseVw_Make 
				ON BaseVw_BaseModel.MakeID = BaseVw_Make.MakeID    
			INNER JOIN (
				SELECT 
					Model.ModelID,  
					Model.ModelName,  
					Model.ClassificationID  
				FROM Vehicle.Model
			) AS BaseVw_Model    
				ON BaseVw_BaseModel.ModelID = BaseVw_Model.ModelID    
			INNER JOIN (
				SELECT 
					Color.ColorID,  
					Color.ColorName,  
					Color.ColorCode  
				FROM Vehicle.Color
			) AS BaseVw_Color    
				ON BaseVw_BaseModel.ColorID = BaseVw_Color.ColorID  
		--) AS dbo.vw_VehicleBaseModel 
		) AS VehicleBaseModel  
			ON Inventory.BaseModelID = VehicleBaseModel.BaseModelID    
		INNER JOIN (
			SELECT DISTINCT  
				BaseVw_Inventory.BaseModelID,
				BaseVw_Inventory.PackageID,
				Vw_VehicleBaseModel.MakeName,
				Vw_VehicleBaseModel.ModelName,
				Vw_VehicleBaseModel.ColorName,
				Vw_VehicleBaseModel.ColorCode,
				BaseVw_Package.PackageName,
				BaseVw_Package.PackageCode,
				BaseVw_Package.Description,
				BaseVw_Package.TrueCost,
				BaseVw_Package.InvoicePrice,
				BaseVw_Package.MSRP
			FROM (
				SELECT 
					InventoryID,
					VIN,
					BaseModelID,
					PackageID,
					TrueCost,
					InvoicePrice,
					MSRP,
					DateReceived
				FROM dbo.Inventory
			) AS BaseVw_Inventory  
			INNER JOIN (
				SELECT     
					BaseVw_BaseModel.BaseModelID,    
					BaseVw_Make.MakeName,    
					BaseVw_Model.ModelName,    
					BaseVw_Color.ColorName,    
					BaseVw_Color.ColorCode    
				FROM (
					SELECT 
						BaseModel.BaseModelID,  
						BaseModel.MakeID,  
						BaseModel.ModelID,  
						BaseModel.ColorID,  
						BaseModel.TrueCost,  
						BaseModel.InvoicePrice,  
						BaseModel.MSRP  
					FROM Vehicle.BaseModel 
				) AS BaseVw_BaseModel    
				INNER JOIN (
					SELECT 
						Make.MakeID,  
						Make.MakeName  
					FROM Vehicle.Make
				) AS BaseVw_Make 
					ON BaseVw_BaseModel.MakeID = BaseVw_Make.MakeID    
				INNER JOIN (
					SELECT 
						Model.ModelID,  
						Model.ModelName,  
						Model.ClassificationID  
					FROM Vehicle.Model
				) AS BaseVw_Model    
					ON BaseVw_BaseModel.ModelID = BaseVw_Model.ModelID    
				INNER JOIN (
					SELECT 
						Color.ColorID,  
						Color.ColorName,  
						Color.ColorCode  
					FROM Vehicle.Color
				) AS BaseVw_Color    
					ON BaseVw_BaseModel.ColorID = BaseVw_Color.ColorID  
			) AS Vw_VehicleBaseModel  
				ON BaseVw_Inventory.BaseModelID = Vw_VehicleBaseModel.BaseModelID  
			INNER JOIN (
				SELECT 
					Package.PackageID,  
					Package.PackageName,  
					Package.PackageCode,  
					Package.Description,  
					Package.TrueCost,  
					Package.InvoicePrice,  
					Package.MSRP  
				FROM Vehicle.Package
			) AS BaseVw_Package  
				ON BaseVw_Inventory.PackageID = BaseVw_Package.PackageID
		--) AS dbo.vw_VehiclePackageDetail 
		) AS Package  
			ON Inventory.PackageID = Package.PackageID    
		INNER JOIN (
			SELECT 
				SalesHistory.SalesHistoryID,  
				SalesHistory.CustomerID,  
				SalesHistory.SalesPersonID,  
				SalesHistory.InventoryID,  
				SalesHistory.TransactionDate,  
				SalesHistory.SellPrice  
			FROM dbo.SalesHistory  
		--) AS dbo.BaseVW_SalesHistory 
		) AS SalesHistory  
			ON SalesHistory.InventoryID = Inventory.InventoryID
	) AS vw_AllSoldInventory
	INNER JOIN (
		SELECT 
			SalesHistory.SalesHistoryID,  
			SalesHistory.CustomerID,  
			SalesHistory.SalesPersonID,  
			SalesHistory.InventoryID,  
			SalesHistory.TransactionDate,  
			SalesHistory.SellPrice  
		FROM dbo.SalesHistory
	--) AS dbo.BaseVw_SalesHistory 
	) AS SalesHistory
		ON vw_AllSoldInventory.SalesHistoryID = SalesHistory.SalesHistoryID
	INNER JOIN (
		SELECT 
			SalesPerson.SalesPersonID,  
			SalesPerson.FirstName,  
			SalesPerson.LastName,  
			SalesPerson.Email,  
			SalesPerson.PhoneNumber,  
			SalesPerson.DateOfHire,  
			SalesPerson.Salary,  
			SalesPerson.CommissionRate  
		FROM dbo.SalesPerson 
	--) AS BaseVw_SalesPerson 
	) AS SalesPerson
		ON SalesHistory.SalesPersonID = SalesPerson.SalesPersonID
	INNER JOIN (
		SELECT 
			vw_SalesPerson_SalesPerMonth.FirstName,
			vw_SalesPerson_SalesPerMonth.LastName,
			YEAR(vw_SalesPerson_SalesPerMonth.MonthYearSold) AS YearSold,
			SUM(NumOfSales) AS AnnualNumOfSales,
			vw_SalesPerson_SalesPerMonth.SalesPersonID
		FROM (
		SELECT   
			SalesPerson.FirstName,
			SalesPerson.LastName,
			CAST(  
				CAST(YEAR(SalesHistory.TransactionDate) AS VARCHAR(4)) + '-'  
				+ CAST(MONTH(SalesHistory.TransactionDate) AS VARCHAR(2)) + '-01'  
				AS DATE  
			) AS MonthYearSold,
			COUNT(1) AS NumOfSales,
			SUM(SellPrice) AS TotalSellPrice,
			MIN(SellPrice) AS MinSellPrice,
			MAX(SellPrice) AS MaxSellPrice,
			AVG(SellPrice) AS AvgSellPrice,
			SalesPerson.SalesPersonID  
		FROM (
			SELECT 
				SalesPerson.SalesPersonID,  
				SalesPerson.FirstName,  
				SalesPerson.LastName,  
				SalesPerson.Email,  
				SalesPerson.PhoneNumber,  
				SalesPerson.DateOfHire,  
				SalesPerson.Salary,  
				SalesPerson.CommissionRate  
			FROM dbo.SalesPerson
		--) AS dbo.BaseVw_SalesPerson 
		) AS SalesPerson
		INNER JOIN (
			SELECT 
				SalesHistory.SalesHistoryID,  
				SalesHistory.CustomerID,  
				SalesHistory.SalesPersonID,  
				SalesHistory.InventoryID,  
				SalesHistory.TransactionDate,  
				SalesHistory.SellPrice  
			FROM dbo.SalesHistory 
		--) AS dbo.BaseVw_SalesHistory 
		) AS SalesHistory
			ON SalesHistory.SalesPersonID = SalesPerson.SalesPersonID  
		GROUP BY   
			SalesPerson.SalesPersonID,
			SalesPerson.FirstName,
			SalesPerson.LastName,
			CAST(  
				CAST(YEAR(SalesHistory.TransactionDate) AS VARCHAR(4)) + '-'  
				+ CAST(MONTH(SalesHistory.TransactionDate) AS VARCHAR(2)) + '-01'  
				AS DATE  
			)
		) AS vw_SalesPerson_SalesPerMonth
		GROUP BY
			vw_SalesPerson_SalesPerMonth.SalesPersonID,
			vw_SalesPerson_SalesPerMonth.FirstName,
			vw_SalesPerson_SalesPerMonth.LastName,
			YEAR(vw_SalesPerson_SalesPerMonth.MonthYearSold)
	
	--) AS dbo.vw_SalesPerson_AnnualNumOfSales 
	) AS AnnualNumOfSales
		ON SalesPerson.SalesPersonID = AnnualNumOfSales.SalespersonID
		AND YEAR(vw_AllSoldInventory.TransactionDate) = AnnualNumOfSales.YearSold
	GROUP BY 
		SalesPerson.LastName,
		SalesPerson.FirstName,
		AnnualNumOfSales.YearSold,	
		AnnualNumOfSales.AnnualNumOfSales
)
AS vw_SalesPerson_AnnualProfit
WHERE YearSold = 2016
	AND LastName = 'Gilbert';
GO

-- TWENTY FOUR!!!  24!!!








-----
-- Unravelling this is a pain!
-- How about using a free script tool instead?
-- https://github.com/SQLBek/sp_helpExpandView
EXEC dbo.sp_helpExpandView
	@ViewName = N'dbo.vw_SalesPerson_AnnualProfit',
	@OutputFormat = 'Horizontal';








-----
-- Focused specific query
SELECT 
	SalesPerson.FirstName,
	SalesPerson.LastName,
	YEAR(SalesHistory.TransactionDate) AS YearSold,
	SUM(SalesHistory.SellPrice - Inventory.InvoicePrice) AS DealerNetProfit,
	SUM(CASE
		WHEN (SalesHistory.SellPrice - Inventory.InvoicePrice) > 0
		THEN (SalesHistory.SellPrice - Inventory.InvoicePrice) * SalesPerson.CommissionRate
		WHEN (SalesHistory.SellPrice - Inventory.InvoicePrice) <= 0
		THEN 0
	END) AS Commission,
	COUNT(SalesHistory.SalesHistoryID) AS AnnualNumOfSales
FROM dbo.Inventory  
INNER JOIN dbo.SalesHistory  
	ON SalesHistory.InventoryID = Inventory.InventoryID
INNER JOIN dbo.SalesPerson
	ON SalesHistory.SalesPersonID = SalesPerson.SalesPersonID
GROUP BY 
	SalesPerson.LastName,
	SalesPerson.FirstName,
	YEAR(SalesHistory.TransactionDate);
GO



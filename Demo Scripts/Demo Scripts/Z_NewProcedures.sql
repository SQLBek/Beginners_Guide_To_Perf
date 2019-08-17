CREATE OR ALTER PROCEDURE demo.sp_InventoryFlat_Fast_Parallel AS
/*
Used with 7 worst practices session
*/
BEGIN
	-- This should give me a parallel plan
	SELECT *
	INTO #foobar
	FROM dbo.InventoryFlat
	WHERE VIN LIKE 'JT2N%';
END
GO

CREATE OR ALTER PROCEDURE demo.sp_InventoryFlat_Fast_Serial AS
/*
Used with 7 worst practices session
*/
BEGIN
	-- Force this to go serial
	SELECT *
	INTO #foobar
	FROM dbo.InventoryFlat
	WHERE VIN LIKE 'JT2N%'
	OPTION(MAXDOP 1);
END
GO

/*
-- Run each of these a bunch, in separate windows

EXEC demo.sp_InventoryFlat_Fast_Serial

EXEC demo.sp_InventoryFlat_Fast_Parallel

*/


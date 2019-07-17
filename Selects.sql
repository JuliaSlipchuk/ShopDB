USE Shop

/*Return all Goods items*/
SELECT * FROM Goods

/*Return StaffName and StaffBirth items from Staffs where StaffName = 'Anna' or StaffSex = 'M'*/
SELECT StaffName, StaffBirth FROM Staffs WHERE StaffName = 'Anna' OR StaffSex = 'M'

/*Return PurchId CustomerName and CustomerSurname: tables join (Purchases and Customers) where year(purchase) - year(custmBirth) = year('01-01-0019')*/
SELECT PurchId, CustName, CustSurname FROM Purchases 
INNER JOIN Customers ON Purchases.CustId = Customers.CustId
WHERE (YEAR(PurchDate) - YEAR(CustBirth) = YEAR('01-01-0019')) AND CustName LIKE 'O%'

/*Determine the average age of sellers who sold the goods to minors*/
SELECT AVG(YEAR(CONVERT(DATE, GETDATE())) - YEAR(Staffs.StaffBirth)) FROM Staffs
INNER JOIN Purchases ON Staffs.StaffId = Purchases.StaffId
INNER JOIN Customers ON Purchases.CustId = Customers.CustId
WHERE (YEAR(CONVERT(DATE, GETDATE())) - YEAR(Customers.CustBirth) <= YEAR('01-01-0018'))

/*Determine the number of men and women who buy goods over 1kg in 2019 (use function)*/
CREATE OR ALTER FUNCTION GET_WEIGHT(@PurchId INT)
RETURNS FLOAT
BEGIN
	DECLARE @RES FLOAT
	SET @RES = (SELECT SUM(GoodWeight) FROM Goods 
			   INNER JOIN GoodsList ON Goods.GoodId = GoodsList.GoodId
			   INNER JOIN Purchases ON GoodsList.PurchId = Purchases.PurchId
			   WHERE Purchases.PurchId = @PurchId)
	RETURN @RES
END
	
SELECT TOP 1 (SELECT COUNT(*) FROM Customers WHERE CustSex = 'M') AS mens, 
	   (SELECT COUNT(*) FROM Customers WHERE CustSex = 'F') AS women FROM Customers
INNER JOIN Purchases ON Customers.CustId = Purchases.CustId
WHERE (dbo.GET_WEIGHT(Purchases.PurchId) > 1 AND YEAR(Purchases.PurchDate) = 2019)

/*Choose the 3 most expensive products that the youngest employee has sold*/
SELECT  TOP(3) GoodName FROM Goods 
INNER JOIN GoodsList ON Goods.GoodId = GoodsList.GoodId
INNER JOIN Purchases ON GoodsList.PurchId = Purchases.PurchId
INNER JOIN Staffs ON Purchases.StaffId = Staffs.StaffId
WHERE StaffBirth = (SELECT MAX(StaffBirth) FROM Staffs WHERE StaffPosition = 'Seller')
ORDER BY Price DESC

/*Among men buyers more than women*/
CREATE OR ALTER FUNCTION COUNT_PURCH_GOOD(@SEX NVARCHAR(1), @GoodId INT)
RETURNS INT 
AS
BEGIN
	DECLARE @RES INT
	SET @RES = (SELECT COUNT(Purchases.PurchId) FROM Purchases 
				INNER JOIN GoodsList ON Purchases.PurchId = GoodsList.PurchId
				INNER JOIN Goods ON GoodsList.GoodId = Goods.GoodId
				INNER JOIN Customers ON Purchases.CustId = Customers.CustId
				WHERE Customers.CustSex = @SEX AND Goods.GoodId = @GoodId)
	RETURN @RES
END

SELECT GoodId FROM Goods 
WHERE (dbo.COUNT_PURCH_GOOD('M', GoodId) > dbo.COUNT_PURCH_GOOD('F', GoodId))

/*Determine who, when and whom the most expensive product was sold*/
SELECT Staffs.StaffId, Customers.CustId, Purchases.PurchId FROM Purchases
INNER JOIN Staffs ON Purchases.StaffId = Staffs.StaffId
INNER JOIN Customers ON Purchases.CustId = Customers.CustId
INNER JOIN GoodsList ON Purchases.PurchId = GoodsList.PurchId
INNER JOIN Goods ON GoodsList.GoodId = Goods.GoodId
WHERE Price = (SELECT MAX(Price) FROM Goods)

/*Determine the total amount of goods sold by each seller with more than 3 years of experience*/
SELECT Purchases.StaffId, SUM(PurchSum) FROM Purchases
INNER JOIN Staffs ON Purchases.StaffId = Staffs.StaffId
WHERE StaffExper >= 3
GROUP BY Purchases.StaffId

/*Determine the day when most goods were sold*/
CREATE OR ALTER FUNCTION GROUP_BY_DATE()
RETURNS @T TABLE (PurchDate DATE, CountPurch INT) 
AS
BEGIN	
	INSERT @T SELECT CONVERT(DATE, PurchDate) AS PurchDat, COUNT(PurchId) FROM Purchases GROUP BY CONVERT(DATE, PurchDate)
	RETURN
END

SELECT PurchDate FROM dbo.GROUP_BY_DATE() 
WHERE CountPurch = (SELECT MAX(CountPurch) FROM dbo.GROUP_BY_DATE())

/*Choose those products that people buy up to 25 years old (among buyers of people up to 25 years older than older people)*/
CREATE OR ALTER FUNCTION COMPARE_COUNT(@GoodId INT)
RETURNS INT
AS
BEGIN
	DECLARE @RES INT
	SET @RES = ((SELECT COUNT(Purchases.PurchId) FROM Purchases
				 INNER JOIN Customers ON Purchases.CustId = Customers.CustId
				 INNER JOIN GoodsList ON Purchases.PurchId = GoodsList.PurchId
				 WHERE DATEDIFF(YEAR,  CustBirth, CONVERT(DATE, GETDATE())) < 25 
					   AND GoodsList.GoodId = @GoodId) -
				 (SELECT COUNT(Purchases.PurchId) FROM Purchases
				 INNER JOIN Customers ON Purchases.CustId = Customers.CustId
				 INNER JOIN GoodsList ON Purchases.PurchId = GoodsList.PurchId
				 WHERE DATEDIFF(YEAR,  CustBirth, CONVERT(DATE,GETDATE())) >= 25 
					   AND GoodsList.GoodId = @GoodId))
	RETURN @RES
END

SELECT DISTINCT Goods.GoodId, COUNT(Purchases.PurchId) FROM Goods 
INNER JOIN GoodsList ON Goods.GoodId = GoodsList.GoodId
INNER JOIN Purchases ON GoodsList.PurchId = Purchases.PurchId
WHERE dbo.COMPARE_COUNT(Goods.GoodId) > 0
GROUP BY Goods.GoodId

/*Choose goods that were sold more often on Sunday than on other days*/
CREATE OR ALTER FUNCTION GOODS_SUNDAY()
RETURNS @CUR TABLE (GoodId INT, PartName NVARCHAR(50), PurchCount INT)
AS
BEGIN
	INSERT @CUR SELECT GoodsList.GoodId, DATENAME(WEEKDAY, PurchDate) AS PurchDat, COUNT(Purchases.PurchId) AS PurchCount
				FROM Purchases INNER JOIN GoodsList ON Purchases.PurchId = GoodsList.PurchId
				GROUP BY GoodsList.GoodId, DATENAME(WEEKDAY, PurchDate)
				ORDER BY GoodsList.GoodId, DATENAME(WEEKDAY, PurchDate)
	RETURN
END

CREATE OR ALTER FUNCTION CHECK_COUNT(@GoodId INT)
RETURNS INT
AS
BEGIN
	DECLARE @RES INT
	DECLARE @T TABLE (PurchCount INT)
	DECLARE @TOPTWO INT
	INSERT @T SELECT TOP(2) PurchCount FROM dbo.GOODS_SUNDAY() WHERE GoodId = @GoodId ORDER BY PurchCount DESC
	SET @TOPTWO = (SELECT MIN(PurchCount) FROM @T)
	IF ((SELECT PurchCount FROM dbo.GOODS_SUNDAY() WHERE GoodId = @GoodId AND PartName = 'Sunday') = 
	   (SELECT MAX(PurchCount) FROM dbo.GOODS_SUNDAY() WHERE GoodId = @GoodId)
	   AND
	   (SELECT PurchCount FROM dbo.GOODS_SUNDAY() WHERE GoodId = @GoodId AND PartName = 'Sunday') <>
	   @TOPTWO)
	BEGIN
		SET @RES = 1
	END
	ELSE
	BEGIN
		SET @RES = -1
	END
	RETURN @RES
END

SELECT GoodId, GoodName FROM Goods
WHERE (dbo.CHECK_COUNT(GoodId) = 1)

/*Determine the longest sequence of days when the seller "Anna Libinska" did not sell anything*/
CREATE OR ALTER FUNCTION SELECT_PURCH_SELLER(@StaffId INT)
RETURNS @T TABLE (PurchDate DATE)
AS
BEGIN
	INSERT @T SELECT TOP(SELECT COUNT(*) - 1 FROM Purchases WHERE StaffId = @StaffId) PurchDate FROM Purchases WHERE StaffId = @StaffId ORDER BY PurchDate
	RETURN
END

CREATE OR ALTER FUNCTION SELECT_MAX_DIFF(@StaffId INT)
RETURNS @RES TABLE (MAXSTARTDAY DATE, MAXENDDAY DATE)
AS
BEGIN
	DECLARE @THISSTARTDAY DATE
	SET @THISSTARTDAY = (SELECT TOP(1) PurchDate FROM Purchases WHERE StaffId = @StaffId ORDER BY PurchDate)
	DECLARE @THISENDDAY DATE
	IF EXISTS (SELECT * FROM SELECT_PURCH_SELLER(@StaffId))
	BEGIN
		DECLARE DBCURSOR CURSOR FOR 
		(SELECT PurchDate FROM SELECT_PURCH_SELLER(@StaffId)) ORDER BY PurchDate
		OPEN DBCURSOR
			FETCH NEXT FROM DBCURSOR INTO @THISENDDAY
			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF (DATEDIFF(DAY, @THISSTARTDAY, @THISENDDAY) > DATEDIFF(DAY, (SELECT MAXSTARTDAY FROM @RES), (SELECT MAXENDDAY FROM @RES)))
				BEGIN
					DELETE FROM @RES
					INSERT @RES VALUES (@THISSTARTDAY, @THISENDDAY)
				END
				SET @THISSTARTDAY = @THISENDDAY
			END
		CLOSE DBCURSOR
	END
	IF (DATEDIFF(DAY, @THISSTARTDAY, @THISENDDAY) > DATEDIFF(DAY, (SELECT MAXSTARTDAY FROM @RES), (SELECT MAXENDDAY FROM @RES)))
	BEGIN
		DELETE FROM @RES
		INSERT @RES VALUES (@THISSTARTDAY, @THISENDDAY)
	END
	RETURN
END

SELECT * FROM dbo.SELECT_MAX_DIFF(5)
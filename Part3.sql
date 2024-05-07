-- PART 1

-- שאילתה לא מקוננת המחזירה את המוצרים שהרווח עליהם מעל 10000 דולר ומחיר יחידה קטן מ100
select c.ID, [Total Price]=sum((c.Quantity)*(COLORS.[Extra Price]+ LOGOS.[Extra Price]+ p.Price))
from ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
join COLORS on COLORS.[Design – Color]= c.[Design – Color] 
join logos on logos.[Design – Logo]= c.[Design – Logo]
join PRODUCTS as P on p.ID=c.ID
where p.Price < 100
group by c.ID
having sum((c.Quantity)*(COLORS.[Extra Price]+ LOGOS.[Extra Price]+ p.Price))>1000
order by [Total Price] desc


-- שאילתה לא מקוננת המחזירה את המוצר הנקנה ביותר ע"י נשים בשנה האחרונה
select top 1 [current year]=year(o.[Order Date]), c.ID, [sum] = sum(c.Quantity), CU.Gender 
from ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
join CUSTOMERS as CU on o.Email = CU.Email
where year(o.[Order Date]) = year(getdate()) and CU.Gender like 'female'
group by year(o.[Order Date]),c.ID, CU.Gender
order by sum desc


-- שאילתה מקוננת המפלחת את אחוז הלקוחות לפי קבוצות גיל
SELECT  	total = count(*)
	INTO	SUMMARY
	FROM 	CUSTOMERS

select age ,amount=count(*)
, total, ratio = round(cast(count(*) as float)/cast(total as float),2)  from
(select age= case when datediff(yy, c.Birthdate, getDate()) between 16 and 30 then '16 - 30' 
when datediff(yy, c.birthdate, getDate()) between 31 and 60 then '31 - 60'
when datediff(yy, c.birthdate, getDate()) >=60 then '61+' 
else '0-15' end
from CUSTOMERS as c) as ages, SUMMARY 
group by age, total
order by amount desc
drop table SUMMARY


-- שאילתה מקוננת המחזירה את רשימה המוצרים שלא נקנו בכלל בשנה האחרונה
SELECT	distinct C.ID	
FROM ORDERS as O JOIN CONTENT AS C ON O.[Creation Date] = c.[Creation Date] and o.Email = c.Email   
WHERE Year(o.[Order Date])	not in(	
select distinct C.ID
from ORDERS as O JOIN CONTENT AS C ON O.[Creation Date] = c.[Creation Date] and o.Email = c.Email   
WHERE	year(O.[Order Date])=Year(GetDate()))


-- שאילתת 'עדכון' המקטלגת מוצרים לפי כמות הפעמים שהם נמכרו
alter table products add [product rate] varchar(11)

update PRODUCTS
set [product rate] = case when t.amount > 10 then 'best seller' when t.amount between 1 and 10 then 'normal'
else 'not sold'
end 

from(
select c.ID, amount = sum(c.Quantity)
from ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
group by c.ID

union

select PRODUCTS.ID, amount = 0
from PRODUCTS
except(
select distinct c.ID,amount = 0
from ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
join PRODUCTS as p on p.ID = c.ID
)
) as t
where t.ID = PRODUCTS.ID


-- שאילתה הבודקת את העיצובים שמחירם גבוה מהמחיר הממוצע ומעולם לא הוזמנו
select a.[Design – Color] as Design
from
(select [Design – Color] , [Extra Price] from COLORS
where [Extra Price] > (select avg([Extra Price]) from COLORS)
union
select * from LOGOS 
where [Extra Price] > (select avg([Extra Price]) from LOGOS)) a
except(
select b.[Design – Color] as Design
from
(select distinct [Design – Color]
from CONTENT
union 
select distinct [Design – Logo]
from CONTENT) b
)


--PART 2


--VIEW מראה מספר כרטיס אשראי בלבד- חסיון לקוח אל מול העובד שצריך את הכרטיס
create View [v_CreditCard] as 
select [Credit Card Number]= Account
From [CREDIT CARDS]
group by Account

-- EXAMPLE
select * from v_CreditCard


--VIEW מראה את כל נתוני כרטיס האשראי, למורשים בלבד
create View [v_CreditCardsForAuthorizedOnly] as 
select Distinct *
From [CREDIT CARDS]

--EXAMPLE
select * from v_CreditCardsForAuthorizedOnly



--FUNCTION 1 מקבלת מספר מוצר ומחזירה את מספר הפעמים שנמכר
create function dbo.AmountSoldByProduct(@ID int)
returns int
as begin
declare @amount int
select @amount = sum(c.Quantity)
from ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
join PRODUCTS as p on p.ID=c.ID
where p.ID = @id 
return @amount
end

--EXAMPLE 
select id, [Total sales]= dbo.AmountSoldByProduct(53684)
from PRODUCTS
where PRODUCTS.id = 53684



-- FUNCTION 2 פונקציה המקבלת מספר, חודש ושנה ומחזירה טבלה המכילה מדינות שמכרו מספר מוצרים גדול/שווה למספר שהוזן, בזמן שהוזן
CREATE 	FUNCTION 	TopProduct ( @x int , @month int, @year int)  
RETURNS 	TABLE
AS 	RETURN
SELECT  o.[Address- State], amount = sum(c.Quantity)
FROM	ORDERS as o join CONTENT as c on o.Email = c.Email AND o.[Creation Date]=c.[Creation Date]
where month(o.[Order Date]) = @month and  year(o.[Order Date]) = @year
group by o.[Address- State]
HAVING	sum (c.Quantity) >= @x

--EXAMPLE
select *
from dbo.TopProduct(5,3,2021)



-- TRIGGER הטריגר עוזר לנו לדעת מה המחיר הכולל של עגלות הקנייה 
alter table [shopping carts] add total money

create trigger update_shopping_carts
on content
for insert, update, delete

as update [SHOPPING CARTS]

set total = (select sum(PRODUCTS.Price + COLORS.[Extra Price] + LOGOS.[Extra Price])
from CONTENT join COLORS on CONTENT.[Design – Color]=COLORS.[Design – Color]
join LOGOS on CONTENT.[Design – Logo] = LOGOS.[Design – Logo]
join PRODUCTS on CONTENT.ID = PRODUCTS.ID
where CONTENT.[Creation Date] = [SHOPPING CARTS].[Creation Date] and CONTENT.Email = [SHOPPING CARTS].Email
)
where
[SHOPPING CARTS].Email in(select distinct Email from inserted union select distinct Email from deleted)

--EXAMPLE
insert into CONTENT(Email,[Creation Date],ID,[Design – Color],[Design – Logo],Size,Quantity)
Values ('abeavenf8@home.pl', '2018-07-16 13:09:00.000', 17564, 'brown', '716030824', 'm',1)


delete from CONTENT where Email = 'abeavenf8@home.pl' and ID = 17564



--STORED PROCEDURE מאפשרת לשליחים של החברה מידע הנחוץ להם בלבד
create procedure SP_GetInfo @Email varchar(40) as
select [Name- first], [Name- last], Email, [Phone Number]
from CUSTOMERS
where (Email = @Email)

--EXAMPLE
execute sp_GetInfo 'aclubley60@typepad.com'



--PART 3
-- VIEW 1
create view total_view as
SELECT O.[order ID], O.[Order Date], O.[Address- State], O.[Address- City], O.[Address- Street], O.[Address- House Number], O.[Address- Postal Code], O.[Shipping Method], O.Email, O.[Creation Date], O.Account, dbo.[CONTENT].ID, dbo.[CONTENT].[Design – Color], dbo.[CONTENT].[Design – Logo], dbo.[CONTENT].Size, dbo.[CONTENT].Quantity, dbo.COLORS.[Extra Price] AS [extra price color], 
         dbo.LOGOS.[Extra Price] AS [extra price logos], dbo.PRODUCTS.Price, dbo.PRODUCTS.Category, dbo.CUSTOMERS.[Name- first], dbo.CUSTOMERS.[Name- last], dbo.CUSTOMERS.Gender, dbo.CUSTOMERS.Birthdate, dbo.[CONTENT].Quantity * (dbo.COLORS.[Extra Price] + dbo.LOGOS.[Extra Price] + dbo.PRODUCTS.Price) AS [Total revenue], dbo.PRODUCTS.[product rate], 
         CAST(dbo.PRODUCTS.ID AS varchar) AS [Product ID], CASE WHEN datediff(yy, CUSTOMERS.Birthdate, getDate()) BETWEEN 16 AND 30 THEN '16 - 30' WHEN datediff(yy, CUSTOMERS.birthdate, getDate()) BETWEEN 31 AND 60 THEN '31 - 60' WHEN datediff(yy, CUSTOMERS.birthdate, getDate()) >= 60 THEN '61+' ELSE '0-15' END AS [age group]
FROM  dbo.ORDERS AS O INNER JOIN
         dbo.[CONTENT] ON O.[Creation Date] = dbo.[CONTENT].[Creation Date] AND O.Email = dbo.[CONTENT].Email INNER JOIN
         dbo.COLORS ON dbo.COLORS.[Design – Color] = dbo.[CONTENT].[Design – Color] INNER JOIN
         dbo.LOGOS ON dbo.LOGOS.[Design – Logo] = dbo.[CONTENT].[Design – Logo] INNER JOIN
         dbo.PRODUCTS ON dbo.PRODUCTS.ID = dbo.[CONTENT].ID INNER JOIN
         dbo.CUSTOMERS ON dbo.CUSTOMERS.Email = dbo.[CONTENT].Email

-- VIEW 2
create view returning_customers_view as
SELECT Email, [Address- State]
FROM  dbo.ORDERS
GROUP BY Email, [Address- State]
HAVING (COUNT(*) >= 2)

--VIEW 3
create view new_customers_view as
SELECT DISTINCT Email, MIN([Creation Date]) AS [join date]
FROM  dbo.[SHOPPING CARTS]
GROUP BY Email

-- VIEW 4
create view costumers_view as
SELECT Email, Password, [Name- first], [Name- last], [Phone Number], Birthdate, Gender, CASE WHEN datediff(yy, c.Birthdate, getDate()) BETWEEN 16 AND 30 THEN '16 - 30' WHEN datediff(yy, c.birthdate, getDate()) BETWEEN 31 AND 60 THEN '31 - 60' WHEN datediff(yy, c.birthdate, getDate()) >= 60 THEN '61+' ELSE '0-15' END AS [age group]
FROM  dbo.CUSTOMERS AS c



--PART 4

--WINDOW FUNCTION 1 הרווח השנתי של החברה, רווח החברה בשנה הקודמת, מהי עליית הרווח באחוזים ובאיזה שנה הייתה העלייה המשמעותית ביותר בחברה
select [year], TotalSales , PrevYearSales , [yearlyGrowth (%)],
yearRank =RANK() OVER (ORDER BY [yearlyGrowth (%)] desc)
from
	(select *, [yearlyGrowth (%)]= round((TotalSales)/(PrevYearSales), 2)
	from

		(SELECT *,
PrevYearSales =round( LAG(TotalSales , 1) over (order by [year]),2)
		from
		(select [year]= year(ORDERS.[order date]) ,
TotalSales=round( sum(CONTENT.Quantity*(COLORS.[Extra Price]+LOGOS.[Extra Price]+PRODUCTS.Price)), 2)
		from orders join CONTENT on orders.Email= content.Email and
		ORDERS.[Creation Date]=CONTENT.[Creation Date]
		join COLORS on CONTENT.[Design – Color]=COLORS.[Design – Color]
		join LOGOS on CONTENT.[Design – Logo] = LOGOS.[Design – Logo]
		join PRODUCTS on CONTENT.ID = PRODUCTS.ID
		group by  year(ORDERS.[order date])) AS V
		) as f)
	as g
order by yearRank


--WINDOW FUNCTION 2 פרק הזמן בין הרכישה הראשונה של לקוח, לבין הרכישה האחרונה שלו
select Email, [Friendship Period]
from

(select *,  [Friendship Period] =  ABS(LEAD (DateDiff(yy, LastPurchase,FirstPurchase), 1) OVER( ORDER BY FIRSTPURCHASE))
from (select c.email, FirstPurchase = First_Value(O.[Order Date]) OVER (Partition By c.Email Order By [Order date]), LastPurchase = Last_Value(O.[Order Date]) OVER (Partition By c.Email Order By [Order date])
from ORDERS AS O JOIN CUSTOMERS AS C ON O.Email = C.Email
) as full_table

where firstpurchase <> LastPurchase)
as Friendship
where Friendship.[Friendship Period] >= 2


--שילוב מערכתי של מספר כלים
--טרנזקציה של תהליך רכישת מוצרים
create PROCEDURE dbo.Transaction_Management @email varchar(40), @AddressState varchar(20),@AddressCity varchar(20), @AddressStreet varchar(20), @AddressHouseNumber varchar(10), @AddressPostalCode varchar(10), @ShippingMethod varchar(20), @Account varchar(20)
as
declare @ORDERID bigint, @expirationM int, @expirationY int
set @expirationM = (select Month([Expiration Date]) from [CREDIT CARDS] where Account = @Account)
set @expirationY = (select Year([Expiration Date]) from [CREDIT CARDS] where Account = @Account)
IF (@expirationY < Year(GETDATE()) or (@expirationY = Year(GETDATE()) AND @expirationM <= Month(GETDATE())))
Begin

-- if credit card has expired: 

RAISERROR ('TRANSACTION IS INVALID. CREDIT CARD HAS EXPIRED', 18, 0)
RETURN 
END

--check if the shopping cart that is being sent is filled with products
-- if not, break the transaction

	IF ((@Email not in(select Email from CONTENT))OR (dbo.GetLastSC(@email) not in (select [Creation Date] from CONTENT)))
	BEGIN
    RAISERROR('NO ITEMS IN CART ', 18, 0)
    RETURN
	END

 
 -- insert into ORDER table
insert into ORDERS ([order ID], [Order Date], [Address- State], [Address- City], [Address- Street], [Address- House Number], [Address- Postal Code], [Shipping Method],Email,[Creation Date],Account)
values(dbo.GetLastoRDERid (),GETDATE(), @AddressState , @AddressCity, @AddressStreet, @AddressHouseNumber, @AddressPostalCode, @ShippingMethod,@email,dbo.GetLastSC(@email),@Account)


-- הפרוצדורה משתמשת בפונקציה הבאה המחזירה את תאריך עגלת הקניות העדכני ביותר
--function the returns the email and last date of shopping cart --> most relevant shopping cart.

CREATE FUNCTION GetLastSC (@email varchar(40))
RETURNS DateTime
AS BEGIN
DECLARE @MaxDate DateTime 
select @MaxDate = MAX([Creation Date]) from [SHOPPING CARTS] where Email like @email	
RETURN @MaxDate
END

--EXAMPLE
select Distinct Email, LastDate = dbo.GetLastSC('abeavenf8@home.pl')
from [SHOPPING CARTS]


-- מייצר קוד הזמנה חדש
CREATE FUNCTION GetLastoRDERid ()
RETURNS BIGINT
AS BEGIN
DECLARE @MaxOrderID BIGINT 
select @MaxOrderID = MAX([order ID]) from ORDERS 
RETURN (@MaxOrderID + 1)
END

--EXAMPLE
execute dbo.Transaction_Management 'akmiecet@cbslocal.com', 'Israel', 'Hertzliya', 'Ha Universita', '3', '498573', 'Express', '1001240098204370'


-- הוספת עגלת קניות חדש ללקוח שעשה הזמנה
CREATE TRIGGER  insert_new_SC on ORDERS for insert as insert into [SHOPPING CARTS] (Email, [Creation Date]) 
Values((Select Distinct Email from inserted), GETDATE())



-- מנוע חיפוש
-- מחזיר את המוצרים מקטגוריה מסוימת בטווח מחירים מסוים
CREATE PROCEDURE SP_RelevantSearch 	@Category varchar(20),@LB int, @UB int as
	SELECT 	ID, Price
	FROM 	PRODUCTS
	WHERE 	(Category like @Category) AND  (Price between @LB and @UB)
	order by Price 

execute SP_RelevantSearch 'shoes', 90, 100


-- מחזיר פרטים נוספים על המוצר הנבחר
CREATE PROCEDURE SP_ShowMoreDetails 	@ID int as 
	SELECT 	ID, Category, Price, Description
	FROM 	PRODUCTS
	WHERE 	ID like @ID

	--EXAMPLE
execute SP_ShowMoreDetails 10255


--מכניס את החיפוש לטבלת החיפושים
CREATE PROCEDURE Insert_Search_Details 	@UserID varchar(40), @SearchDT DateTime, @Category varchar(40) ,@LB varchar(10) ,@UB varchar(10), @searchDuration varchar(10), @Product varchar(40) as 
	insert into excel_details ([User ID], [Search DT], [Category], [LB], [UB], [Search Duration], [Selected Product])VALUES
	(@UserID, @SearchDT, @Category, @LB, @UB, @searchDuration, @Product)




USE [my_db]
GO
/****** Object:  StoredProcedure [dbo].[open_contract]    Script Date: 31.05.2018 5:00:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[open_contract](@client_id VARCHAR(20), @yacht_id INT, @expected_closing_date DATE, @openning_date DATE = NULL) AS
BEGIN
	IF(@openning_date IS NULL)
		SET @openning_date = CURRENT_TIMESTAMP

	DECLARE @prolongation INT = DATEDIFF(day, @openning_date, @expected_closing_date);
	IF(@prolongation <= 0)
	BEGIN
		RAISERROR('The openning day must be earlier then the closing', 15, 1)
		RETURN
	END

	DECLARE @payment_scheme CHAR(13);
	IF(@prolongation <= 7)
		SET @payment_scheme = 'upfront'
	ELSE IF (@prolongation <= 30)
		SET @payment_scheme = 'half upfront'
	ELSE 
		SET @payment_scheme = 'monthly'
	DECLARE @paid_until DATE;
	DECLARE @money_paid MONEY;
	DECLARE @per_month MONEY = (SELECT cost_per_month
								FROM classes
								WHERE rang = (SELECT class_rang
											  FROM yachts
											  WHERE id = @yacht_id));
	DECLARE @per_day MONEY = (SELECT cost_per_day
								FROM classes
								WHERE rang = (SELECT class_rang
											  FROM yachts
											  WHERE id = @yacht_id));
	IF(@payment_scheme = 'upfront') 
		BEGIN
		SET @paid_until = @expected_closing_date;
		SET @money_paid = (@prolongation / 30) * @per_month + (@prolongation % 30) * @per_day;
		END
	ELSE IF(@payment_scheme = 'monthly')
		BEGIN
		SET @paid_until = DATEADD(day, 30, @openning_date);
		SET @money_paid = @per_month;
		END
	ELSE -- half upfront
		BEGIN
		SET @paid_until = @expected_closing_date;
		SET @money_paid = ((@prolongation / 30) * @per_month + (@prolongation % 30) * @per_day) / 2;
		END

	INSERT INTO contracts(yacht_id, client_id, openning_date, expected_closing_date, actual_closing_date, payment_scheme, paid_until, money_paid)
	VALUES (@yacht_id, @client_id, @openning_date, @expected_closing_date, null, @payment_scheme, @paid_until, @money_paid);
END
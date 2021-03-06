USE [my_db]
GO
/****** Object:  StoredProcedure [dbo].[accept_payment]    Script Date: 31.05.2018 3:47:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[accept_payment] (@contract_number INT, @curr_date DATE) AS
BEGIN
	DECLARE @payment_scheme CHAR(13) = (SELECT payment_scheme
										FROM contracts
										WHERE number = @contract_number)

	IF(@payment_scheme != 'monthly')
	BEGIN
		RAISERROR('The payment for not monthly contracts is to be taken upon closing or openning the contract', 14, 1)
		RETURN
	END

	DECLARE @closing DATE = (SELECT expected_closing_date
							 FROM contracts
							 WHERE number = @contract_number)
	DECLARE @paid_until DATE = (SELECT paid_until
							    FROM contracts
							    WHERE number = @contract_number)

	IF(DATEDIFF(day, @paid_until, @closing) < 30)
	BEGIN
		RAISERROR('The remaining payment is to be taken upon closing the contract', 14, 1)
		RETURN
	END

	IF(DATEDIFF(day, @paid_until, @curr_date) > 0)
		BEGIN
		DECLARE @client_id VARCHAR(20) = (SELECT client_id
										  FROM contracts
										  WHERE number = @contract_number)
		UPDATE clients
		SET times_payment_overdue = times_payment_overdue + 1
		WHERE id = @client_id;
		END

	DECLARE @money MONEY
	
	DECLARE @yacht_id INT = (SELECT yacht_id
							 FROM contracts
							 WHERE number = @contract_number)

	DECLARE @per_month MONEY = (SELECT cost_per_month
								FROM classes
								WHERE rang = (SELECT class_rang
											  FROM yachts
											  WHERE id = @yacht_id));


	UPDATE contracts 
	SET paid_until = DATEADD(day, 30, paid_until), money_paid = money_paid + @per_month
	WHERE number = @contract_number;

	PRINT 'The payment for ' + CAST(@per_month AS varchar(20)) + ' successfully came through'
END
USE [my_db]
GO
/****** Object:  Trigger [dbo].[checking_yacht_in_port_for_check]    Script Date: 31.05.2018 6:55:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER TRIGGER [dbo].[checking_yacht_in_port_for_check] ON [dbo].[yachts]
AFTER UPDATE AS
BEGIN
	IF(EXISTS (SELECT * 
			   FROM deleted
			   JOIN inserted
			   ON deleted.id = inserted.id
			   WHERE deleted.last_check <> inserted.last_check 
			   AND
			   deleted.placement <> 'in port'))
	BEGIN
		RAISERROR('Yacht should be in port to get checked', 16, 1);
		ROLLBACK;
	END

	IF(EXISTS (SELECT * 
			   FROM deleted
			   JOIN inserted
			   ON deleted.id = inserted.id
			   WHERE 
			   deleted.condition = 'in order'
			   AND
			   inserted.condition <> 'in order'))
	BEGIN
		UPDATE clients
		SET times_damaged = times_damaged + 1
		WHERE id = (SELECT client_id 
					FROM contracts 
					WHERE number = (SELECT MAX(contracts.number) 
									FROM contracts 
						 			JOIN inserted 
									ON contracts.yacht_id = inserted.id))
	END
END
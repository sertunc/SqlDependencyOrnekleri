USE master

-- Cleaning up before we start
IF  EXISTS (SELECT name FROM sys.databases WHERE name = N'KurumiciBilgilendirmeSistemi')
DROP DATABASE [KurumiciBilgilendirmeSistemi]
IF  EXISTS (SELECT * FROM sys.server_principals WHERE name = N'startUser')
DROP LOGIN [startUser]
IF  EXISTS (SELECT * FROM sys.server_principals WHERE name = N'subscribeUser')
DROP LOGIN [subscribeUser]

-- Creating a database
CREATE DATABASE [KurumiciBilgilendirmeSistemi]
GO

-- Ensuring that Service Broker is enabled 
ALTER DATABASE [KurumiciBilgilendirmeSistemi] SET ENABLE_BROKER
GO 

-- Creating users
CREATE LOGIN [startUser] WITH PASSWORD=N'startUser', 
            DEFAULT_DATABASE=[KurumiciBilgilendirmeSistemi], 
            CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
CREATE LOGIN [subscribeUser] WITH PASSWORD=N'subscribeUser', 
            DEFAULT_DATABASE=[KurumiciBilgilendirmeSistemi], CHECK_EXPIRATION=OFF, 
            CHECK_POLICY=OFF
GO

-- Switching to our database
use [KurumiciBilgilendirmeSistemi]

-- Creating a table. All changes made to the contents of this table will be
-- monitored.
CREATE TABLE [dbo].[Bilgilendirmeler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BilgilendirmeTipi] [varchar](50) NULL,
	[Baslik] [varchar](50) NULL,
	[Icerik] [nvarchar](max) NULL,
	[Tarih] [datetime] NULL,
 CONSTRAINT [PK_Bilgilendirmeler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

SET ANSI_PADDING OFF

GO

/****** Object:  StoredProcedure [dbo].[sp_BilgilendirmeEkle]    Script Date: 21.7.2015 10:53:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[sp_BilgilendirmeEkle] 
	@p_BilgilendirmeTipi varchar(50),
	@p_Baslik varchar(50),
	@p_Icerik nvarchar(500),
	@p_Tarih datetime  
AS
BEGIN
	
	SET NOCOUNT ON;

    TRUNCATE TABLE [dbo].[Bilgilendirmeler]
    INSERT INTO [dbo].[Bilgilendirmeler]([BilgilendirmeTipi],[Baslik],[Icerik]) VALUES(@p_BilgilendirmeTipi,@p_Baslik,@p_Icerik)
    INSERT INTO [dbo].[BilgilendirmelerArsiv]([BilgilendirmeTipi],[Baslik],[Icerik],[Tarih]) VALUES(@p_BilgilendirmeTipi,@p_Baslik,@p_Icerik,@p_Tarih)
END

GO
/*
 * Creating the users in this database
 *
 * We're going to create two users. One called startUser. This is the user 
 * that is going to have sufficient rights to run SqlDependency.Start.
 * The other user is called subscribeUser, and this is the user that is 
 * going to actually register for changes on the Users-table created earlier.
 * Technically, you're not obligated to make two different users naturally, 
 * but I did here anyway to make sure that I know the minimal rights required
 * for both operations
 *
 * Pay attention to the fact that the startUser-user has a default schema set.
 * This is critical for SqlDependency.Start to work. Below is explained why.
 */
CREATE USER [startUser] FOR LOGIN [startUser] 
WITH DEFAULT_SCHEMA = [startUser]
GO
CREATE USER [subscribeUser] FOR LOGIN [subscribeUser]
GO

/*
 * Creating the schema
 *
 * It is vital that we create a schema specifically for startUser and that we
 * make this user the owner of this schema. We also need to make sure that 
 * the default schema of this user is set to this new schema (we have done 
 * this earlier)
 *
 * If we wouldn't do this, then SqlDependency.Start would attempt to create 
 * some queues and stored procedures in the user's default schema which is
 * dbo. This would fail since startUser does not have sufficient rights to 
 * control the dbo-schema. Since we want to know the minimum rights startUser
 * needs to run SqlDependency.Start, we don't want to give him dbo priviliges.
 * Creating a separate schema ensures that SqlDependency.Start can create the
 * necessary objects inside this startUser schema without compromising 
 * security.
 */
CREATE SCHEMA [startUser] AUTHORIZATION [startUser]
GO

/*
 * Creating two new roles. We're not going to set the necessary permissions 
 * on the user-accounts, but we're going to set them on these two new roles.
 * At the end of this script, we're simply going to make our two users 
 * members of these roles.
 */
EXEC sp_addrole 'sql_dependency_subscriber' 
EXEC sp_addrole 'sql_dependency_starter' 

-- Permissions needed for [sql_dependency_starter]
GRANT CREATE PROCEDURE to [sql_dependency_starter] 
GRANT CREATE QUEUE to [sql_dependency_starter]
GRANT CREATE SERVICE to [sql_dependency_starter]
GRANT REFERENCES on 
CONTRACT::[http://schemas.microsoft.com/SQL/Notifications/PostQueryNotification]
  to [sql_dependency_starter] 
GRANT VIEW DEFINITION TO [sql_dependency_starter] 

-- Permissions needed for [sql_dependency_subscriber] 
GRANT SELECT to [sql_dependency_subscriber] 
GRANT SUBSCRIBE QUERY NOTIFICATIONS TO [sql_dependency_subscriber] 
GRANT RECEIVE ON QueryNotificationErrorsQueue TO [sql_dependency_subscriber] 
GRANT REFERENCES on 
CONTRACT::[http://schemas.microsoft.com/SQL/Notifications/PostQueryNotification]
  to [sql_dependency_subscriber] 

-- Making sure that my users are member of the correct role.
EXEC sp_addrolemember 'sql_dependency_starter', 'startUser'
EXEC sp_addrolemember 'sql_dependency_subscriber', 'subscribeUser'

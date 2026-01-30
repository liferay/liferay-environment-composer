USE master
GO
CREATE DATABASE %DATABASE_NAME%
ALTER DATABASE %DATABASE_NAME% set read_committed_snapshot on
ON (FILENAME = /var/opt/mssql/data/%DATABASE_NAME%.mdf),
(FILENAME = /var/opt/mssql/data/%DATABASE_NAME%.ldf)
FOR ATTACH
GO
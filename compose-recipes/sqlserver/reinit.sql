USE master
GO
CREATE DATABASE %DATABASE_NAME%
ON (FILENAME = /var/opt/mssql/data/%DATABASE_NAME%.mdf),
(FILENAME = /var/opt/mssql/data/%DATABASE_NAME%.ldf)
FOR ATTACH
GO
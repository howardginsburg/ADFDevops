--Create the watermark table.
CREATE TABLE [dbo].[Watermark](
	[TableName] [varchar](255) NULL,
	[WatermarkValue] [datetime] NULL
) ON [PRIMARY]
GO

--Insert tables from the Adventureworks database.
INSERT [dbo].[Watermark] ([TableName], [WatermarkValue]) VALUES ('adventureworks.SalesLT.Addresses', '1970-01-01')
INSERT [dbo].[Watermark] ([TableName], [WatermarkValue]) VALUES ('adventureworks.SalesLT.Customer', '1970-01-01')
INSERT [dbo].[Watermark] ([TableName], [WatermarkValue]) VALUES ('adventureworks.SalesLT.Product', '1970-01-01')
GO

CREATE PROCEDURE [dbo].[sp_updatewatermark] @LastModifiedtime datetime, @TableName varchar(50)
AS

BEGIN

    UPDATE Watermark
    SET [WatermarkValue] = @LastModifiedtime 
    WHERE [TableName] = @TableName

END
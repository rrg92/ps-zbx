/*
	This table will store a mapping to extended properties.
	This mapping will help "CMSProps" engine.
	The engine will use this mapping to query extended properties of master database searching for this.
 */ 

CREATE TABLE [cmsprops].[ExtendedMapping](
	CMSProp	 			nvarchar(300)
	,ExtendedProperty	sysname
)
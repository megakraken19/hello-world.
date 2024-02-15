SELECT
	*
FROM sys.schemas;
--------------------
SELECT
	*
FROM sys.tables
WHERE tables.is_ms_shipped = 0;
-----------------------
SELECT
	schemas.name AS Esquema,
	tables.name AS Nombre_Tabla
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
WHERE tables.is_ms_shipped = 0
ORDER BY schemas.name, tables.name;
------------------------
--######################
------------------------
--Columnas
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	columns.name AS Column_Name,
	ROW_NUMBER() OVER (PARTITION BY schemas.name, tables.name ORDER BY columns.column_id ASC) AS Ordinal_Position,
	--columns.max_length AS Column_Length,
	--columns.precision AS Column_Precision,
	--columns.scale AS Column_Scale,
	columns.collation_name AS Column_Collation,
	columns.is_nullable AS Is_Nullable,
	columns.is_identity AS Is_Identity,
	columns.is_computed AS Is_Computed,
	columns.is_sparse AS Is_Sparse
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id;
--------------------------------------
--Tipos de Datos
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	columns.name AS Column_Name,
	UPPER(types.name) AS Column_Data_Type,
	columns.max_length AS Column_Length,
	columns.precision AS Column_Precision,
	columns.scale AS Column_Scale
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
INNER JOIN sys.types
ON columns.user_type_id = types.user_type_id
order by Schema_Name, Table_Name;
----------------------------------
--Detalles de la Columna Identidad
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	columns.name AS Column_Name,
	UPPER(types.name) AS Column_Data_Type,
	CAST(identity_columns.seed_value AS BIGINT) AS Identity_Seed,
	CAST(identity_columns.increment_value AS BIGINT) AS Identity_Increment
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
INNER JOIN sys.types
ON columns.user_type_id = types.user_type_id
LEFT JOIN sys.identity_columns
ON columns.object_id = identity_columns.object_id
AND columns.column_id = identity_columns.column_id
where identity_columns.seed_value <> '' and identity_columns.increment_value <> ''
order by Schema_Name, Table_Name;
----------------------------------
--Restricciones por Defecto
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	columns.name AS Column_Name,
	UPPER(types.name) AS Column_Data_Type,
	default_constraints.name AS Default_Constraint_Name,
	UPPER(default_constraints.definition) AS Default_Constraint_Definition
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
INNER JOIN sys.types
ON columns.user_type_id = types.user_type_id
LEFT JOIN sys.default_constraints
ON schemas.schema_id = default_constraints.schema_id
AND columns.object_id = default_constraints.parent_object_id
AND columns.column_id = default_constraints.parent_column_id
where default_constraints.name <> '' and default_constraints.definition <> ''
order by Schema_Name, Table_Name;
----------------------------------------
--Columnas Computadas
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	columns.name AS Column_Name,
	UPPER(types.name) AS Column_Data_Type,
	UPPER(computed_columns.definition) AS Computed_Column_Definition
FROM sys.schemas
INNER JOIN sys.tables
ON schemas.schema_id = tables.schema_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
INNER JOIN sys.types
ON columns.user_type_id = types.user_type_id
LEFT JOIN sys.computed_columns
ON columns.object_id = computed_columns.object_id
AND columns.column_id = computed_columns.column_id
where computed_columns.definition <> ''
order by Schema_Name, Table_Name;
---------------------------------------------
--Índices y Definiciones de Claves Primarias
WITH CTE_INDEX_COLUMNS AS (
	SELECT
		TABLE_DATA.name AS Table_Name,
		INDEX_DATA.name AS Index_Name,
		SCHEMA_DATA.name AS Schema_Name,
		INDEX_DATA.is_unique,
		INDEX_DATA.has_filter,
		INDEX_DATA.filter_definition,
		INDEX_DATA.type_desc AS Index_Type,
		STUFF(( SELECT ', ' + columns.name + CASE WHEN index_columns.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
				FROM sys.tables
				INNER JOIN sys.indexes
				ON tables.object_id = indexes.object_id
				INNER JOIN sys.index_columns
				ON indexes.object_id = index_columns.object_id
				AND indexes.index_id = index_columns.index_id
				INNER JOIN sys.columns
				ON tables.object_id = columns.object_id
				AND index_columns.column_id = columns.column_id
				WHERE INDEX_DATA.object_id = indexes.object_id
				AND INDEX_DATA.index_id = indexes.index_id
				AND index_columns.is_included_column = 0
				ORDER BY index_columns.key_ordinal
			FOR XML PATH('')), 1, 2, '') AS Index_Column_List,
			STUFF(( SELECT ', ' + columns.name
				FROM sys.tables
				INNER JOIN sys.indexes
				ON tables.object_id = indexes.object_id
				INNER JOIN sys.index_columns
				ON indexes.object_id = index_columns.object_id
				AND indexes.index_id = index_columns.index_id
				INNER JOIN sys.columns
				ON tables.object_id = columns.object_id
				AND index_columns.column_id = columns.column_id
				WHERE INDEX_DATA.object_id = indexes.object_id
				AND INDEX_DATA.index_id = indexes.index_id
				AND index_columns.is_included_column = 1
				ORDER BY index_columns.key_ordinal
			FOR XML PATH('')), 1, 2, '') AS Include_Column_List,
		Is_Primary_Key
	FROM sys.indexes INDEX_DATA
	INNER JOIN sys.tables TABLE_DATA
	ON TABLE_DATA.object_id = INDEX_DATA.object_id
	INNER JOIN sys.schemas SCHEMA_DATA
	ON TABLE_DATA.schema_id = SCHEMA_DATA.schema_id)
SELECT
	Table_Name,
	Index_Name,
	Schema_Name,
	is_unique,
	has_filter,
	filter_definition,
	Index_Type,
	Index_Column_List,
	ISNULL(Include_Column_List, '') AS Include_Column_List,
	Is_Primary_Key
FROM CTE_INDEX_COLUMNS
WHERE CTE_INDEX_COLUMNS.Index_Type <> 'HEAP'
order by Schema_Name, Table_Name;
---------------------------------------------
--Claves Foráneas
SELECT
	tables.name AS Foreign_Key_Table_Name,
	schemas.name AS Foreign_Key_Schema_Name,
	foreign_keys.name AS Foreign_Key_Name
FROM sys.foreign_keys
INNER JOIN sys.tables
ON tables.object_id = foreign_keys.parent_object_id
INNER JOIN sys.schemas
ON schemas.schema_id = tables.schema_id
order by Foreign_Key_Table_Name;

SELECT
	foreign_keys.name AS Foreign_Key_Name,
	FOREIGN_KEY_TABLE.name AS Foreign_Key_Table_Name,
	FOREIGN_KEY_COLUMN.name AS Foreign_Key_Column_Name,
	REFERENCED_TABLE.name AS Referenced_Table_Name,
	REFERENECD_COLUMN.name AS Referenced_Column_Name
FROM sys.foreign_key_columns
INNER JOIN sys.foreign_keys
ON foreign_keys.object_id = foreign_key_columns.constraint_object_id
INNER JOIN sys.tables FOREIGN_KEY_TABLE
ON foreign_key_columns.parent_object_id = FOREIGN_KEY_TABLE.object_id
INNER JOIN sys.columns as FOREIGN_KEY_COLUMN
ON foreign_key_columns.parent_object_id = FOREIGN_KEY_COLUMN.object_id 
AND foreign_key_columns.parent_column_id = FOREIGN_KEY_COLUMN.column_id
INNER JOIN sys.columns REFERENECD_COLUMN
ON foreign_key_columns.referenced_object_id = REFERENECD_COLUMN.object_id
AND foreign_key_columns.referenced_column_id = REFERENECD_COLUMN.column_id
INNER JOIN sys.tables REFERENCED_TABLE
ON REFERENCED_TABLE.object_id = foreign_key_columns.referenced_object_id
ORDER BY FOREIGN_KEY_TABLE.name, foreign_key_columns.constraint_column_id;





----------------------------------------------
--Restricciones CHECK **NO HAY DATOS
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	check_constraints.name AS Check_Constraint_Name,
	check_constraints.is_not_trusted AS With_Nocheck,
	check_constraints.definition AS Check_Constraint_Definition
FROM sys.check_constraints
INNER JOIN sys.tables
ON tables.object_id = check_constraints.parent_object_id
INNER JOIN sys.schemas
ON tables.schema_id = schemas.schema_id;
------------------------------------------
--Desencadenadores **NO HAY DATOS
SELECT
	schemas.name AS Schema_Name,
	tables.name AS Table_Name,
	sql_modules.definition AS Trigger_Definition
FROM sys.triggers
INNER JOIN sys.sql_modules
ON triggers.object_id = sql_modules.object_id
INNER JOIN sys.tables
ON triggers.parent_id = tables.object_id
INNER JOIN sys.schemas
ON schemas.schema_id = tables.schema_id;
-----------------------------------------------
--Propiedades Extendidas
SELECT
	Child.type_desc AS Object_Type,
	extended_properties.name AS Extended_Property_Name,
	CAST(extended_properties.value AS NVARCHAR(MAX)) AS Extended_Property_Value,
	schemas.name AS Schema_Name,
	Child.name AS Object_Name,
	Parent.name AS Parent_Object_Name,
	columns.name AS Parent_Column_Name,
	indexes.name AS Index_Name
FROM sys.extended_properties
INNER JOIN sys.objects Child
ON extended_properties.major_id = Child.object_id
INNER JOIN sys.schemas
ON schemas.schema_id = Child.schema_id
LEFT JOIN sys.objects Parent
ON Parent.object_id = Child.parent_object_id
LEFT JOIN sys.columns
ON Child.object_id = columns.object_id
AND extended_properties.minor_id = columns.column_id
AND extended_properties.class_desc = 'OBJECT_OR_COLUMN'
AND extended_properties.minor_id <> 0
LEFT JOIN sys.indexes
ON Child.object_id = indexes.object_id
AND extended_properties.minor_id = indexes.index_id
AND extended_properties.class_desc = 'INDEX'
WHERE Child.type_desc IN ('CHECK_CONSTRAINT', 'DEFAULT_CONSTRAINT', 'FOREIGN_KEY_CONSTRAINT', 'PRIMARY_KEY_CONSTRAINT', 'SQL_TRIGGER', 'USER_TABLE')
ORDER BY Child.type_desc ASC;
-------------------------











--######################
-------------------------
DECLARE @string NVARCHAR(MAX) = '';
SELECT @string = @string + name + ','
FROM sys.tables
WHERE tables.is_ms_shipped = 0
ORDER BY tables.name;
SELECT @string = LEFT(@string, LEN(@string) - 1);
SELECT @string;
-----------------------
DECLARE @string2 NVARCHAR(MAX) = '';
SELECT @string2 = 
		STUFF(( SELECT ', ' + tables.name
					FROM sys.tables
					WHERE tables.is_ms_shipped = 0
					ORDER BY tables.name
				FOR XML PATH('')), 1, 2, '')
SELECT @string2;
-------------------------
DECLARE @Database_Name NVARCHAR(MAX) = '';
IF @Database_Name IS NULL
	BEGIN
		RAISERROR('Document_Schema: Please provide a database name for this stored procedure', 16, 1);
		RETURN;			
	END
-----------------
SELECT @Sql_Command = '
			USE [' + @Database_Name + '];
			SELECT DISTINCT
				schemas.name
			FROM sys.schemas
			INNER JOIN sys.tables
			ON schemas.schema_id = tables.schema_id
			WHERE schemas.name = ''' + @Schema_Name + ''';'
		INSERT INTO @Schemas
			(Schema_Name)
		EXEC sp_executesql @Sql_Command;
 
		IF NOT EXISTS (SELECT * FROM @Schemas)
		BEGIN
			RAISERROR('Document_Schema: The schema name provided does not exist, or it contains no user tables', 16, 1);
			RETURN;			
		END
------------------
DECLARE @Schemas TABLE
	(Schema_Name SYSNAME NOT NULL);
 
DECLARE @Tables TABLE
	(Schema_Name SYSNAME, Table_Name SYSNAME NOT NULL, Result_Text NVARCHAR(MAX) NULL);
 
DECLARE @Columns TABLE
	(Schema_Name SYSNAME NOT NULL, Table_Name SYSNAME NOT NULL, Column_Name SYSNAME NOT NULL, Type_Name SYSNAME NOT NULL, Ordinal_Position SMALLINT NOT NULL,
		Column_Length SMALLINT NOT NULL, Column_Precision TINYINT NOT NULL, Column_Scale TINYINT NOT NULL, Column_Collation SYSNAME NULL, Is_Nullable BIT NOT NULL,
		Is_Identity BIT NOT NULL, Is_Computed BIT NOT NULL, is_sparse BIT NOT NULL, Identity_Seed BIGINT NULL, Identity_Increment BIGINT NULL,
		Default_Constraint_Name SYSNAME NULL, Default_Constraint_Definition NVARCHAR(MAX) NULL, Computed_Column_Definition NVARCHAR(MAX));
	
DECLARE @Foreign_Keys TABLE
	(Foreign_Key_Name SYSNAME NOT NULL, Foreign_Key_Schema_Name SYSNAME NOT NULL, Foreign_Key_Table_Name SYSNAME NOT NULL, Foreign_Key_Creation_Script NVARCHAR(MAX) NOT NULL);
 
DECLARE @Check_Constraints TABLE
	(Schema_Name SYSNAME, Table_Name SYSNAME, Check_Constraint_Definition NVARCHAR(MAX));
 
DECLARE @Indexes TABLE
	(Index_Name SYSNAME NOT NULL, Schema_Name SYSNAME NOT NULL, Table_Name SYSNAME NOT NULL, Is_Unique BIT NOT NULL, Has_Filter BIT NOT NULL, Filter_Definition NVARCHAR(MAX) NULL, Index_Type NVARCHAR(MAX) NOT NULL, Index_Column_List NVARCHAR(MAX) NULL, Include_Column_List NVARCHAR(MAX) NULL, Is_Primary_Key BIT NOT NULL);
 
DECLARE @Triggers TABLE
	(Schema_Name SYSNAME NOT NULL, Table_Name SYSNAME NOT NULL, Trigger_Definition NVARCHAR(MAX) NOT NULL);
 
DECLARE @Extended_Property TABLE
	(Object_Type NVARCHAR(60) NOT NULL, Extended_Property_Name SYSNAME NOT NULL, Extended_Property_Value NVARCHAR(MAX) NOT NULL, Schema_Name SYSNAME NOT NULL, Object_Name SYSNAME NOT NULL, Parent_Object_Name SYSNAME NULL, Parent_Column_Name SYSNAME NULL, Index_Name SYSNAME NULL);
------------------
DECLARE @Schema_List NVARCHAR(MAX) = '';
	SELECT
		@Schema_List = @Schema_List + '''' + Schema_Name + ''','
	FROM @Schemas;
	SELECT @Schema_List = LEFT(@Schema_List, LEN(@Schema_List) - 1); -- Remove trailing comma.
	-------------------------
SELECT @Sql_Command = '
		USE [' + @Database_Name + '];
		SELECT DISTINCT
			schemas.name AS Schema_Name,
			tables.name AS Table_Name
		FROM sys.tables
		INNER JOIN sys.schemas
		ON schemas.schema_id = tables.schema_id
		WHERE tables.is_ms_shipped = 0';
	IF @Table_Name IS NOT NULL
	BEGIN
		SELECT @Sql_Command = @Sql_Command + '
		AND tables.name = ''' + @Table_Name + '''';
	END
	SELECT @Sql_Command = @Sql_Command + '
		AND schemas.name IN (' + @Schema_List + ')';
 
	INSERT INTO @Tables
		(Schema_Name, Table_Name)
	EXEC sp_executesql @Sql_Command;
-------------------------------
DECLARE @Schema_Build_Text NVARCHAR(MAX);
DECLARE @Schema_Name_Current NVARCHAR(MAX);
DECLARE @Table_Name_Current NVARCHAR(MAX);
SELECT
			@Schema_Build_Text = @Schema_Build_Text + '
	' + COLUMN_DATA.Column_Name + ' ' + 
			CASE WHEN COLUMN_DATA.Is_Computed = 1 THEN '' ELSE -- Don't add metadata if a column is computed (just include definition)
			COLUMN_DATA.Type_Name + -- Basic column metadata
			CASE WHEN COLUMN_DATA.Type_Name = 'DECIMAL' THEN '(' + CAST(COLUMN_DATA.Column_Precision AS NVARCHAR(MAX)) + ',' + CAST(COLUMN_DATA.Column_Scale AS NVARCHAR(MAX)) + ')' ELSE '' END + -- Column precision (decimal)
			CASE WHEN COLUMN_DATA.Type_Name IN ('VARCHAR', 'NVARCHAR', 'NCHAR', 'CHAR') THEN '(' + CAST(COLUMN_DATA.Column_Length AS NVARCHAR(MAX)) + ')' ELSE '' END + -- Column length (string)
			CASE WHEN COLUMN_DATA.is_sparse = 1 THEN ' SPARSE' ELSE '' END + -- If a column is sparse, denote that here.
			CASE WHEN COLUMN_DATA.Is_Identity = 1 THEN ' IDENTITY(' + CAST(Identity_Seed AS NVARCHAR(MAX)) + ',' + CAST(Identity_Increment AS NVARCHAR(MAX)) + ')' ELSE '' END + -- Identity Metadata (optional)
			CASE WHEN COLUMN_DATA.Is_Nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END + -- NULL/NOT NULL definition
			CASE WHEN COLUMN_DATA.Default_Constraint_Name IS NOT NULL THEN ' CONSTRAINT ' + COLUMN_DATA.Default_Constraint_Name + ' DEFAULT ' + COLUMN_DATA.Default_Constraint_Definition ELSE '' END END + -- Default constraint definition (optional)
			CASE WHEN COLUMN_DATA.Is_Computed = 1 THEN 'AS ' + COLUMN_DATA.Computed_Column_Definition ELSE '' END + ','
		FROM @Columns COLUMN_DATA
		WHERE COLUMN_DATA.Table_Name = @Table_Name_Current
		AND COLUMN_DATA.Schema_Name = @Schema_Name_Current
		ORDER BY COLUMN_DATA.Ordinal_Position ASC;
 
		SELECT @Schema_Build_Text = LEFT(@Schema_Build_Text, LEN(@Schema_Build_Text) - 1);
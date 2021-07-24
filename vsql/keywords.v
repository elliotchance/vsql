module vsql

fn is_reserved_word(word string) bool {
	reserved_words := ['ABS', 'ACOS', 'ALL', 'ALLOCATE', 'ALTER', 'AND', 'ANY', 'ARE', 'ARRAY',
		'ARRAY_AGG', 'ARRAY_MAX_CARDINALITY', 'AS', 'ASENSITIVE', 'ASIN', 'ASYMMETRIC', 'AT', 'ATAN',
		'ATOMIC', 'AUTHORIZATION', 'AVG', 'BEGIN', 'BEGIN_FRAME', 'BEGIN_PARTITION', 'BETWEEN',
		'BIGINT', 'BINARY', 'BLOB', 'BOOLEAN', 'BOTH', 'BY', 'CALL', 'CALLED', 'CARDINALITY',
		'CASCADED', 'CASE', 'CAST', 'CEIL', 'CEILING', 'CHAR', 'CHAR_LENGTH', 'CHARACTER',
		'CHARACTER_LENGTH', 'CHECK', 'CLASSIFIER', 'CLOB', 'CLOSE', 'COALESCE', 'COLLATE', 'COLLECT',
		'COLUMN', 'COMMIT', 'CONDITION', 'CONNECT', 'CONSTRAINT', 'CONTAINS', 'CONVERT', 'COPY',
		'CORR', 'CORRESPONDING', 'COS', 'COSH', 'COUNT', 'COVAR_POP', 'COVAR_SAMP', 'CREATE', 'CROSS',
		'CUBE', 'CUME_DIST', 'CURRENT', 'CURRENT_CATALOG', 'CURRENT_DATE',
		'CURRENT_DEFAULT_TRANSFORM_GROUP', 'CURRENT_PATH', 'CURRENT_ROLE', 'CURRENT_ROW',
		'CURRENT_SCHEMA', 'CURRENT_TIME', 'CURRENT_TIMESTAMP', 'CURRENT_PATH', 'CURRENT_ROLE',
		'CURRENT_TRANSFORM_GROUP_FOR_TYPE', 'CURRENT_USER', 'CURSOR', 'CYCLE', 'DATE', 'DAY',
		'DEALLOCATE', 'DEC', 'DECIMAL', 'DECFLOAT', 'DECLARE', 'DEFAULT', 'DEFINE', 'DELETE',
		'DENSE_RANK', 'DEREF', 'DESCRIBE', 'DETERMINISTIC', 'DISCONNECT', 'DISTINCT', 'DOUBLE',
		'DROP', 'DYNAMIC', 'EACH', 'ELEMENT', 'ELSE', 'EMPTY', 'END', 'END_FRAME', 'END_PARTITION',
		'END-EXEC', 'EQUALS', 'ESCAPE', 'EVERY', 'EXCEPT', 'EXEC', 'EXECUTE', 'EXISTS', 'EXP',
		'EXTERNAL', 'EXTRACT', 'FALSE', 'FETCH', 'FILTER', 'FIRST_VALUE', 'FLOAT', 'FLOOR', 'FOR',
		'FOREIGN', 'FRAME_ROW', 'FREE', 'FROM', 'FULL', 'FUNCTION', 'FUSION', 'GET', 'GLOBAL',
		'GRANT', 'GROUP', 'GROUPING', 'GROUPS', 'HAVING', 'HOLD', 'HOUR', 'IDENTITY', 'IN',
		'INDICATOR', 'INITIAL', 'INNER', 'INOUT', 'INSENSITIVE', 'INSERT', 'INT', 'INTEGER',
		'INTERSECT', 'INTERSECTION', 'INTERVAL', 'INTO', 'IS', 'JOIN', 'JSON_ARRAY', 'JSON_ARRAYAGG',
		'JSON_EXISTS', 'JSON_OBJECT', 'JSON_OBJECTAGG', 'JSON_QUERY', 'JSON_TABLE',
		'JSON_TABLE_PRIMITIVE', 'JSON_VALUE', 'LAG', 'LANGUAGE', 'LARGE', 'LAST_VALUE', 'LATERAL',
		'LEAD', 'LEADING', 'LEFT', 'LIKE', 'LIKE_REGEX', 'LISTAGG', 'LN', 'LOCAL', 'LOCALTIME',
		'LOCALTIMESTAMP', 'LOG', 'LOG10', 'LOWER', 'MATCH', 'MATCH_NUMBER', 'MATCH_RECOGNIZE',
		'MATCHES', 'MAX', 'MEMBER', 'MERGE', 'METHOD', 'MIN', 'MINUTE', 'MOD', 'MODIFIES', 'MODULE',
		'MONTH', 'MULTISET', 'NATIONAL', 'NATURAL', 'NCHAR', 'NCLOB', 'NEW', 'NO', 'NONE',
		'NORMALIZE', 'NOT', 'NTH_VALUE', 'NTILE', 'NULL', 'NULLIF', 'NUMERIC', 'OCTET_LENGTH',
		'OCCURRENCES_REGEX', 'OF', 'OFFSET', 'OLD', 'OMIT', 'ON', 'ONE', 'ONLY', 'OPEN', 'OR',
		'ORDER', 'OUT', 'OUTER', 'OVER', 'OVERLAPS', 'OVERLAY', 'PARAMETER', 'PARTITION', 'PATTERN',
		'PER', 'PERCENT', 'PERCENT_RANK', 'PERCENTILE_CONT', 'PERCENTILE_DISC', 'PERIOD', 'PORTION',
		'POSITION', 'POSITION_REGEX', 'POWER', 'PRECEDES', 'PRECISION', 'PREPARE', 'PRIMARY',
		'PROCEDURE', 'PTF', 'RANGE', 'RANK', 'READS', 'REAL', 'RECURSIVE', 'REF', 'REFERENCES',
		'REFERENCING', 'REGR_AVGX', 'REGR_AVGY', 'REGR_COUNT', 'REGR_INTERCEPT', 'REGR_R2',
		'REGR_SLOPE', 'REGR_SXX', 'REGR_SXY', 'REGR_SYY', 'RELEASE', 'RESULT', 'RETURN', 'RETURNS',
		'REVOKE', 'RIGHT', 'ROLLBACK', 'ROLLUP', 'ROW', 'ROW_NUMBER', 'ROWS', 'RUNNING', 'SAVEPOINT',
		'SCOPE', 'SCROLL', 'SEARCH', 'SECOND', 'SEEK', 'SELECT', 'SENSITIVE', 'SESSION_USER', 'SET',
		'SHOW', 'SIMILAR', 'SIN', 'SINH', 'SKIP', 'SMALLINT', 'SOME', 'SPECIFIC', 'SPECIFICTYPE',
		'SQL', 'SQLEXCEPTION', 'SQLSTATE', 'SQLWARNING', 'SQRT', 'START', 'STATIC', 'STDDEV_POP',
		'STDDEV_SAMP', 'SUBMULTISET', 'SUBSET', 'SUBSTRING', 'SUBSTRING_REGEX', 'SUCCEEDS', 'SUM',
		'SYMMETRIC', 'SYSTEM', 'SYSTEM_TIME', 'SYSTEM_USER', 'TABLE', 'TABLESAMPLE', 'TAN', 'TANH',
		'THEN', 'TIME', 'TIMESTAMP', 'TIMEZONE_HOUR', 'TIMEZONE_MINUTE', 'TO', 'TRAILING',
		'TRANSLATE', 'TRANSLATE_REGEX', 'TRANSLATION', 'TREAT', 'TRIGGER', 'TRIM', 'TRIM_ARRAY',
		'TRUE', 'TRUNCATE', 'UESCAPE', 'UNION', 'UNIQUE', 'UNKNOWN', 'UNNEST', 'UPDATE', 'UPPER',
		'USER', 'USING', 'VALUE', 'VALUES', 'VALUE_OF', 'VAR_POP', 'VAR_SAMP', 'VARBINARY', 'VARCHAR',
		'VARYING', 'VERSIONING', 'WHEN', 'WHENEVER', 'WHERE', 'WIDTH_BUCKET', 'WINDOW', 'WITH',
		'WITHIN', 'WITHOUT', 'YEAR']

	return word.to_upper() in reserved_words
}

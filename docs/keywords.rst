Keywords
========

Names of entities (such as tables and columns) cannot be a reserved word. The
reserved words are those of SQL:2023 (ISO/IEC 9075-2:2023, 5.2), which are the
tokens listed under ``// reserved words`` in
`grammar.y <https://github.com/elliotchance/vsql/blob/main/vsql/grammar.y>`_.

A reserved word can still be used as a name if it is quoted, such as
``"ORDER"``.

A name can have up to 128 characters, quoted or not. Longer names are a
``42601`` error.

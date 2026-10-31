SQL Standard
============

`ISO/IEC 9075 <https://www.iso.org/standard/76583.html>`_ is the formal name for
what is more colloquially known as the *SQL standard*. Every few years a new
`version is published <https://en.wikipedia.org/wiki/SQL#Standardization_history>`_.

Each version is split into multiple parts.
`Part 2: Foundation (SQL/Foundation) <https://www.iso.org/standard/76584.html>`_
is the largest part (in terms of pages) and covers the syntax and behavior for
the core SQL language. It's also the most relevant part for this project.

vsql works against **SQL:2016** (ISO/IEC 9075-2:2016), as well as
`Part 3: Call-Level Interface (SQL/CLI) <https://www.iso.org/standard/63557.html>`_
for :doc:`language-c`, and
`Part 11: Information and Definition Schemas (SQL/Schemata) <https://www.iso.org/standard/63565.html>`_
for the ``INFORMATION_SCHEMA``. Not every part is available at the latest
edition, so the code cites the latest edition that we have of each part (see
:doc:`standard-index`). The source files are named after the part and section
of the standard that they implement (such as
``std_2_14_14_update_statement_searched.v`` for Part 2, section 14.14),
:doc:`sql-compliance` lists which features are supported, and
:doc:`standard-index` tracks each rule. Most of the features
in common use were published by 2003, so older versions (such as 1999) are
still relevant and helpful because they contain most of the core features.

**Unfortunately, the SQL Standard is not free (and is very expensive).** This
includes all previous versions. This is obviously a challenge for an open-source
project. While we cannot include a copy of the standard, the next best option is
to provide a list of locations where it exists:

* `SQL:2016 Foundation Grammar (BNF) <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_
* `SQL:2003 (working draft) <https://synthesis.frccsc.ru/synthesis/student/oodb/essayRef/sqlFoundation.pdf>`_
* `SQL:1999 (final draft) (1) <https://web.cecs.pdx.edu/~len/sql1999.pdf>`_
* `SQL:1999 (final draft) (2) <http://courses.cms.caltech.edu/cs123/sql99std/ansi-iso-9075-2-1999.pdf>`_
* `SQL-99 Complete, Really <https://sql-99.readthedocs.io/en/latest/>`_ is the digitized version of `the book with the same name <https://www.amazon.com/SQL-99-Complete-Really-Peter-Gulutzan/dp/0879305681>`_ brought to you by CrateDB.

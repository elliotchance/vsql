Standard Index
==============

.. contents::

The standard index (in ``docs/standard/``) has a row for every Subclause and
every numbered rule (Syntax Rules, Access Rules, General Rules, Conformance
Rules and, for Part 11, the numbered items of the Description) of the parts of
the SQL standard that vsql implements. Each row records whether vsql implements
it, where, and how it's tested.

:doc:`sql-compliance` lists which features are supported. The index is the
detail underneath that: it's how to find what isn't covered yet, or what needs
a closer look, one rule at a time.

The standard is copyrighted, so the index only has the numbers and titles of
the Subclauses, never the text of the rules. Notes are in our own words.

Editions
--------

Not every part is available at the same (or the latest) edition, so each part
uses the latest edition that we have. They are listed in
``docs/standard/editions.txt``, with the SHA-256 of the PDF that the index was
generated from:

.. list-table::
   :header-rows: 1

   * - Part
     - Citation
     - Source

   * - 1 (Framework)
     - ISO/IEC 9075-1:2003(E)
     - SQL:2003 working draft (2003-09)

   * - 2 (Foundation)
     - ISO/IEC 9075-2:2016(E)
     - SQL:2016

   * - 3 (Call-Level Interface)
     - ISO/IEC 9075-3:2003(E)
     - SQL:2003 working draft (2003-09)

   * - 11 (Information and Definition Schemas)
     - ISO/IEC 9075-11:2008(E)
     - SQL:2008 committee draft (2006-02)

Every citation in the code must be for the edition of its part. When a newer
edition is available:

1. Put its PDF in ``standard_docs/`` and update the part in ``editions.txt``
   (its citation, SHA-256 and source).
2. Run ``scripts/standard-index.py generate``. It keeps the status, code, tests
   and note of every row that still exists, and prints the reviewed rows that
   don't (because the edition renumbered them), so they can be moved by hand.
3. Run ``make check-standard-index``. It fails for every citation of the old
   edition, which then needs to be checked against the new one.

Files
-----

There is a directory for each part (such as ``docs/standard/part2/``) with a
file for each clause (``08.txt`` for 8), which has the rows of every Subclause
within it (such as 8.8 and 8.8.1). Each Subclause starts with a heading line
(such as ``# 8.8, <null predicate>``).

Each row is one line with the columns separated by spaces:

.. code-block:: text

  8.8/GR/2.a               implemented  vsql/std_2_8_8_null_predicate.v tests/null.sql NULL is NULL

1. **ID**: the Subclause, then (for a rule) the section (``SR`` for Syntax
   Rules, ``AR`` for Access Rules, ``GR`` for General Rules, ``CR`` for
   Conformance Rules and ``DE`` for Description) and the rule, with a dot
   between each level. So ``8.8/GR/2.b.i`` is General Rule 2) b) i) of 8.8.
2. **Status**: one of the statuses below.
3. **Code**: the files (separated by commas, without spaces) that implement the
   rule, or ``-``. Each must cite the rule (or a rule that contains it, or is
   within it).
4. **Tests**: the test files (separated by commas) that test the rule, or
   ``-``.
5. **Note**: the rest of the line, in our own words. It's optional, except for
   some statuses.

Statuses
--------

.. list-table::
   :header-rows: 1

   * - Status
     - Meaning

   * - ``todo``
     - Not reviewed yet. Every row starts as ``todo``.

   * - ``implemented``
     - Implemented and tested. Needs code and tests.

   * - ``untested``
     - Implemented, but there's no test for it. Needs code. It counts as
       implemented, but it's listed by the report.

   * - ``partial``
     - Implemented, but not completely. Needs code and tests, and the note says
       what's missing.

   * - ``missing``
     - Applies to vsql, but isn't implemented. The note needs an issue
       (``#123``).

   * - ``deviates``
     - Implemented differently on purpose. The note needs an issue (``#123``)
       that explains why.

   * - ``n/a``
     - Doesn't apply, because it depends on something vsql doesn't support. The
       note says what (ideally a Feature ID, such as ``S023``).

   * - ``definition``
     - Only defines terms that other rules use, so there is nothing to
       implement on its own.

   * - ``container``
     - Only groups the rules within it (such as "Case:"). The generator marks
       the ones that are only "Case:" or "Otherwise:".

   * - ``impl-defined``
     - Implementation-defined. The note says what vsql does.

   * - ``untestable``
     - Can't be observed by a test (such as which of several equal values is
       returned). The note says why.

   * - ``unclear``
     - Needs someone to interpret it. The note says what's unclear.

Citations
---------

A citation of the standard in the code looks like:

.. code-block:: text

  ISO/IEC 9075-2:2016(E), 8.8, <null predicate>, General Rules, 2.a

The title (``<null predicate>``) and the rules are optional. The title must be
the title of the Subclause, or one of the ``<...>`` names in it (such as
``<token>`` for 5.2, ``<token> and <separator>``). Several rules are written as
``2, 4 and 5`` or ``2-4``. Rules are always plural ("Syntax Rules, 2") and each
level is separated by a dot (``2.b.i``, not ``2b.i``).

A citation can be wrapped over several lines of a comment. Describe the rule in
your own words next to it, rather than quoting the standard.

Checking
--------

.. code-block:: sh

  make check-standard-index

checks (without the PDFs) that:

- Every citation in the code is for the edition in ``editions.txt``, and its
  Subclause, title and rules are in the index.
- Every row has a known status, and the code, tests and note that its status
  needs. Each code file must cite the rule.

It runs in CI.

Reviewing a Subclause
---------------------

The PDFs are in ``standard_docs/``, which isn't committed. With them (and
``pypdf``), this prints the rows of a Subclause, each with the text of the rule
and the code that cites it:

.. code-block:: sh

  scripts/standard-index.py show 2 8.8

That's everything needed to review a Subclause: set the status of each row (and
its code, tests and note), add a citation to the code where a rule is
implemented, then run ``make check-standard-index``. Rows can be edited by hand,
or with ``set`` (which doesn't need the PDFs). An ID ending with ``*`` sets the
row and every rule within it:

.. code-block:: sh

  scripts/standard-index.py set 2 8.8/GR/2.a implemented \
    vsql/std_2_8_8_null_predicate.v tests/null.sql
  scripts/standard-index.py set 2 '8.2/GR/1.b.ii*' n/a - - 'arrays (S091)'

Reports
-------

``scripts/standard-index.py report`` (or ``report 2`` for each clause of Part 2)
prints how much has been reviewed and implemented, and lists the rows that need
attention (see :doc:`sql-compliance`). It doesn't need the PDFs.

Since every row is one line, the work left is also easy to find, for example:

.. code-block:: sh

  # Clauses that haven't been fully reviewed yet.
  grep -l ' todo ' docs/standard/part2/*.txt

  # Rules that need someone to interpret them.
  grep -r ' unclear ' docs/standard

  # The issues for missing rules.
  grep -rh ' missing ' docs/standard | grep -o '#[0-9]*' | sort -u

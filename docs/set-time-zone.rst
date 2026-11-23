SET TIME ZONE
=============

.. contents::

Syntax
------

.. code-block:: text

  SET TIME ZONE LOCAL
  SET TIME ZONE <interval>

``SET TIME ZONE LOCAL`` sets the time zone of the connection back to the one it
started with, which is the time zone of its clock (see
:doc:`dates-times`). The time zone is used by ``CURRENT_TIME``,
``CURRENT_TIMESTAMP`` and ``AT LOCAL``, and for values without a time zone that
are compared to or cast to values with a time zone.

``SET TIME ZONE <interval>`` sets the time zone of the connection to an
``INTERVAL HOUR TO MINUTE``, such as ``INTERVAL '+05:30' HOUR TO MINUTE``. It
must be between ``-14:00`` and ``+14:00``, otherwise it's a ``22009`` error
(as is ``NULL``).

``SET TIME ZONE`` doesn't start a transaction, and it can be used in one.

Examples
--------

.. code-block:: sql

  SET TIME ZONE INTERVAL '-03:30' HOUR TO MINUTE;
  VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL;
  -- msg: SET TIME ZONE
  -- COL1: 2022-07-04T08:30:00-0330

  SET TIME ZONE LOCAL;
  -- msg: SET TIME ZONE

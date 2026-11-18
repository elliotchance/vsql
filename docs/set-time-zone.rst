SET TIME ZONE
=============

.. contents::

Syntax
------

.. code-block:: text

  SET TIME ZONE LOCAL

``SET TIME ZONE LOCAL`` sets the time zone of the connection back to the one it
started with, which is the time zone of its clock (see
:doc:`dates-times`). The time zone is used by ``CURRENT_TIME``,
``CURRENT_TIMESTAMP`` and ``AT LOCAL``, and for values without a time zone that
are compared to or cast to values with a time zone.

Setting another time zone (``SET TIME ZONE INTERVAL '+05:30' HOUR TO MINUTE``)
isn't supported yet, because it needs an ``INTERVAL``.

``SET TIME ZONE`` doesn't start a transaction, and it can be used in one.

Examples
--------

.. code-block:: sql

  SET TIME ZONE LOCAL;
  -- msg: SET TIME ZONE

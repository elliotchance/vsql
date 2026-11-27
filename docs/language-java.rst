Language: Java
==============

`vsql-java <https://github.com/elliotchance/vsql-java>`_ is a JDBC driver. It's
built on libvsql (see :doc:`language-c`), which is in the jar for Linux, macOS
(ARM64 and x86-64) and Windows (x86-64), so there's nothing else to install.

The URL is ``jdbc:vsql:`` and the path of the database file (it's created if it
doesn't exist), or ``jdbc:vsql::memory:`` for a database that only exists for
the life of the connection. The repository's README describes transactions and
the Java type of each SQL type.

The jar is on Maven Central:

.. code-block:: xml

   <dependency>
     <groupId>io.github.elliotchance</groupId>
     <artifactId>vsql</artifactId>
     <version>1.2.8</version>
   </dependency>

.. contents::

Requirements
------------

Java 22 or later. libvsql is called with the
`Foreign Function and Memory API <https://openjdk.org/jeps/454>`_, which needs
native access to be enabled (``--enable-native-access=ALL-UNNAMED``), otherwise
the JVM prints a warning. It works on Linux with glibc 2.17 or later, macOS 11
or later, and Windows 10 or later.

Example
-------

The jar doesn't have any dependencies, so the example doesn't need Maven or
Gradle. Download the jar from Maven Central:

.. code-block:: sh

   mkdir example && cd example
   curl -LO https://repo1.maven.org/maven2/io/github/elliotchance/vsql/1.2.8/vsql-1.2.8.jar

Save this as ``Example.java``:

.. code-block:: java

   import java.sql.Connection;
   import java.sql.DriverManager;
   import java.sql.PreparedStatement;
   import java.sql.ResultSet;
   import java.sql.SQLException;
   import java.sql.Statement;

   public class Example {
       public static void main(String[] args) throws SQLException {
           try (Connection conn = DriverManager.getConnection("jdbc:vsql::memory:")) {
               try (Statement s = conn.createStatement()) {
                   s.execute("CREATE TABLE products (id INTEGER, name VARCHAR(50))");
               }

               try (PreparedStatement s = conn.prepareStatement(
                       "INSERT INTO products (id, name) VALUES (?, ?)")) {
                   s.setInt(1, 1);
                   s.setString(2, "Bolt");
                   s.executeUpdate();
                   s.setInt(1, 2);
                   s.setString(2, "Nut");
                   s.executeUpdate();
               }

               try (Statement s = conn.createStatement();
                       ResultSet rs = s.executeQuery("SELECT id, name FROM products ORDER BY id")) {
                   while (rs.next()) {
                       System.out.println(rs.getInt("id") + " " + rs.getString("name"));
                   }
               }
           }
       }
   }

Then run it:

.. code-block:: sh

   java --enable-native-access=ALL-UNNAMED -cp vsql-1.2.8.jar Example.java

Which prints:

.. code-block:: text

   1 Bolt
   2 Nut

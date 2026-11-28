module vsql

// Without -autofree (or -d ownership), V doesn't declare IClone, and copies of
// a Table, Index or Column can share memory, because the garbage collector
// frees it. With -autofree, IClone gives Table, Index and Column a deep clone()
// (see Storage.find_table and Table.column).
//
// A struct update copies from table.copy() rather than table ("Table{
// ...table.copy() }"), because -autofree copies the fields of table into the
// new struct without moving them, and then frees table (no small repro yet).
interface IClone {}

fn (t Table) clone() Table {
	return t
}

fn (i Index) clone() Index {
	return i
}

fn (c Column) clone() Column {
	return c
}

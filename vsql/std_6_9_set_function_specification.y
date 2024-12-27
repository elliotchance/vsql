%%

// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>
//
// Specify a value derived by the application of a function to an argument.

set_function_specification:
  aggregate_function { $$.v = $1.v as AggregateFunction }

%%

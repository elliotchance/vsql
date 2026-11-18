module vsql

// A Condition is an error (or warning) that's kept after it's returned, such
// as Connection.warnings. It isn't an IError because -autofree can't copy an
// IError out of a field or an array (vlang/v#32452): some error types (in
// vlib) can't be cloned. Every Condition can be, and it's the same error
// again with ierror.
pub type Condition = OtherError
	| SQLState
	| SQLState01001
	| SQLState01003
	| SQLState02000
	| SQLState01004
	| SQLState21000
	| SQLState24000
	| SQLState34000
	| SQLState22001
	| SQLState22003
	| SQLState22007
	| SQLState22009
	| SQLState2200B
	| SQLState2200C
	| SQLState2200H
	| SQLState22011
	| SQLState22012
	| SQLState2201E
	| SQLState2201F
	| SQLState2201G
	| SQLState22018
	| SQLState22019
	| SQLState2201B
	| SQLState2201W
	| SQLState2201X
	| SQLState22023
	| SQLState22025
	| SQLState22027
	| SQLState22029
	| SQLState23001
	| SQLState23502
	| SQLState23503
	| SQLState23505
	| SQLState23514
	| SQLState2BP01
	| SQLState3B001
	| SQLState3D000
	| SQLState3F000
	| SQLState42601
	| SQLState42P03
	| SQLState42702
	| SQLState42703
	| SQLState42704
	| SQLState42710
	| SQLState42803
	| SQLState42804
	| SQLState42830
	| SQLState42846
	| SQLState428C9
	| SQLState42P01
	| SQLState42P06
	| SQLState42P07
	| SQLState42P10
	| SQLState42723
	| SQLState42883
	| SQLState42P02
	| SQLState07006
	| SQLState08001
	| SQLState08002
	| SQLState08003
	| SQLState2C000
	| SQLState28000
	| SQLState2E000
	| SQLState01012
	| SQLState35000
	| SQLState25001
	| SQLState25002
	| SQLState25003
	| SQLState25004
	| SQLState25005
	| SQLState25006
	| SQLState25008
	| SQLState27000
	| SQLState0B000
	| SQLState40001
	| SQLState40002
	| SQLState40V01
	| SQLState0A000
	| SQLState42501
	| SQLState42P04
	| SQLState42602
	| SQLState55P03
	| SQLState54000
	| SQLState57014
	| SQLState58030
	| SQLStateXX000
	| SQLStateXX001

// OtherError is an error that isn't an SQLSTATE error of vsql, such as an error
// from the file system. Only its message and code are kept.
pub struct OtherError {
	message    string
	error_code int
}

fn (err OtherError) msg() string {
	return err.message
}

fn (err OtherError) code() int {
	return err.error_code
}

fn (err OtherError) clone() OtherError {
	return OtherError{
		message:    err.message.clone()
		error_code: err.error_code
	}
}

// condition_of is a copy of err that can be kept.
fn condition_of(err IError) Condition {
	return match err {
		OtherError { Condition(err.clone()) }
		SQLState { Condition(err.clone()) }
		SQLState01001 { Condition(err.clone()) }
		SQLState01003 { Condition(err.clone()) }
		SQLState02000 { Condition(err.clone()) }
		SQLState01004 { Condition(err.clone()) }
		SQLState21000 { Condition(err.clone()) }
		SQLState24000 { Condition(err.clone()) }
		SQLState34000 { Condition(err.clone()) }
		SQLState22001 { Condition(err.clone()) }
		SQLState22003 { Condition(err.clone()) }
		SQLState22007 { Condition(err.clone()) }
		SQLState22009 { Condition(err.clone()) }
		SQLState2200B { Condition(err.clone()) }
		SQLState2200C { Condition(err.clone()) }
		SQLState2200H { Condition(err.clone()) }
		SQLState22011 { Condition(err.clone()) }
		SQLState22012 { Condition(err.clone()) }
		SQLState2201E { Condition(err.clone()) }
		SQLState2201F { Condition(err.clone()) }
		SQLState2201G { Condition(err.clone()) }
		SQLState22018 { Condition(err.clone()) }
		SQLState22019 { Condition(err.clone()) }
		SQLState2201B { Condition(err.clone()) }
		SQLState2201W { Condition(err.clone()) }
		SQLState2201X { Condition(err.clone()) }
		SQLState22023 { Condition(err.clone()) }
		SQLState22025 { Condition(err.clone()) }
		SQLState22027 { Condition(err.clone()) }
		SQLState22029 { Condition(err.clone()) }
		SQLState23001 { Condition(err.clone()) }
		SQLState23502 { Condition(err.clone()) }
		SQLState23503 { Condition(err.clone()) }
		SQLState23505 { Condition(err.clone()) }
		SQLState23514 { Condition(err.clone()) }
		SQLState2BP01 { Condition(err.clone()) }
		SQLState3B001 { Condition(err.clone()) }
		SQLState3D000 { Condition(err.clone()) }
		SQLState3F000 { Condition(err.clone()) }
		SQLState42601 { Condition(err.clone()) }
		SQLState42P03 { Condition(err.clone()) }
		SQLState42702 { Condition(err.clone()) }
		SQLState42703 { Condition(err.clone()) }
		SQLState42704 { Condition(err.clone()) }
		SQLState42710 { Condition(err.clone()) }
		SQLState42803 { Condition(err.clone()) }
		SQLState42804 { Condition(err.clone()) }
		SQLState42830 { Condition(err.clone()) }
		SQLState42846 { Condition(err.clone()) }
		SQLState428C9 { Condition(err.clone()) }
		SQLState42P01 { Condition(err.clone()) }
		SQLState42P06 { Condition(err.clone()) }
		SQLState42P07 { Condition(err.clone()) }
		SQLState42P10 { Condition(err.clone()) }
		SQLState42723 { Condition(err.clone()) }
		SQLState42883 { Condition(err.clone()) }
		SQLState42P02 { Condition(err.clone()) }
		SQLState07006 { Condition(err.clone()) }
		SQLState08001 { Condition(err.clone()) }
		SQLState08002 { Condition(err.clone()) }
		SQLState08003 { Condition(err.clone()) }
		SQLState2C000 { Condition(err.clone()) }
		SQLState28000 { Condition(err.clone()) }
		SQLState2E000 { Condition(err.clone()) }
		SQLState01012 { Condition(err.clone()) }
		SQLState35000 { Condition(err.clone()) }
		SQLState25001 { Condition(err.clone()) }
		SQLState25002 { Condition(err.clone()) }
		SQLState25003 { Condition(err.clone()) }
		SQLState25004 { Condition(err.clone()) }
		SQLState25005 { Condition(err.clone()) }
		SQLState25006 { Condition(err.clone()) }
		SQLState25008 { Condition(err.clone()) }
		SQLState27000 { Condition(err.clone()) }
		SQLState0B000 { Condition(err.clone()) }
		SQLState40001 { Condition(err.clone()) }
		SQLState40002 { Condition(err.clone()) }
		SQLState40V01 { Condition(err.clone()) }
		SQLState0A000 { Condition(err.clone()) }
		SQLState42501 { Condition(err.clone()) }
		SQLState42P04 { Condition(err.clone()) }
		SQLState42602 { Condition(err.clone()) }
		SQLState55P03 { Condition(err.clone()) }
		SQLState54000 { Condition(err.clone()) }
		SQLState57014 { Condition(err.clone()) }
		SQLState58030 { Condition(err.clone()) }
		SQLStateXX000 { Condition(err.clone()) }
		SQLStateXX001 { Condition(err.clone()) }
		else {
			Condition(OtherError{
				message:    err.msg().clone()
				error_code: err.code()
			})
		}
	}
}

// ierror is the condition as an error, so it can be returned.
pub fn (c Condition) ierror() IError {
	return match c {
		OtherError { IError(c.clone()) }
		SQLState { IError(c.clone()) }
		SQLState01001 { IError(c.clone()) }
		SQLState01003 { IError(c.clone()) }
		SQLState02000 { IError(c.clone()) }
		SQLState01004 { IError(c.clone()) }
		SQLState21000 { IError(c.clone()) }
		SQLState24000 { IError(c.clone()) }
		SQLState34000 { IError(c.clone()) }
		SQLState22001 { IError(c.clone()) }
		SQLState22003 { IError(c.clone()) }
		SQLState22007 { IError(c.clone()) }
		SQLState22009 { IError(c.clone()) }
		SQLState2200B { IError(c.clone()) }
		SQLState2200C { IError(c.clone()) }
		SQLState2200H { IError(c.clone()) }
		SQLState22011 { IError(c.clone()) }
		SQLState22012 { IError(c.clone()) }
		SQLState2201E { IError(c.clone()) }
		SQLState2201F { IError(c.clone()) }
		SQLState2201G { IError(c.clone()) }
		SQLState22018 { IError(c.clone()) }
		SQLState22019 { IError(c.clone()) }
		SQLState2201B { IError(c.clone()) }
		SQLState2201W { IError(c.clone()) }
		SQLState2201X { IError(c.clone()) }
		SQLState22023 { IError(c.clone()) }
		SQLState22025 { IError(c.clone()) }
		SQLState22027 { IError(c.clone()) }
		SQLState22029 { IError(c.clone()) }
		SQLState23001 { IError(c.clone()) }
		SQLState23502 { IError(c.clone()) }
		SQLState23503 { IError(c.clone()) }
		SQLState23505 { IError(c.clone()) }
		SQLState23514 { IError(c.clone()) }
		SQLState2BP01 { IError(c.clone()) }
		SQLState3B001 { IError(c.clone()) }
		SQLState3D000 { IError(c.clone()) }
		SQLState3F000 { IError(c.clone()) }
		SQLState42601 { IError(c.clone()) }
		SQLState42P03 { IError(c.clone()) }
		SQLState42702 { IError(c.clone()) }
		SQLState42703 { IError(c.clone()) }
		SQLState42704 { IError(c.clone()) }
		SQLState42710 { IError(c.clone()) }
		SQLState42803 { IError(c.clone()) }
		SQLState42804 { IError(c.clone()) }
		SQLState42830 { IError(c.clone()) }
		SQLState42846 { IError(c.clone()) }
		SQLState428C9 { IError(c.clone()) }
		SQLState42P01 { IError(c.clone()) }
		SQLState42P06 { IError(c.clone()) }
		SQLState42P07 { IError(c.clone()) }
		SQLState42P10 { IError(c.clone()) }
		SQLState42723 { IError(c.clone()) }
		SQLState42883 { IError(c.clone()) }
		SQLState42P02 { IError(c.clone()) }
		SQLState07006 { IError(c.clone()) }
		SQLState08001 { IError(c.clone()) }
		SQLState08002 { IError(c.clone()) }
		SQLState08003 { IError(c.clone()) }
		SQLState2C000 { IError(c.clone()) }
		SQLState28000 { IError(c.clone()) }
		SQLState2E000 { IError(c.clone()) }
		SQLState01012 { IError(c.clone()) }
		SQLState35000 { IError(c.clone()) }
		SQLState25001 { IError(c.clone()) }
		SQLState25002 { IError(c.clone()) }
		SQLState25003 { IError(c.clone()) }
		SQLState25004 { IError(c.clone()) }
		SQLState25005 { IError(c.clone()) }
		SQLState25006 { IError(c.clone()) }
		SQLState25008 { IError(c.clone()) }
		SQLState27000 { IError(c.clone()) }
		SQLState0B000 { IError(c.clone()) }
		SQLState40001 { IError(c.clone()) }
		SQLState40002 { IError(c.clone()) }
		SQLState40V01 { IError(c.clone()) }
		SQLState0A000 { IError(c.clone()) }
		SQLState42501 { IError(c.clone()) }
		SQLState42P04 { IError(c.clone()) }
		SQLState42602 { IError(c.clone()) }
		SQLState55P03 { IError(c.clone()) }
		SQLState54000 { IError(c.clone()) }
		SQLState57014 { IError(c.clone()) }
		SQLState58030 { IError(c.clone()) }
		SQLStateXX000 { IError(c.clone()) }
		SQLStateXX001 { IError(c.clone()) }
	}
}

// msg is the human-readable message.
pub fn (c Condition) msg() string {
	return c.ierror().msg()
}

// code is the integer representation of the SQLSTATE. Convert it to a string
// with sqlstate_from_int.
pub fn (c Condition) code() int {
	return c.ierror().code()
}

fn (c Condition) clone() Condition {
	return match c {
		OtherError { Condition(c.clone()) }
		SQLState { Condition(c.clone()) }
		SQLState01001 { Condition(c.clone()) }
		SQLState01003 { Condition(c.clone()) }
		SQLState02000 { Condition(c.clone()) }
		SQLState01004 { Condition(c.clone()) }
		SQLState21000 { Condition(c.clone()) }
		SQLState24000 { Condition(c.clone()) }
		SQLState34000 { Condition(c.clone()) }
		SQLState22001 { Condition(c.clone()) }
		SQLState22003 { Condition(c.clone()) }
		SQLState22007 { Condition(c.clone()) }
		SQLState22009 { Condition(c.clone()) }
		SQLState2200B { Condition(c.clone()) }
		SQLState2200C { Condition(c.clone()) }
		SQLState2200H { Condition(c.clone()) }
		SQLState22011 { Condition(c.clone()) }
		SQLState22012 { Condition(c.clone()) }
		SQLState2201E { Condition(c.clone()) }
		SQLState2201F { Condition(c.clone()) }
		SQLState2201G { Condition(c.clone()) }
		SQLState22018 { Condition(c.clone()) }
		SQLState22019 { Condition(c.clone()) }
		SQLState2201B { Condition(c.clone()) }
		SQLState2201W { Condition(c.clone()) }
		SQLState2201X { Condition(c.clone()) }
		SQLState22023 { Condition(c.clone()) }
		SQLState22025 { Condition(c.clone()) }
		SQLState22027 { Condition(c.clone()) }
		SQLState22029 { Condition(c.clone()) }
		SQLState23001 { Condition(c.clone()) }
		SQLState23502 { Condition(c.clone()) }
		SQLState23503 { Condition(c.clone()) }
		SQLState23505 { Condition(c.clone()) }
		SQLState23514 { Condition(c.clone()) }
		SQLState2BP01 { Condition(c.clone()) }
		SQLState3B001 { Condition(c.clone()) }
		SQLState3D000 { Condition(c.clone()) }
		SQLState3F000 { Condition(c.clone()) }
		SQLState42601 { Condition(c.clone()) }
		SQLState42P03 { Condition(c.clone()) }
		SQLState42702 { Condition(c.clone()) }
		SQLState42703 { Condition(c.clone()) }
		SQLState42704 { Condition(c.clone()) }
		SQLState42710 { Condition(c.clone()) }
		SQLState42803 { Condition(c.clone()) }
		SQLState42804 { Condition(c.clone()) }
		SQLState42830 { Condition(c.clone()) }
		SQLState42846 { Condition(c.clone()) }
		SQLState428C9 { Condition(c.clone()) }
		SQLState42P01 { Condition(c.clone()) }
		SQLState42P06 { Condition(c.clone()) }
		SQLState42P07 { Condition(c.clone()) }
		SQLState42P10 { Condition(c.clone()) }
		SQLState42723 { Condition(c.clone()) }
		SQLState42883 { Condition(c.clone()) }
		SQLState42P02 { Condition(c.clone()) }
		SQLState07006 { Condition(c.clone()) }
		SQLState08001 { Condition(c.clone()) }
		SQLState08002 { Condition(c.clone()) }
		SQLState08003 { Condition(c.clone()) }
		SQLState2C000 { Condition(c.clone()) }
		SQLState28000 { Condition(c.clone()) }
		SQLState2E000 { Condition(c.clone()) }
		SQLState01012 { Condition(c.clone()) }
		SQLState35000 { Condition(c.clone()) }
		SQLState25001 { Condition(c.clone()) }
		SQLState25002 { Condition(c.clone()) }
		SQLState25003 { Condition(c.clone()) }
		SQLState25004 { Condition(c.clone()) }
		SQLState25005 { Condition(c.clone()) }
		SQLState25006 { Condition(c.clone()) }
		SQLState25008 { Condition(c.clone()) }
		SQLState27000 { Condition(c.clone()) }
		SQLState0B000 { Condition(c.clone()) }
		SQLState40001 { Condition(c.clone()) }
		SQLState40002 { Condition(c.clone()) }
		SQLState40V01 { Condition(c.clone()) }
		SQLState0A000 { Condition(c.clone()) }
		SQLState42501 { Condition(c.clone()) }
		SQLState42P04 { Condition(c.clone()) }
		SQLState42602 { Condition(c.clone()) }
		SQLState55P03 { Condition(c.clone()) }
		SQLState54000 { Condition(c.clone()) }
		SQLState57014 { Condition(c.clone()) }
		SQLState58030 { Condition(c.clone()) }
		SQLStateXX000 { Condition(c.clone()) }
		SQLStateXX001 { Condition(c.clone()) }
	}
}

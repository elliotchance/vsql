/*
Derived from Go's yacc tool
https://pkg.go.dev/golang.org/x/tools/cmd/goyacc

Derived from Inferno's utils/iyacc/yacc.c
http://code.google.com/p/inferno-os/source/browse/utils/iyacc/yacc.c

This copyright NOTICE applies to all files in this directory and
subdirectories, unless another copyright notice appears in a given
file or subdirectory.  If you take substantial code from this software to use in
other programs, you must somehow include with it an appropriate
copyright notice that includes the copyright notice and the other
notices below.  It is fine (and often tidier) to do that in a separate
file such as NOTICE, LICENCE or COPYING.

	Copyright © 1994-1999 Lucent Technologies Inc.  All rights reserved.
	Portions Copyright © 1995-1997 C H Forsyth (forsyth@terzarima.net)
	Portions Copyright © 1997-1999 Vita Nuova Limited
	Portions Copyright © 2000-2007 Vita Nuova Holdings Limited (www.vitanuova.com)
	Portions Copyright © 2004,2006 Bruce Ellis
	Portions Copyright © 2005-2007 C H Forsyth (forsyth@terzarima.net)
	Revisions Copyright © 2000-2007 Lucent Technologies Inc. and others
	Portions Copyright © 2009 The Go Authors. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

module main

// yacc
// major difference is lack of stem ("y" variable)
//
import flag
import os
import strings
import encoding.utf8

// the following are adjustable
// according to memory size
const actsize = 240000
const nstates = 16000
const tempsize = 16000

const syminc = 50 // increase for non-term or term
const ruleinc = 50 // increase for max rule length y.prodptr[i]
const prodinc = 100 // increase for productions     y.prodptr
const wsetinc = 50 // increase for working sets    y.wsets
const stateinc = 200 // increase for states          y.statemem

const private = 0xE000 // unicode private use

// relationships which must hold:
//	tempsize >= NTERMS + NNONTERM + 1;
//	tempsize >= nstates;
//

const ntbase = 0o10000
const errcode = 8190
const acceptcode = 8191
const yylexunk = 3
const tokstart = 4 // index of first defined token

// no, left, right, binary assoc.
const noasc = 0
const lasc = 1
const rasc = 2
const basc = 3

// flags for state generation
const done = 0
const mustdo = 1
const mustlookahead = 2

// flags for a rule having an action, and being reduced
const actflag = 4
const redflag = 8

// output parser flags
const yy_flag = -1000

// parse tokens
const identifier = private + 0
const mark = private + 1
const term = private + 2
const left = private + 3
const right = private + 4
const binary = private + 5
const prec = private + 6
const lcurly = private + 7
const identcolon = private + 8
const number = private + 9
const start = private + 10
const typedef = private + 11
const typename = private + 12
const union = private + 13
const error = private + 14

const max_int8 = 127
const min_int8 = -128
const max_int16 = 32767
const min_int16 = -32768
const max_int32 = 2147483647
const min_int32 = -2147483648
const max_uint8 = 255
const max_uint16 = 65535

const endfile = 0
const empty = 1
const whoknows = 0
const ok = 1
const nomore = -1000

// macros for getting associativity and precedence levels
fn assoc(i int) int {
	return i & 3
}

fn plevel(i int) int {
	return (i >> 4) & 0o77
}

fn typ(i int) int {
	return (i >> 10) & 0o77
}

// macros for setting associativity and precedence levels
fn setasc(i int, j int) int {
	return i | j
}

fn setplev(i int, j int) int {
	unsafe {
		return i | (j << 4)
	}
}

fn settype(i int, j int) int {
	unsafe {
		return i | (j << 10)
	}
}

struct Vyacc {
mut:
	// I/O descriptors
	finput  os.File // Reader: input file
	stderr  os.File // Writer
	ftable  os.File // Writer: y.v file
	fcode   strings.Builder = strings.new_builder(0) // saved code
	foutput ?os.File // Writer: y.output file

	fmt_imported bool // output file has recorded an import of "fmt"

	oflag    string // -o [y.v]		- y.v file
	vflag    string // -v [y.output]	- y.output file
	lflag    bool   // -l			- disable line directives
	prefix   string // name prefix for identifiers, default yy
	restflag []string

	// communication variables between various I/O routines
	infile  string // input file name
	numbval int    // value of an input number
	tokname string // input token name, slop for runes and 0
	tokflag bool

	// storage of types
	ntypes  int // number of types defined
	typeset map[int]string = map[int]string{} // pointers to type tags

	// token information
	ntokens int // number of tokens
	tokset  []Symb
	toklev  []int // vector with the precedence of the terminals

	// nonterminal information
	nnonter int = -1 // the number of nonterminals
	nontrst []Symb
	start   int // start symbol

	// state information
	nstate   int // number of states
	pstate   []int = []int{len: nstates + 2} // index into y.statemem to the descriptions of the states
	statemem []Item
	tystate  []int = []int{len: nstates} // contains type information about the states
	tstates  []int // states generated by terminal gotos
	ntstates []int // states generated by nonterminal gotos
	mstates  []int = []int{len: nstates} // chain of overflows of term/nonterm generation lists
	lastred  int // number of last reduction of a state
	defact   []int = []int{len: nstates} // default actions of states

	// lookahead set information
	nolook  int   // flag to turn off lookahead computations
	tbitset int   // size of lookahead sets
	clset   Lkset // temporary storage for lookahead computations

	// working set information
	wsets []Wset
	cwp   int

	// storage for action table
	amem  []int // action table storage
	memp  int   // next free action table position
	indgo []int = []int{len: nstates} // index to the stored goto table

	// temporary vector, indexable by states, terms, or ntokens
	temp1   []int = []int{len: tempsize} // temporary storage, indexed by terms + ntokens or states
	lineno  int   = 1                    // current input line number
	fatfl   int   = 1                    // if on, error is fatal
	nerrors int // number of y.errors

	// assigned token type values
	extval int

	// grammar rule information
	nprod  int = 1 // number of productions
	prdptr [][]int // pointers to descriptions of productions
	levprd []int   // precedence levels for the productions
	rlines []int   // line number for this rule

	// statistics collection variables
	zzgoent  int
	zzgobest int
	zzacent  int
	zzexcp   int
	zzclose  int
	zzrrconf int
	zzsrconf int
	zzstate  int

	// optimizer arrays
	yypgo  [][]int
	optst  [][]int
	ggreed []int
	pgo    []int

	maxspr int // maximum spread of any entry
	maxoff int // maximum offset into a array
	maxa   int

	// storage for information about the nonterminals
	pres   [][][]int // vector of pointers to productions yielding each nonterminal
	pfirst []Lkset
	pempty []int // vector of nonterminals nontrivially deriving e

	// random stuff picked out from between functions
	indebug int // debugging flag for cpfir
	pidebug int // debugging flag for putitem
	gsdebug int // debugging flag for stagen
	cldebug int // debugging flag for closure
	pkdebug int // debugging flag for apack
	g2debug int // debugging for go2gen
	adb     int = 1 // debugging for callopt

	errors []ParseError

	state_table []Row

	zznewstate int

	yaccpar string // will be processed version of yaccpartext: s/$\$/prefix/g

	peekline int

	resrv []Resrv = [
	Resrv{'binary', binary},
	Resrv{'left', left},
	Resrv{'nonassoc', binary},
	Resrv{'prec', prec},
	Resrv{'right', right},
	Resrv{'start', start},
	Resrv{'term', term},
	Resrv{'token', term},
	Resrv{'type', typedef},
	Resrv{'union', @union},
	Resrv{'struct', @union},
	Resrv{'error', error},
]

	// utility routines
	peekrune rune
}

fn (mut y Vyacc) init() {
	mut parser := flag.new_flag_parser(os.args)
	y.oflag = parser.string('', `o`, 'y.v', 'parser output', flag.FlagConfig{})
	y.prefix = parser.string('', `p`, 'yy', 'name prefix to use in generated code', flag.FlagConfig{})
	y.vflag = parser.string('', `v`, 'y.output', 'create parsing tables', flag.FlagConfig{})
	y.lflag = parser.bool('', `l`, false, 'disable line directives', flag.FlagConfig{})
	y.restflag = (parser.finalize() or { panic(err) })[1..]
}

const initialstacksize = 16

// structure declarations
type Lkset = []int

struct Pitem {
mut:
	prod   []int
	off    int // offset within the production
	first  int // first term or non-term in item
	prodno int // production number for sorting
}

struct Item {
mut:
	pitem Pitem
	look  Lkset
}

struct Symb {
mut:
	name    string
	noconst bool
	value   int
}

struct Wset {
mut:
	pitem Pitem
	flag  int
	ws    Lkset
}

struct Resrv {
	name  string
	value int
}

struct ParseError {
	lineno int
	tokens []string
	msg    string
}

struct Row {
	actions        []int
	default_action int
}

const eof = -1

fn main() {
	mut y := Vyacc{}

	y.init()
	y.setup()! // initialize and read productions

	y.tbitset = (y.ntokens + 32) / 32
	y.cpres() // make table of which productions yield a given nonterminal
	y.cempty() // make a table of which nonterminals can match the empty string
	y.cpfir()! // make a table of firsts of nonterminals

	y.stagen()! // generate the states

	y.yypgo = [][]int{len: y.nnonter + 1}
	y.optst = [][]int{len: y.nstate}
	y.output()! // write the states and the tables
	y.go2out()!

	y.hideprod()!
	y.summary()

	y.callopt()!

	y.others()!

	exit_(0)
}

fn (mut y Vyacc) setup() ! {
	mut j := 0
	mut ty := 0

	y.stderr = os.stderr()
	y.foutput = none

	if y.restflag.len != 1 {
		y.usage()
	}
	if initialstacksize < 1 {
		// never set so cannot happen
		y.stderr.write_string('yacc: stack size too small\n')!
		y.usage()
	}
	y.yaccpar = yaccpartext.replace('$\$', y.prefix)
	y.openup()!

	y.ftable.write_string('// Code generated by vyacc ${os.args[1..].join(' ')}. DO NOT EDIT.\n')!

	y.defin(0, '\$end')
	y.extval = private // tokens start in unicode 'private use'
	y.defin(0, 'error')
	y.defin(1, '\$accept')
	y.defin(0, '\$unk')
	mut i := 0

	mut t := y.gettok()

	outer: for {
		match t {
			mark, endfile {
				break outer
			}
			int(`;`) {
				// Do nothing.
			}
			start {
				t = y.gettok()
				if t != identifier {
					y.errorf('bad %start construction')
				}
				y.start = y.chfind(1, y.tokname)
			}
			error {
				lno := y.lineno
				mut tokens := []string{}
				for {
					t2 := y.gettok()
					if t2 == `:` {
						break
					}
					if t2 != identifier && t2 != identcolon {
						y.errorf('bad syntax in %error')
					}
					tokens << y.tokname
					if t2 == identcolon {
						break
					}
				}
				if y.gettok() != identifier {
					y.errorf('bad syntax in %error')
				}
				y.errors << ParseError{lno, tokens, y.tokname}
			}
			typedef {
				t = y.gettok()
				if t != typename {
					y.errorf('bad syntax in %type')
				}
				ty = y.numbval
				for {
					t = y.gettok()
					match t {
						identifier {
							t = y.chfind(1, y.tokname)
							if t < ntbase {
								j = typ(y.toklev[t])
								if j != 0 && j != ty {
									y.errorf('type redeclaration of token ${y.tokset[t].name}')
								} else {
									y.toklev[t] = settype(y.toklev[t], ty)
								}
							} else {
								j = y.nontrst[t - ntbase].value
								if j != 0 && j != ty {
									y.errorf('type redeclaration of nonterminal ${y.nontrst[t - ntbase].name}')
								} else {
									y.nontrst[t - ntbase].value = ty
								}
							}
							continue
						}
						int(`,`) {
							continue
						}
						else {}
					}
					break
				}
				continue
			}
			@union {
				y.cpyunion()!
			}
			left, binary, right, term {
				// nonzero means new prec. and assoc.
				lev := t - term
				if lev != 0 {
					i++
				}
				ty = 0

				// get identifiers so defined
				t = y.gettok()

				// there is a type defined
				if t == typename {
					ty = y.numbval
					t = y.gettok()
				}
				for {
					match t {
						int(`,`) {
							t = y.gettok()
							continue
						}
						int(`;`) {
							// Do nothing.
						}
						identifier {
							j = y.chfind(0, y.tokname)
							if j >= ntbase {
								y.errorf('${y.tokname} defined earlier as nonterminal')
							}
							if lev != 0 {
								if assoc(y.toklev[j]) != 0 {
									y.errorf('redeclaration of precedence of ${y.tokname}')
								}
								y.toklev[j] = setasc(y.toklev[j], lev)
								y.toklev[j] = setplev(y.toklev[j], i)
							}
							if ty != 0 {
								if typ(y.toklev[j]) != 0 {
									y.errorf('redeclaration of type of ${y.tokname}')
								}
								y.toklev[j] = settype(y.toklev[j], ty)
							}
							t = y.gettok()
							if t == number {
								y.tokset[j].value = y.numbval
								t = y.gettok()
							}

							continue
						}
						else {}
					}
					break
				}
				continue
			}
			lcurly {
				y.cpycode()!
			}
			else {
				y.errorf('syntax error tok=${t - private}')
			}
		}
		t = y.gettok()
	}

	if t == endfile {
		y.errorf('unexpected EOF before %')
	}

	y.fcode.write_string('match ${y.prefix}nt {\n')

	y.moreprod()
	y.prdptr[0] = [int(ntbase), y.start, 1, 0]

	y.nprod = 1
	mut curprod := []int{len: ruleinc}
	t = y.gettok()
	if t != identcolon {
		y.errorf('bad syntax on first rule')
	}

	if y.start == 0 {
		y.prdptr[0][1] = y.chfind(1, y.tokname)
	}

	// read rules
	// put into y.prdptr array in the format
	// target
	// followed by id's of terminals and non-terminals
	// followed by -y.nprod

	for t != mark && t != endfile {
		mut mem := 0

		// process a rule
		y.rlines[y.nprod] = y.lineno
		ruleline := y.lineno
		if t == `|` {
			curprod[mem] = y.prdptr[y.nprod - 1][0]
			mem++
		} else if t == identcolon {
			curprod[mem] = y.chfind(1, y.tokname)
			if curprod[mem] < ntbase {
				y.lerrorf(ruleline, 'token illegal on LHS of grammar rule')
			}
			mem++
		} else {
			y.lerrorf(ruleline, 'illegal rule: missing semicolon or | ?')
		}

		// read rule body
		t = y.gettok()
		for {
			for t == identifier {
				curprod[mem] = y.chfind(1, y.tokname)
				if curprod[mem] < ntbase {
					y.levprd[y.nprod] = y.toklev[curprod[mem]]
				}
				mem++
				if mem >= curprod.len {
					mut ncurprod := []int{len: mem + ruleinc}
					gocopy(mut ncurprod, curprod)
					curprod = ncurprod.clone()
				}
				t = y.gettok()
			}
			if t == prec {
				if y.gettok() != identifier {
					y.lerrorf(ruleline, 'illegal %prec syntax')
				}
				j = y.chfind(2, y.tokname)
				if j >= ntbase {
					y.lerrorf(ruleline, 'nonterminal ${y.nontrst[j - ntbase].name} illegal after %prec')
				}
				y.levprd[y.nprod] = y.toklev[j]
				t = y.gettok()
			}
			if t != `=` {
				break
			}
			y.levprd[y.nprod] |= actflag
			y.fcode.write_string('\n\t${y.nprod} {')
			y.fcode.write_string('\n\t\t${y.prefix}_dollar = ${y.prefix}_s[${y.prefix}pt-${mem - 1}..${y.prefix}pt+1].clone()')
			y.cpyact(curprod, mem)!
			y.fcode.write_string('\n\t}')

			// action within rule...
			t = y.gettok()
			if t == identifier {
				// make it a nonterminal
				j = y.chfind(1, '$\$${y.nprod}')

				//
				// the current rule will become rule number y.nprod+1
				// enter null production for action
				//
				y.prdptr[y.nprod] = []int{len: 2}
				y.prdptr[y.nprod][0] = j
				y.prdptr[y.nprod][1] = -y.nprod

				// update the production information
				y.nprod++
				y.moreprod()
				y.levprd[y.nprod] = y.levprd[y.nprod - 1] & ~actflag
				y.levprd[y.nprod - 1] = actflag
				y.rlines[y.nprod] = y.lineno

				// make the action appear in the original rule
				curprod[mem] = j
				mem++
				if mem >= curprod.len {
					mut ncurprod := []int{len: mem + ruleinc}
					gocopy(mut ncurprod, curprod)
					curprod = ncurprod.clone()
				}
			}
		}

		for t == `;` {
			t = y.gettok()
		}
		curprod[mem] = -y.nprod
		mem++

		// check that default action is reasonable
		if y.ntypes != 0 && (y.levprd[y.nprod] & actflag) == 0
			&& y.nontrst[curprod[0] - ntbase].value != 0 {
			// no explicit action, LHS has value
			mut tempty := curprod[1]
			if tempty < 0 {
				y.lerrorf(ruleline, 'must return a value, since LHS has a type')
			}
			if tempty >= ntbase {
				tempty = y.nontrst[tempty - ntbase].value
			} else {
				tempty = typ(y.toklev[tempty])
			}
			if tempty != y.nontrst[curprod[0] - ntbase].value {
				y.lerrorf(ruleline, 'default action causes potential type clash')
			}
		}
		y.moreprod()
		y.prdptr[y.nprod] = []int{len: mem}
		gocopy(mut y.prdptr[y.nprod], curprod)
		y.nprod++
		y.moreprod()
		y.levprd[y.nprod] = 0
	}
	y.fcode.write_string('\n\telse {}')

	if tempsize < y.ntokens + y.nnonter + 1 {
		y.errorf('too many tokens (${y.ntokens}) or non-terminals (${y.nnonter})')
	}

	//
	// end of all rules
	// dump out the prefix code
	//

	y.fcode.write_string('\n\t}')

	// put out non-literal terminals
	for i2 := tokstart; i2 <= y.ntokens; i2++ {
		// non-literals
		if !y.tokset[i2].noconst {
			y.ftable.write_string('const token_${y.tokset[i2].name.to_lower()} = ${y.tokset[i2].value}\n')!
		}
	}

	// put out names of tokens
	y.ftable.write_string('\n')!
	y.ftable.write_string('const ${y.prefix}_toknames = [\n')!
	for i2 := 1; i2 <= y.ntokens; i2++ {
		y.ftable.write_string("\t\"${y.tokset[i2].name.replace('$', '\\$')}\",\n")!
	}
	y.ftable.write_string(']\n')!

	// put out names of states.
	// commented out to avoid a huge table just for debugging.
	// re-enable to have the names in the binary.
	y.ftable.write_string('\n')!
	y.ftable.write_string('const ${y.prefix}_statenames = [\n')!
	for j = tokstart; j <= y.ntokens; j++ {
		y.ftable.write_string("\t\"${y.tokset[j].name}\",\n")!
	}
	y.ftable.write_string(']\n')!

	y.ftable.write_string('\n')!
	y.ftable.write_string('const ${y.prefix}_eof_code = 1\n')!
	y.ftable.write_string('const ${y.prefix}_err_code = 2\n')!
	y.ftable.write_string('const ${y.prefix}_initial_stack_size = ${initialstacksize}\n')!

	//
	// copy any postfix code
	//
	if t == mark {
		if !y.lflag {
			y.ftable.write_string('\n//line ${y.infile}:${y.lineno}\n')!
		}
		for {
			c := y.getrune(mut y.finput)
			if c == eof {
				break
			}
			y.ftable.write_string(c.str())!
		}
	}
}

// allocate enough room to hold another production
fn (mut y Vyacc) moreprod() {
	n := y.prdptr.len
	if y.nprod >= n {
		nn := n + prodinc
		mut aprod := [][]int{len: nn}
		mut alevprd := []int{len: nn}
		mut arlines := []int{len: nn}

		gocopy(mut aprod, y.prdptr)
		gocopy(mut alevprd, y.levprd)
		gocopy(mut arlines, y.rlines)

		y.prdptr = aprod
		y.levprd = alevprd
		y.rlines = arlines
	}
}

// define s to be a terminal if nt==0
// or a nonterminal if nt==1
fn (mut y Vyacc) defin(nt int, s string) int {
	mut val := 0
	if nt != 0 {
		y.nnonter++
		if y.nnonter >= y.nontrst.len {
			mut anontrst := []Symb{len: y.nnonter + syminc}
			gocopy(mut anontrst, y.nontrst)
			y.nontrst = anontrst
		}
		y.nontrst[y.nnonter] = Symb{
			name: s
		}
		return ntbase + y.nnonter
	}

	// must be a token
	y.ntokens++
	if y.ntokens >= y.tokset.len {
		nn := y.ntokens + syminc
		mut atokset := []Symb{len: nn}
		mut atoklev := []int{len: nn}

		gocopy(mut atoklev, y.toklev)
		gocopy(mut atokset, y.tokset)

		y.tokset = atokset
		y.toklev = atoklev
	}
	y.tokset[y.ntokens].name = s
	y.toklev[y.ntokens] = 0

	// establish value for token
	// single character literal
	if s[0] == `'` || s[0] == `"` {
		q := unquote(s) or {
			y.errorf('invalid token: ${err}')
			''
		}
		rq := q.runes()
		if rq.len != 1 {
			y.errorf('character token too long: ${s}')
		}
		val = int(rq[0])
		if val == 0 {
			y.errorf('token value 0 is illegal')
		}
		y.tokset[y.ntokens].noconst = true
	} else {
		val = y.extval
		y.extval++
		if s[0] == `$` {
			y.tokset[y.ntokens].noconst = true
		}
	}

	y.tokset[y.ntokens].value = val
	return y.ntokens
}

fn gocopy[T](mut dst []T, src []T) int {
	mut min := dst.len
	if src.len < min {
		min = src.len
	}
	for i := 0; i < min; i++ {
		dst[i] = src[i]
	}
	return src.len
}

fn (mut y Vyacc) gettok() int {
	mut i := 0
	mut mtch := rune(0)
	mut c := rune(0)

	y.tokname = ''
	for {
		y.lineno += y.peekline
		y.peekline = 0
		c = y.getrune(mut y.finput)
		for c == ` ` || c == `\n` || c == `\t` || c == `\v` || c == `\r` {
			if c == `\n` {
				y.lineno++
			}
			c = y.getrune(mut y.finput)
		}

		// skip comment -- fix
		if c != `/` {
			break
		}
		y.lineno += y.skipcom()
	}

	match c {
		eof {
			if y.tokflag {
				print('>>> endfile ${y.lineno}\n')
			}
			return endfile
		}
		`{` {
			y.ungetrune(y.finput, c)
			if y.tokflag {
				print('>>> ={ ${y.lineno}\n')
			}
			return int(`=`)
		}
		`<` {
			// get, and look up, a type name (union member name)
			c = y.getrune(mut y.finput)
			for c != `>` && c != eof && c != `\n` {
				y.tokname += c.str()
				c = y.getrune(mut y.finput)
			}

			if c != `>` {
				y.errorf('unterminated < ... > clause')
			}

			for i = 1; i <= y.ntypes; i++ {
				if y.typeset[i] == y.tokname {
					y.numbval = i
					if y.tokflag {
						print('>>> typename old <${y.tokname}> ${y.lineno}\n')
					}
					return typename
				}
			}
			y.ntypes++
			y.numbval = y.ntypes
			y.typeset[y.numbval] = y.tokname
			if y.tokflag {
				print('>>> typename new <${y.tokname}> ${y.lineno}\n')
			}
			return typename
		}
		`"`, `'` {
			mtch = c
			y.tokname = c.str()
			for {
				c = y.getrune(mut y.finput)
				if c == `\n` || c == eof {
					y.errorf('illegal or missing \' or "')
				}
				if c == `\\` {
					y.tokname += `\\`.str()
					c = y.getrune(mut y.finput)
				} else if c == mtch {
					if y.tokflag {
						print(">>> identifier \"${y.tokname}\" ${y.lineno}\n")
					}
					y.tokname += c.str()
					return identifier
				}
				y.tokname += c.str()
			}
		}
		`%` {
			c = y.getrune(mut y.finput)
			match c {
				`%` {
					if y.tokflag {
						print('>>> mark % ${y.lineno}\n')
					}
					return mark
				}
				`=` {
					if y.tokflag {
						print('>>> prec %= ${y.lineno}\n')
					}
					return prec
				}
				`{` {
					if y.tokflag {
						print('>>> lcurly %{ ${y.lineno}\n')
					}
					return lcurly
				}
				else {}
			}

			y.getword(c)
			// find a reserved word
			for i2, _ in y.resrv {
				if y.tokname == y.resrv[i2].name {
					if y.tokflag {
						print('>>> %${y.tokname} ${y.resrv[i2].value - private} ${y.lineno}\n')
					}
					return y.resrv[i2].value
				}
			}
			y.errorf('invalid escape, or illegal reserved word: ${y.tokname}')
		}
		`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9` {
			y.numbval = int(c - `0`)
			for {
				c = y.getrune(mut y.finput)
				if !isdigit(c) {
					break
				}
				y.numbval = y.numbval * 10 + int(c - `0`)
			}
			y.ungetrune(y.finput, c)
			if y.tokflag {
				print('>>> number ${y.numbval} ${y.lineno}\n')
			}
			return number
		}
		else {
			if isword(c) || c == `.` || c == `$` {
				y.getword(c)
			} else {
				if y.tokflag {
					print('>>> OPERATOR ${c.str()} ${y.lineno}\n')
				}
				return int(c)
			}
		}
	}

	// look ahead to distinguish identifier from identcolon
	c = y.getrune(mut y.finput)
	for c == ` ` || c == `\t` || c == `\n` || c == `\v` || c == `\r` || c == `/` {
		if c == `\n` {
			y.peekline++
		}
		// look for comments
		if c == `/` {
			y.peekline += y.skipcom()
		}
		c = y.getrune(mut y.finput)
	}
	if c == `:` {
		if y.tokflag {
			print('>>> identcolon ${y.tokname}: ${y.lineno}\n')
		}
		return identcolon
	}

	y.ungetrune(y.finput, c)
	if y.tokflag {
		print('>>> identifier ${y.tokname} ${y.lineno}\n')
	}
	return identifier
}

fn (mut y Vyacc) getword(c rune) {
	mut c2 := c
	y.tokname = ''
	for isword(c2) || isdigit(c2) || c2 == `.` || c2 == `$` {
		y.tokname += c2.str()
		c2 = y.getrune(mut y.finput)
	}
	y.ungetrune(y.finput, c2)
}

// determine the type of a symbol
fn (mut y Vyacc) fdtype(t int) int {
	mut v := 0
	mut s := ''

	if t >= ntbase {
		v = y.nontrst[t - ntbase].value
		s = y.nontrst[t - ntbase].name
	} else {
		v = typ(y.toklev[t])
		s = y.tokset[t].name
	}
	if v <= 0 {
		y.errorf('must specify type for ${s}')
	}
	return v
}

fn (mut y Vyacc) chfind(t int, s string) int {
	mut t2 := t

	if s[0] == `"` || s[0] == `'` {
		t2 = 0
	}
	for i := 0; i <= y.ntokens; i++ {
		if s == y.tokset[i].name {
			return i
		}
	}
	for i := 0; i <= y.nnonter; i++ {
		if s == y.nontrst[i].name {
			return ntbase + i
		}
	}

	// cannot find name
	if t2 > 1 {
		y.errorf('${s} should have been defined earlier')
	}
	return y.defin(t2, s)
}

// copy the union declaration to the output, and the define file if present
fn (mut y Vyacc) cpyunion() ! {
	if !y.lflag {
		y.ftable.write_string('\n//line ${y.infile}:${y.lineno}\n')!
	}
	y.ftable.write_string('type ${y.prefix}SymType struct')!

	mut level := 0

	out: for {
		c := y.getrune(mut y.finput)
		if c == eof {
			y.errorf('EOF encountered while processing %union')
		}
		y.ftable.write(c.bytes())!
		match c {
			`\n` {
				y.lineno++
			}
			`{` {
				if level == 0 {
					y.ftable.write_string('\n\tyys int')!
				}
				level++
			}
			`}` {
				level--
				if level == 0 {
					break out
				}
			}
			else {}
		}
	}
	y.ftable.write_string('\n\n')!
}

// saves code between %{ and %}
// adds an import for __fmt__ the first time
fn (mut y Vyacc) cpycode() ! {
	lno := y.lineno

	mut c := y.getrune(mut y.finput)
	if c == `\n` {
		c = y.getrune(mut y.finput)
		y.lineno++
	}
	if !y.lflag {
		y.ftable.write_string('\n//line ${y.infile}:${y.lineno}\n')!
	}
	// accumulate until %}
	mut code := []rune{cap: 1024}
	for c != eof {
		if c == `%` {
			c = y.getrune(mut y.finput)
			if c == `}` {
				y.emitcode(code, lno + 1)!
				return
			}
			code << `%`
		}
		code << c
		if c == `\n` {
			y.lineno++
		}
		c = y.getrune(mut y.finput)
	}
	y.lineno = lno
	y.errorf('eof before %}')
}

// emits code saved up from between %{ and %}
// called by cpycode
// adds an import for __yyfmt__ after the package clause
fn (mut y Vyacc) emitcode(code []rune, lineno int) ! {
	for i, line in lines(code) {
		y.writecode(line)!
		if !y.fmt_imported && is_package_clause(line) {
			y.ftable.write_string('import __yyfmt__ "fmt"\n')!
			if !y.lflag {
				y.ftable.write_string('//line ${y.infile}:${lineno + i}\n\t\t')!
			}
			y.fmt_imported = true
		}
	}
}

// does this line look like a package clause?  not perfect: might be confused by early comments.
fn is_package_clause(line_ []rune) bool {
	mut line := line_.clone()
	line = skipspace(line)

	// must be big enough.
	if line.len < 'package X\n'.len {
		return false
	}

	// must start with "package"
	for i, r in 'package'.runes() {
		if line[i] != r {
			return false
		}
	}
	line = skipspace(line['package'.len..])

	// must have another identifier.
	if line.len == 0 || (!utf8.is_letter(line[0]) && line[0] != `_`) {
		return false
	}
	for line.len > 0 {
		if !utf8.is_letter(line[0]) && !utf8.is_number(line[0]) && line[0] != `_` {
			break
		}
		line = line.clone()[1..]
	}
	line = skipspace(line)

	// eol, newline, or comment must follow
	if line.len == 0 {
		return true
	}
	if line[0] == `\r` || line[0] == `\n` {
		return true
	}
	if line.len >= 2 {
		return line[0] == `/` && (line[1] == `/` || line[1] == `*`)
	}
	return false
}

// skip initial spaces
fn skipspace(line_ []rune) []rune {
	mut line := line_.clone()
	for line.len > 0 {
		if line[0] != ` ` && line[0] != `\t` {
			break
		}
		line = line.clone()[1..]
	}
	return line
}

// break code into lines
fn lines(code_ []rune) [][]rune {
	mut code := code_.clone()
	mut l := [][]rune{cap: 100}
	for code.len > 0 {
		// one line per loop
		mut i := 0
		for idx, _ in code {
			if code[idx] == `\n` {
				i = idx
				break
			}
		}
		l << code[..i + 1]
		code = code.clone()[i + 1..]
	}
	return l
}

// writes code to y.ftable
fn (mut y Vyacc) writecode(code []rune) ! {
	for _, r in code {
		y.ftable.write_string(r.str())!
	}
}

// skip over comments
// skipcom is called after reading a `/`
fn (mut y Vyacc) skipcom() int {
	mut c := y.getrune(mut y.finput)
	if c == `/` {
		for c != eof {
			if c == `\n` {
				return 1
			}
			c = y.getrune(mut y.finput)
		}
		y.errorf('EOF inside comment')
		return 0
	}
	if c != `*` {
		y.errorf('illegal comment')
	}

	mut nl := 0 // lines skipped
	c = y.getrune(mut y.finput)

	l1:
	match c {
		`*` {
			c = y.getrune(mut y.finput)
			if c != `/` {
				unsafe {
					goto l1
				}
			}
		}
		`\n` {
			nl++
			c = y.getrune(mut y.finput)
			unsafe {
				goto l1
			}
		}
		else {
			c = y.getrune(mut y.finput)
			unsafe {
				goto l1
			}
		}
	}
	return nl
}

// copy action to the next ; or closing }
fn (mut y Vyacc) cpyact(curprod []int, max int) ! {
	if !y.lflag {
		y.fcode.write_string('\n//line ${y.infile}:${y.lineno}')
	}
	y.fcode.write_string('\n\t\t')

	lno := y.lineno
	mut brac := 0

	loop: for {
		mut c := y.getrune(mut y.finput)

		match c {
			`;` {
				if brac == 0 {
					y.fcode.write_string(c.str())
					return
				}
			}
			`{` {
				brac++
			}
			`$` {
				mut s := 1
				mut tok := -1
				c = y.getrune(mut y.finput)

				// type description
				if c == `<` {
					y.ungetrune(y.finput, c)
					if y.gettok() != typename {
						y.errorf('bad syntax on $<ident> clause')
					}
					tok = y.numbval
					c = y.getrune(mut y.finput)
				}
				if c == `$` {
					y.fcode.write_string('${y.prefix}_val')

					// put out the proper tag...
					if y.ntypes != 0 {
						if tok < 0 {
							tok = y.fdtype(curprod[0])
						}
						y.fcode.write_string('.${y.typeset[tok]}')
					}
					continue loop
				}
				if c == `-` {
					s = -s
					c = y.getrune(mut y.finput)
				}
				mut j := 0
				if isdigit(c) {
					for isdigit(c) {
						j = j * 10 + int(c - `0`)
						c = y.getrune(mut y.finput)
					}
					y.ungetrune(y.finput, c)
					j = j * s
					if j >= max {
						y.errorf('Illegal use of $${j}')
					}
				} else if isword(c) || c == `.` {
					// look for $name
					y.ungetrune(y.finput, c)
					if y.gettok() != identifier {
						y.errorf('$ must be followed by an identifier')
					}
					tokn := y.chfind(2, y.tokname)
					mut fnd := -1
					c = y.getrune(mut y.finput)
					if c != `@` {
						y.ungetrune(y.finput, c)
					} else if y.gettok() != number {
						y.errorf('@ must be followed by number')
					} else {
						fnd = y.numbval
					}
					for k := 1; k < max; k++ {
						if tokn == curprod[k] {
							fnd--
							if fnd <= 0 {
								break
							}
						}
					}
					if j >= max {
						y.errorf('\$name or \$name@number not found')
					}
				} else {
					y.fcode.write_string('$')
					if s < 0 {
						y.fcode.write_string('-')
					}
					y.ungetrune(y.finput, c)
					continue loop
				}
				y.fcode.write_string('${y.prefix}_dollar[${j}]')

				// put out the proper tag
				if y.ntypes != 0 {
					if j <= 0 && tok < 0 {
						y.errorf('must specify type of $${j}')
					}
					if tok < 0 {
						tok = y.fdtype(curprod[j])
					}
					y.fcode.write_string('.${y.typeset[tok]}')
				}
				continue loop
			}
			`}` {
				brac--
				if brac == 0 {
					y.fcode.write_string(c.str())
					return
				}
			}
			`/` {
				nc := y.getrune(mut y.finput)
				if nc != `/` && nc != `*` {
					y.ungetrune(y.finput, nc)
				} else {
					// a comment
					y.fcode.write_string(c.str())
					y.fcode.write_string(nc.str())
					c = y.getrune(mut y.finput)
					for c != eof {
						match true {
							c == `\n` {
								y.lineno++
								if nc == `/` { // end of // comment
									unsafe {
										goto swt
									}
								}
							}
							c == `*` && nc == `*` { // end of /* comment?
								nnc := y.getrune(mut y.finput)
								if nnc == `/` {
									y.fcode.write_string('*')
									y.fcode.write_string('/')
									continue loop
								}
								y.ungetrune(y.finput, nnc)
							}
							else {}
						}
						y.fcode.write_string(c.str())
						c = y.getrune(mut y.finput)
					}
					y.errorf('EOF inside comment')
				}
			}
			`'`, `"` {
				// character string or constant
				mtch := c
				y.fcode.write_string(c.str())
				c = y.getrune(mut y.finput)
				for c != eof {
					if c == `\\` {
						y.fcode.write_string(c.str())
						c = y.getrune(mut y.finput)
						if c == `\n` {
							y.lineno++
						}
					} else if c == mtch {
						unsafe {
							goto swt
						}
					}
					if c == `\n` {
						y.errorf('newline in string or char const')
					}
					y.fcode.write_string(c.str())
					c = y.getrune(mut y.finput)
				}
				y.errorf('EOF in string or character constant')
			}
			eof {
				y.lineno = lno
				y.errorf('action does not terminate')
			}
			`\n` {
				y.fcode.write_string('\n\t')
				y.lineno++
				continue loop
			}
			else {}
		}
		swt:
		y.fcode.write_string(c.str())
	}
}

fn (mut y Vyacc) openup() ! {
	y.infile = y.restflag[0]
	y.finput = y.open(y.infile)!

	y.foutput = none
	if y.vflag != '' {
		y.foutput = y.create(y.vflag)!
	}

	if y.oflag == '' {
		y.oflag = 'y.v'
	}
	y.ftable = y.create(y.oflag)!
}

// return a pointer to the name of symbol i
fn (y Vyacc) symnam(i int) string {
	mut s := ''

	if i >= ntbase {
		s = y.nontrst[i - ntbase].name
	} else {
		s = y.tokset[i].name
	}
	return s
}

// set elements 0 through n-1 to c
fn aryfil(mut v []int, n int, c int) {
	for i := 0; i < n; i++ {
		v[i] = c
	}
}

// compute an array with the beginnings of productions yielding given nonterminals
// The array y.pres points to these lists
// the array pyield has the lists: the total size is only NPROD+1
fn (mut y Vyacc) cpres() {
	y.pres = [][][]int{len: y.nnonter + 1}
	mut curres := [][]int{len: y.nprod}

	if false {
		for j := 0; j <= y.nnonter; j++ {
			print('y.nnonter[${j}] = ${y.nontrst[j].name}\n')
		}
		for j := 0; j < y.nprod; j++ {
			print('y.prdptr[${j}][0] = ${y.prdptr[j][0] - ntbase}+ntbase\n')
		}
	}

	y.fatfl = 0 // make undefined symbols nonfatal
	for i := 0; i <= y.nnonter; i++ {
		mut n := 0
		c := i + ntbase
		for j := 0; j < y.nprod; j++ {
			if y.prdptr[j][0] == c {
				curres[n] = y.prdptr[j][1..]
				n++
			}
		}
		if n == 0 {
			y.errorf('nonterminal ${y.nontrst[i].name} not defined')
			continue
		}
		y.pres[i] = [][]int{len: n}
		gocopy(mut y.pres[i], curres)
	}
	y.fatfl = 1
	if y.nerrors != 0 {
		y.summary()
		exit_(1)
	}
}

// mark nonterminals which derive the empty string
// also, look for nonterminals which don't derive any token strings
fn (mut y Vyacc) cempty() {
	mut i := 0
	mut p := 0
	mut np := 0
	mut prd := []int{}

	y.pempty = []int{len: y.nnonter + 1}

	// first, use the array y.pempty to detect productions that can never be reduced
	// set y.pempty to WHONOWS
	aryfil(mut y.pempty, y.nnonter + 1, whoknows)

	// now, look at productions, marking nonterminals which derive something

	more: for {
		for i = 0; i < y.nprod; i++ {
			prd = y.prdptr[i]
			if y.pempty[prd[0] - ntbase] != 0 {
				continue
			}
			np = prd.len - 1
			for p = 1; p < np; p++ {
				if prd[p] >= ntbase && y.pempty[prd[p] - ntbase] == whoknows {
					break
				}
			}
			// production can be derived
			if p == np {
				y.pempty[prd[0] - ntbase] = ok
				continue more
			}
		}
		break
	}

	// now, look at the nonterminals, to see if they are all ok
	for i = 0; i <= y.nnonter; i++ {
		// the added production rises or falls as the start symbol ...
		if i == 0 {
			continue
		}
		if y.pempty[i] != ok {
			y.fatfl = 0
			y.errorf('nonterminal ${y.nontrst[i].name} never derives any token string')
		}
	}

	if y.nerrors != 0 {
		y.summary()
		exit_(1)
	}

	// now, compute the y.pempty array, to see which nonterminals derive the empty string
	// set y.pempty to whoknows
	aryfil(mut y.pempty, y.nnonter + 1, whoknows)

	// loop as long as we keep finding empty nonterminals

	again: for {
		next: for i = 1; i < y.nprod; i++ {
			// not known to be empty
			prd = y.prdptr[i]
			if y.pempty[prd[0] - ntbase] != whoknows {
				continue
			}
			np = prd.len - 1
			for p = 1; p < np; p++ {
				if prd[p] < ntbase || y.pempty[prd[p] - ntbase] != empty {
					continue next
				}
			}

			// we have a nontrivially empty nonterminal
			y.pempty[prd[0] - ntbase] = empty

			// got one ... try for another
			continue again
		}
		return
	}
}

// compute an array with the first of nonterminals
fn (mut y Vyacc) cpfir() ! {
	mut s := 0
	mut n := 0
	mut p := 0
	mut np := 0
	mut ch := 0
	mut i := 0
	mut curres := [][]int{}
	mut prd := []int{}

	y.wsets = []Wset{len: y.nnonter + wsetinc}
	y.pfirst = []Lkset{len: y.nnonter + 1}
	for i = 0; i <= y.nnonter; i++ {
		y.wsets[i].ws = y.mkset()
		y.pfirst[i] = y.mkset()
		curres = y.pres[i]
		n = curres.len

		// initially fill the sets
		for s = 0; s < n; s++ {
			prd = curres[s]
			np = prd.len - 1
			for p = 0; p < np; p++ {
				ch = prd[p]
				if ch < ntbase {
					setbit(mut y.pfirst[i], ch)
					break
				}
				if y.pempty[ch - ntbase] == 0 {
					break
				}
			}
		}
	}

	// now, reflect transitivity
	mut changes := 1
	for changes != 0 {
		changes = 0
		for i = 0; i <= y.nnonter; i++ {
			curres = y.pres[i]
			n = curres.len
			for s = 0; s < n; s++ {
				prd = curres[s]
				np = prd.len - 1
				for p = 0; p < np; p++ {
					ch = prd[p] - ntbase
					if ch < 0 {
						break
					}
					changes |= y.setunion(mut y.pfirst[i], y.pfirst[ch])
					if y.pempty[ch] == 0 {
						break
					}
				}
			}
		}
	}

	if y.indebug == 0 {
		return
	}
	if y.foutput != none {
		for i = 0; i <= y.nnonter; i++ {
			y.foutput.write_string('\n${y.nontrst[i].name}: ${y.pfirst[i]} ${y.pempty[i]}\n')!
		}
	}
}

// generate the states
fn (mut y Vyacc) stagen() ! {
	// initialize
	y.nstate = 0
	y.tstates = []int{len: y.ntokens + 1} // states generated by terminal gotos
	y.ntstates = []int{len: y.nnonter + 1} // states generated by nonterminal gotos
	y.amem = []int{len: actsize}
	y.memp = 0

	y.clset = y.mkset()
	y.pstate[0] = 0
	y.pstate[1] = 0
	aryfil(mut y.clset, y.tbitset, 0)
	mut item := Pitem{y.prdptr[0], 0, 0, 0}
	y.putitem(item, y.clset)!
	y.tystate[0] = mustdo
	y.nstate = 1
	y.pstate[2] = y.pstate[1]

	//
	// now, the main state generation loop
	// first pass generates all of the states
	// later passes fix up lookahead
	// could be sped up a lot by remembering
	// results of the first pass rather than recomputing
	//
	mut first := 1
	for more := 1; more != 0; first = 0 {
		more = 0
		for i := 0; i < y.nstate; i++ {
			if y.tystate[i] != mustdo {
				continue
			}

			y.tystate[i] = done
			aryfil(mut y.temp1, y.nnonter + 1, 0)

			// take state i, close it, and do gotos
			y.closure(i)!

			// generate goto's
			for p := 0; p < y.cwp; p++ {
				pi := y.wsets[p]
				if pi.flag != 0 {
					continue
				}
				y.wsets[p].flag = 1
				c := pi.pitem.first
				if c <= 1 {
					if y.pstate[i + 1] - y.pstate[i] <= p {
						y.tystate[i] = mustlookahead
					}
					continue
				}

				// do a goto on c
				y.putitem(y.wsets[p].pitem, y.wsets[p].ws)!
				for q := p + 1; q < y.cwp; q++ {
					// this item contributes to the goto
					if c == y.wsets[q].pitem.first {
						y.putitem(y.wsets[q].pitem, y.wsets[q].ws)!
						y.wsets[q].flag = 1
					}
				}

				if c < ntbase {
					y.state(c) // register new state
				} else {
					y.temp1[c - ntbase] = y.state(c)
				}
			}

			if y.gsdebug != 0 && y.foutput != none {
				y.foutput.write_string('${i}: ')!
				for j := 0; j <= y.nnonter; j++ {
					if y.temp1[j] != 0 {
						y.foutput.write_string('${y.nontrst[j].name} ${y.temp1[j]},')!
					}
				}
				y.foutput.write_string('\n')!
			}

			if first != 0 {
				y.indgo[i] = y.apack(mut y.temp1[1..], y.nnonter - 1)! - 1
			}

			more++
		}
	}
}

// generate the closure of state i
fn (mut y Vyacc) closure(i int) ! {
	y.zzclose++

	// first, copy kernel of state i to y.wsets
	y.cwp = 0
	q := y.pstate[i + 1]
	for p := y.pstate[i]; p < q; p++ {
		y.wsets[y.cwp].pitem = y.statemem[p].pitem
		y.wsets[y.cwp].flag = 1 // this item must get closed
		gocopy(mut y.wsets[y.cwp].ws, y.statemem[p].look)
		y.cwp++
	}

	// now, go through the loop, closing each item
	mut work := 1
	for work != 0 {
		work = 0
		for u := 0; u < y.cwp; u++ {
			if y.wsets[u].flag == 0 {
				continue
			}

			// dot is before c
			c := y.wsets[u].pitem.first
			if c < ntbase {
				y.wsets[u].flag = 0
				// only interesting case is where . is before nonterminal
				continue
			}

			// compute the lookahead
			aryfil(mut y.clset, y.tbitset, 0)

			// find items involving c
			for v := u; v < y.cwp; v++ {
				if y.wsets[v].flag != 1 || y.wsets[v].pitem.first != c {
					continue
				}
				pi := y.wsets[v].pitem.prod
				mut ipi := y.wsets[v].pitem.off + 1

				y.wsets[v].flag = 0
				if y.nolook != 0 {
					continue
				}

				mut ch := pi[ipi]
				ipi++
				for ch > 0 {
					// terminal symbol
					if ch < ntbase {
						setbit(mut y.clset, ch)
						break
					}

					// nonterminal symbol
					y.setunion(mut y.clset, y.pfirst[ch - ntbase])
					if y.pempty[ch - ntbase] == 0 {
						break
					}
					ch = pi[ipi]
					ipi++
				}
				if ch <= 0 {
					y.setunion(mut y.clset, y.wsets[v].ws)
				}
			}

			//
			// now loop over productions derived from c
			//
			curres := y.pres[c - ntbase]
			n := curres.len

			nexts:
			// initially fill the sets
			for s := 0; s < n; s++ {
				prd := curres[s]

				//
				// put these items into the closure
				// is the item there
				//
				for v := 0; v < y.cwp; v++ {
					// yes, it is there
					if y.wsets[v].pitem.off == 0 && aryeq(y.wsets[v].pitem.prod, prd) != 0 {
						if y.nolook == 0 && y.setunion(mut y.wsets[v].ws, y.clset) != 0 {
							y.wsets[v].flag = 1
							work = 1
						}
						continue nexts
					}
				}

				//  not there; make a new entry
				if y.cwp >= y.wsets.len {
					mut awsets := []Wset{len: y.cwp + wsetinc}
					gocopy(mut awsets, y.wsets)
					y.wsets = awsets
				}
				y.wsets[y.cwp].pitem = Pitem{prd, 0, prd[0], -prd[prd.len - 1]}
				y.wsets[y.cwp].flag = 1
				y.wsets[y.cwp].ws = y.mkset()
				if y.nolook == 0 {
					work = 1
					gocopy(mut y.wsets[y.cwp].ws, y.clset)
				}
				y.cwp++
			}
		}
	}

	// have computed closure; flags are reset; return
	if y.cldebug != 0 && y.foutput != none {
		y.foutput.write_string('\nState ${i}, nolook = ${y.nolook}\n')!
		for u := 0; u < y.cwp; u++ {
			if y.wsets[u].flag != 0 {
				y.foutput.write_string('flag set\n')!
			}
			y.wsets[u].flag = 0
			y.foutput.write_string('\t${y.writem(y.wsets[u].pitem)}')!
			y.prlook(y.wsets[u].ws)!
			y.foutput.write_string('\n')!
		}
	}
}

// sorts last state,and sees if it equals earlier ones. returns state number
fn (mut y Vyacc) state(c int) int {
	y.zzstate++
	p1 := y.pstate[y.nstate]
	p2 := y.pstate[y.nstate + 1]
	if p1 == p2 {
		return 0 // null state
	}

	// sort the items
	mut k := 0
	mut l := 0
	for k = p1 + 1; k < p2; k++ { // make k the biggest
		for l = k; l > p1; l-- {
			if y.statemem[l].pitem.prodno < y.statemem[l - 1].pitem.prodno
				|| (y.statemem[l].pitem.prodno == y.statemem[l - 1].pitem.prodno
				&& y.statemem[l].pitem.off < y.statemem[l - 1].pitem.off) {
				s := y.statemem[l]
				y.statemem[l] = y.statemem[l - 1]
				y.statemem[l - 1] = s
			} else {
				break
			}
		}
	}

	size1 := p2 - p1 // size of state

	mut i := 0
	if c >= ntbase {
		i = y.ntstates[c - ntbase]
	} else {
		i = y.tstates[c]
	}

	look: for ; i != 0; i = y.mstates[i] {
		// get ith state
		q1 := y.pstate[i]
		q2 := y.pstate[i + 1]
		size2 := q2 - q1
		if size1 != size2 {
			continue
		}
		k = p1
		for l = q1; l < q2; l++ {
			if aryeq(y.statemem[l].pitem.prod, y.statemem[k].pitem.prod) == 0
				|| y.statemem[l].pitem.off != y.statemem[k].pitem.off {
				continue look
			}
			k++
		}

		// found it
		y.pstate[y.nstate + 1] = y.pstate[y.nstate] // delete last state

		// fix up lookaheads
		if y.nolook != 0 {
			return i
		}
		k = p1
		for l = q1; l < q2; l++ {
			if y.setunion(mut y.statemem[l].look, y.statemem[k].look) != 0 {
				y.tystate[i] = mustdo
			}
			k++
		}
		return i
	}

	// state is new
	y.zznewstate++
	if y.nolook != 0 {
		y.errorf('yacc state/y.nolook error')
	}
	y.pstate[y.nstate + 2] = p2
	if y.nstate + 1 >= nstates {
		y.errorf('too many states')
	}
	if c >= ntbase {
		y.mstates[y.nstate] = y.ntstates[c - ntbase]
		y.ntstates[c - ntbase] = y.nstate
	} else {
		y.mstates[y.nstate] = y.tstates[c]
		y.tstates[c] = y.nstate
	}
	y.tystate[y.nstate] = mustdo
	y.nstate++
	return y.nstate - 1
}

fn (mut y Vyacc) putitem(p_ Pitem, set Lkset) ! {
	mut p := p_
	p.off++
	p.first = p.prod[p.off]

	if y.pidebug != 0 && y.foutput != none {
		y.foutput.write_string('putitem(${y.writem(p)}), state ${y.nstate}\n')!
	}
	mut j := y.pstate[y.nstate + 1]
	if j >= y.statemem.len {
		mut asmm := []Item{len: j + stateinc}
		gocopy(mut asmm, y.statemem)
		y.statemem = asmm
	}
	y.statemem[j].pitem = p
	if y.nolook == 0 {
		mut s := y.mkset()
		gocopy(mut s, set)
		y.statemem[j].look = s
	}
	j++
	y.pstate[y.nstate + 1] = j
}

// creates output string for item pointed to by pp
fn (mut y Vyacc) writem(pp Pitem) string {
	mut i := 0

	mut p := pp.prod.clone()
	mut q := chcopy(y.nontrst[y.prdptr[pp.prodno][0] - ntbase].name) + ': '
	mut npi := pp.off

	mut pi := aryeq(p, y.prdptr[pp.prodno])

	for {
		mut c := ` `
		if pi == npi {
			c = `.`
		}
		q += c.str()

		i = p[pi]
		pi++
		if i <= 0 {
			break
		}
		q += chcopy(y.symnam(i))
	}

	// an item calling for a reduction
	i = p[npi]
	if i < 0 {
		q += '    (${-i})'
	}

	return q
}

// pack state i from y.temp1 into y.amem
fn (mut y Vyacc) apack(mut p []int, n_ int) !int {
	mut n := n_
	//
	// we don't need to worry about checking because
	// we will only look at entries known to be there...
	// eliminate leading and trailing 0's
	//
	mut off := 0
	mut pp := 0
	for ; pp <= n && p[pp] == 0; pp++ {
		off--
	}

	// no actions
	if pp > n {
		return 0
	}
	for ; n > pp && p[n] == 0; n-- {
	}
	p = p.clone()[pp..n + 1]

	// now, find a place for the elements from p to q, inclusive
	r := y.amem.len - p.len

	nextk: for rr := 0; rr <= r; rr++ {
		mut qq := rr
		for pp = 0; pp < p.len; pp++ {
			if p[pp] != 0 {
				if p[pp] != y.amem[qq] && y.amem[qq] != 0 {
					continue nextk
				}
			}
			qq++
		}

		// we have found an acceptable k
		if y.pkdebug != 0 && y.foutput != none {
			y.foutput.write_string('off = ${off + rr}, k = ${rr}\n')!
		}
		qq = rr
		for pp = 0; pp < p.len; pp++ {
			if p[pp] != 0 {
				if qq > y.memp {
					y.memp = qq
				}
				y.amem[qq] = p[pp]
			}
			qq++
		}
		if y.pkdebug != 0 && y.foutput != none {
			for pp = 0; pp <= y.memp; pp += 10 {
				y.foutput.write_string('\n')!
				for qq = pp; qq <= pp + 9; qq++ {
					y.foutput.write_string('${y.amem[qq]} ')!
				}
				y.foutput.write_string('\n')!
			}
		}
		return off + rr
	}
	y.errorf('no space in action table')
	return 0
}

// print the output for the states
fn (mut y Vyacc) output() ! {
	mut c := 0
	mut u := 0
	mut v := 0

	if !y.lflag {
		y.ftable.write_string('\n//line yacctab:1')!
	}
	mut actions := []int{}

	if y.errors.len > 0 {
		y.state_table = []Row{len: y.nstate}
	}

	noset := y.mkset()

	// output the stuff for state i
	for i := 0; i < y.nstate; i++ {
		y.nolook = 0
		if y.tystate[i] != mustlookahead {
			y.nolook = 1
		}
		y.closure(i)!

		// output actions
		y.nolook = 1
		aryfil(mut y.temp1, y.ntokens + y.nnonter + 1, 0)
		for u = 0; u < y.cwp; u++ {
			c = y.wsets[u].pitem.first
			if c > 1 && c < ntbase && y.temp1[c] == 0 {
				for v = u; v < y.cwp; v++ {
					if c == y.wsets[v].pitem.first {
						y.putitem(y.wsets[v].pitem, noset)!
					}
				}
				y.temp1[c] = y.state(c)
			} else if c > ntbase {
				c -= ntbase
				if y.temp1[c + y.ntokens] == 0 {
					y.temp1[c + y.ntokens] = y.amem[y.indgo[i] + c]
				}
			}
		}
		if i == 1 {
			y.temp1[1] = acceptcode
		}

		// now, we have the shifts; look at the reductions
		y.lastred = 0
		for u = 0; u < y.cwp; u++ {
			c = y.wsets[u].pitem.first

			// reduction
			if c > 0 {
				continue
			}
			y.lastred = -c
			us := y.wsets[u].ws
			for k := 0; k <= y.ntokens; k++ {
				if bitset(us, k) == 0 {
					continue
				}
				if y.temp1[k] == 0 {
					y.temp1[k] = c
				} else if y.temp1[k] < 0 { // reduce/reduce conflict
					if y.foutput != none {
						y.foutput.write_string("\n ${i}: reduce/reduce conflict  (red'ns " +
							'${-y.temp1[k]} and ${y.lastred}) on ${y.symnam(k)}')!
					}
					if -y.temp1[k] > y.lastred {
						y.temp1[k] = -y.lastred
					}
					y.zzrrconf++
				} else {
					// potential shift/reduce conflict
					y.precftn(y.lastred, k, i)!
				}
			}
		}
		actions = y.add_actions(mut actions, i)!
	}

	y.array_out_columns('_exca', actions, 2, false)!
	y.ftable.write_string('\n')!
	y.ftable.write_string('\n')!
	y.ftable.write_string('const ${y.prefix}_private = ${private}\n')!
}

// decide a shift/reduce conflict by precedence.
// r is a rule number, t a token number
// the conflict is in state s
// y.temp1[t] is changed to reflect the action
fn (mut y Vyacc) precftn(r int, t int, s int) ! {
	mut action := noasc

	mut lp := y.levprd[r]
	mut lt := y.toklev[t]
	if plevel(lt) == 0 || plevel(lp) == 0 {
		// conflict
		if y.foutput != none {
			y.foutput.write_string("\n${s}: shift/reduce conflict (shift ${y.temp1[t]}(${plevel(lt)}), red'n ${r}(${plevel(lp)})) on ${y.symnam(t)}")!
		}
		y.zzsrconf++
		return
	}
	if plevel(lt) == plevel(lp) {
		action = assoc(lt)
	} else if plevel(lt) > plevel(lp) {
		action = rasc // shift
	} else {
		action = lasc
	} // reduce
	match action {
		basc { // error action
			y.temp1[t] = errcode
		}
		lasc { // reduce
			y.temp1[t] = -r
		}
		else {}
	}
}

// output state i
// y.temp1 has the actions, y.lastred the default
fn (mut y Vyacc) add_actions(mut act []int, i int) ![]int {
	mut p := 0
	mut p1 := 0

	// find the best choice for y.lastred
	y.lastred = 0
	mut ntimes := 0
	for j := 0; j <= y.ntokens; j++ {
		if y.temp1[j] >= 0 {
			continue
		}
		if y.temp1[j] + y.lastred == 0 {
			continue
		}
		// count the number of appearances of y.temp1[j]
		mut count := 0
		tred := -y.temp1[j]
		y.levprd[tred] |= redflag
		for p = 0; p <= y.ntokens; p++ {
			if y.temp1[p] + tred == 0 {
				count++
			}
		}
		if count > ntimes {
			y.lastred = tred
			ntimes = count
		}
	}

	//
	// for error recovery, arrange that, if there is a shift on the
	// error recovery token, `error', that the default be the error action
	//
	if y.temp1[2] > 0 {
		y.lastred = 0
	}

	// clear out entries in y.temp1 which equal y.lastred
	// count entries in y.optst table
	mut n := 0
	for p = 0; p <= y.ntokens; p++ {
		p1 = y.temp1[p]
		if p1 + y.lastred == 0 {
			y.temp1[p] = 0
			p1 = 0
		}
		if p1 > 0 && p1 != acceptcode && p1 != errcode {
			n++
		}
	}

	y.wrstate(i)!
	y.defact[i] = y.lastred
	mut f := 0
	mut os_ := []int{len: n * 2}
	n = 0
	for p = 0; p <= y.ntokens; p++ {
		p1 = y.temp1[p]
		if p1 != 0 {
			if p1 < 0 {
				p1 = -p1
			} else if p1 == acceptcode {
				p1 = -1
			} else if p1 == errcode {
				p1 = 0
			} else {
				os_[n] = p
				n++
				os_[n] = p1
				n++
				y.zzacent++
				continue
			}
			if f == 0 {
				act << -1
				act << i
			}
			f++
			act << p
			act << p1
			y.zzexcp++
		}
	}

	if f != 0 {
		y.defact[i] = -2
		act << -2
		act << y.lastred
	}
	y.optst[i] = os_

	return act
}

// writes state i
fn (mut y Vyacc) wrstate(i int) ! {
	mut j0 := 0
	mut j1 := 0
	mut u := 0
	mut pp := 0
	mut qq := 0

	if y.errors.len > 0 {
		actions := y.temp1.clone()
		mut default_action := errcode
		if y.lastred != 0 {
			default_action = -y.lastred
		}
		y.state_table[i] = Row{actions, default_action}
	}

	if y.foutput != none {
		y.foutput.write_string('\nstate ${i}\n')!
		qq = y.pstate[i + 1]
		for pp = y.pstate[i]; pp < qq; pp++ {
			y.foutput.write_string('\t${y.writem(y.statemem[pp].pitem)}\n')!
		}
		if y.tystate[i] == mustlookahead {
			// print out empty productions in closure
			for u = y.pstate[i + 1] - y.pstate[i]; u < y.cwp; u++ {
				if y.wsets[u].pitem.first < 0 {
					y.foutput.write_string('\t${y.writem(y.wsets[u].pitem)}\n')!
				}
			}
		}

		// check for state equal to another
		for j0 = 0; j0 <= y.ntokens; j0++ {
			j1 = y.temp1[j0]
			if j1 != 0 {
				y.foutput.write_string('\n\t${y.symnam(j0)}  ')!

				// shift, error, or accept
				if j1 > 0 {
					if j1 == acceptcode {
						y.foutput.write_string('accept')!
					} else if j1 == errcode {
						y.foutput.write_string('error')!
					} else {
						y.foutput.write_string('shift ${j1}')!
					}
				} else {
					y.foutput.write_string('reduce ${-j1} (src line ${y.rlines[-j1]})')!
				}
			}
		}

		// output the final production
		if y.lastred != 0 {
			y.foutput.write_string('\n\t.  reduce ${y.lastred} (src line ${y.rlines[y.lastred]})\n\n')!
		} else {
			y.foutput.write_string('\n\t.  error\n\n')!
		}

		// now, output nonterminal actions
		j1 = y.ntokens
		for j0 = 1; j0 <= y.nnonter; j0++ {
			j1++
			if y.temp1[j1] != 0 {
				y.foutput.write_string('\t${y.symnam(j0 + ntbase)}  goto ${y.temp1[j1]}\n')!
			}
		}
	}
}

// output the gotos for the nontermninals
fn (mut y Vyacc) go2out() ! {
	for i := 1; i <= y.nnonter; i++ {
		y.go2gen(i)!

		// find the best one to make default
		mut best := -1
		mut times := 0

		// is j the most frequent
		for j := 0; j < y.nstate; j++ {
			if y.tystate[j] == 0 {
				continue
			}
			if y.tystate[j] == best {
				continue
			}

			// is y.tystate[j] the most frequent
			mut count := 0
			cbest := y.tystate[j]
			for k := j; k < y.nstate; k++ {
				if y.tystate[k] == cbest {
					count++
				}
			}
			if count > times {
				best = cbest
				times = count
			}
		}

		// best is now the default entry
		y.zzgobest += times - 1
		mut n := 0
		for j := 0; j < y.nstate; j++ {
			if y.tystate[j] != 0 && y.tystate[j] != best {
				n++
			}
		}
		mut goent := []int{len: 2 * n + 1}
		n = 0
		for j := 0; j < y.nstate; j++ {
			if y.tystate[j] != 0 && y.tystate[j] != best {
				goent[n] = j
				n++
				goent[n] = y.tystate[j]
				n++
				y.zzgoent++
			}
		}

		// now, the default
		if best == -1 {
			best = 0
		}

		y.zzgoent++
		goent[n] = best
		y.yypgo[i] = goent
	}
}

// output the gotos for nonterminal c
fn (mut y Vyacc) go2gen(c int) ! {
	mut i := 0
	mut cc := 0
	mut p := 0
	mut q := 0

	// first, find nonterminals with gotos on c
	aryfil(mut y.temp1, y.nnonter + 1, 0)
	y.temp1[c] = 1
	mut work := 1
	for work != 0 {
		work = 0
		for i = 0; i < y.nprod; i++ {
			// cc is a nonterminal with a goto on c
			cc = y.prdptr[i][1] - ntbase
			if cc >= 0 && y.temp1[cc] != 0 {
				// thus, the left side of production i does too
				cc = y.prdptr[i][0] - ntbase
				if y.temp1[cc] == 0 {
					work = 1
					y.temp1[cc] = 1
				}
			}
		}
	}

	// now, we have y.temp1[c] = 1 if a goto on c in closure of cc
	if y.g2debug != 0 && y.foutput != none {
		y.foutput.write_string('${y.nontrst[c].name}: gotos on ')!
		for i = 0; i <= y.nnonter; i++ {
			if y.temp1[i] != 0 {
				y.foutput.write_string('${y.nontrst[i].name} ')!
			}
		}
		y.foutput.write_string('\n')!
	}

	// now, go through and put gotos into y.tystate
	aryfil(mut y.tystate, y.nstate, 0)
	for i = 0; i < y.nstate; i++ {
		q = y.pstate[i + 1]
		for p = y.pstate[i]; p < q; p++ {
			cc = y.statemem[p].pitem.first
			if cc >= ntbase {
				// goto on c is possible
				if y.temp1[cc - ntbase] != 0 {
					y.tystate[i] = y.amem[y.indgo[i] + c]
					break
				}
			}
		}
	}
}

// in order to free up the mem and y.amem arrays for the optimizer,
// and still be able to output yyr1, etc., after the sizes of
// the action array is known, we hide the nonterminals
// derived by productions in y.levprd.
fn (mut y Vyacc) hideprod() ! {
	mut nred := 0
	y.levprd[0] = 0
	for i := 1; i < y.nprod; i++ {
		if (y.levprd[i] & redflag) == 0 {
			if y.foutput != none {
				y.foutput.write_string('Rule not reduced: ${y.writem(Pitem{y.prdptr[i], 0, 0, i})}\n')!
			}
			print('rule ${y.writem(Pitem{y.prdptr[i], 0, 0, i})} never reduced\n')
			nred++
		}
		y.levprd[i] = y.prdptr[i][0] - ntbase
	}
	if nred != 0 {
		print('${nred} rules never reduced\n')
	}
}

fn (mut y Vyacc) callopt() ! {
	mut j := 0
	mut k := 0
	mut p := 0
	mut q := 0
	mut i := 0
	mut v := []int{}

	y.pgo = []int{len: y.nnonter + 1}
	y.pgo[0] = 0
	y.maxoff = 0
	y.maxspr = 0
	for i = 0; i < y.nstate; i++ {
		k = 32000
		j = 0
		v = y.optst[i]
		q = v.len
		for p = 0; p < q; p += 2 {
			if v[p] > j {
				j = v[p]
			}
			if v[p] < k {
				k = v[p]
			}
		}

		// nontrivial situation
		if k <= j {
			// j is now the range
			//			j -= k;			// call scj
			if k > y.maxoff {
				y.maxoff = k
			}
		}
		y.tystate[i] = q + 2 * j
		if j > y.maxspr {
			y.maxspr = j
		}
	}

	// initialize y.ggreed table
	y.ggreed = []int{len: y.nnonter + 1}
	for i = 1; i <= y.nnonter; i++ {
		y.ggreed[i] = 1
		j = 0

		// minimum entry index is always 0
		v = y.yypgo[i]
		q = v.len - 1
		for p = 0; p < q; p += 2 {
			y.ggreed[i] += 2
			if v[p] > j {
				j = v[p]
			}
		}
		y.ggreed[i] = y.ggreed[i] + 2 * j
		if j > y.maxoff {
			y.maxoff = j
		}
	}

	// now, prepare to put the shift actions into the y.amem array
	for i = 0; i < actsize; i++ {
		y.amem[i] = 0
	}
	y.maxa = 0
	for i = 0; i < y.nstate; i++ {
		if y.tystate[i] == 0 && y.adb > 1 {
			y.ftable.write_string('State ${i}: null\n')!
		}
		y.indgo[i] = yy_flag
	}

	i = y.nxti()
	for i != nomore {
		if i >= 0 {
			y.stin(i)!
		} else {
			y.gin(-i)!
		}
		i = y.nxti()
	}

	// print y.amem array
	if y.adb > 2 {
		for p = 0; p <= y.maxa; p += 10 {
			y.ftable.write_string('${p}  ')!
			for i = 0; i < 10; i++ {
				y.ftable.write_string('${y.amem[p + i]}  ')!
			}
			y.ftable.write_string('\n')!
		}
	}

	y.aoutput()!
	y.osummary()!
}

// finds the next i
fn (mut y Vyacc) nxti() int {
	mut max := 0
	mut maxi := 0
	for i := 1; i <= y.nnonter; i++ {
		if y.ggreed[i] >= max {
			max = y.ggreed[i]
			maxi = -i
		}
	}
	for i := 0; i < y.nstate; i++ {
		if y.tystate[i] >= max {
			max = y.tystate[i]
			maxi = i
		}
	}
	if max == 0 {
		return nomore
	}
	return maxi
}

fn (mut y Vyacc) gin(i int) ! {
	mut s := 0

	// enter gotos on nonterminal i into array y.amem
	y.ggreed[i] = 0

	q := y.yypgo[i]
	nq := q.len - 1

	// now, find y.amem place for it

	nextgp: for p := 0; p < actsize; p++ {
		if y.amem[p] != 0 {
			continue
		}
		for r := 0; r < nq; r += 2 {
			s = p + q[r] + 1
			if s > y.maxa {
				y.maxa = s
				if y.maxa >= actsize {
					y.errorf('a array overflow')
				}
			}
			if y.amem[s] != 0 {
				continue nextgp
			}
		}

		// we have found y.amem spot
		y.amem[p] = q[nq]
		if p > y.maxa {
			y.maxa = p
		}
		for r := 0; r < nq; r += 2 {
			s = p + q[r] + 1
			y.amem[s] = q[r + 1]
		}
		y.pgo[i] = p
		if y.adb > 1 {
			y.ftable.write_string('Nonterminal ${i}, entry at ${y.pgo[i]}\n')!
		}
		return
	}
	y.errorf('cannot place goto ${i}\n')
}

fn (mut y Vyacc) stin(i int) ! {
	mut s := 0

	y.tystate[i] = 0

	// enter state i into the y.amem array
	q := y.optst[i]
	nq := q.len

	nextn:
	// find an acceptable place
	for n := -y.maxoff; n < actsize; n++ {
		mut f := 0
		for r := 0; r < nq; r += 2 {
			s = q[r] + n
			if s < 0 || s > actsize {
				continue nextn
			}
			if y.amem[s] == 0 {
				f++
			} else if y.amem[s] != q[r + 1] {
				continue nextn
			}
		}

		// check the position equals another only if the states are identical
		for j := 0; j < y.nstate; j++ {
			if y.indgo[j] == n {
				// we have some disagreement
				if f != 0 {
					continue nextn
				}
				if nq == y.optst[j].len {
					// states are equal
					y.indgo[i] = n
					if y.adb > 1 {
						y.ftable.write_string('State ${i}: entry at' + '${n} equals state ${j}\n')!
					}
					return
				}

				// we have some disagreement
				continue nextn
			}
		}

		for r := 0; r < nq; r += 2 {
			s = q[r] + n
			if s > y.maxa {
				y.maxa = s
			}
			if y.amem[s] != 0 && y.amem[s] != q[r + 1] {
				y.errorf("clobber of a array, pos'n ${s}, by ${q[r + 1]}")
			}
			y.amem[s] = q[r + 1]
		}
		y.indgo[i] = n
		if y.adb > 1 {
			y.ftable.write_string('State ${i}: entry at ${y.indgo[i]}\n')!
		}
		return
	}
	y.errorf('Error; failure to place state ${i}')
}

// this version is for limbo
// write out the optimized parser
fn (mut y Vyacc) aoutput() ! {
	y.ftable.write_string('\n')!
	y.ftable.write_string('const ${y.prefix}_last = ${y.maxa + 1}\n')!
	y.arout('_act', y.amem, y.maxa + 1)!
	y.arout('_pact', y.indgo, y.nstate)!
	y.arout('_pgo', y.pgo, y.nnonter + 1)!
}

// put out other arrays, copy the parsers
fn (mut y Vyacc) others() ! {
	mut i := 0
	mut j := 0

	y.arout('_r1', y.levprd, y.nprod)!
	aryfil(mut y.temp1, y.nprod, 0)

	//
	// yyr2 is the number of rules for each production
	//
	for i = 1; i < y.nprod; i++ {
		y.temp1[i] = y.prdptr[i].len - 2
	}
	y.arout('_r2', y.temp1, y.nprod)!

	aryfil(mut y.temp1, y.nstate, -1000)
	for i = 0; i <= y.ntokens; i++ {
		for j2 := y.tstates[i]; j2 != 0; j2 = y.mstates[j2] {
			y.temp1[j2] = i
		}
	}
	for i = 0; i <= y.nnonter; i++ {
		for j = y.ntstates[i]; j != 0; j = y.mstates[j] {
			y.temp1[j] = -i
		}
	}
	y.arout('_chk', y.temp1, y.nstate)!
	y.array_out_columns('_def', y.defact[..y.nstate], 10, false)!

	// put out token translation tables
	// table 1 has 0-256
	aryfil(mut y.temp1, 256, 0)
	mut c := 0
	for i2 := 1; i2 <= y.ntokens; i2++ {
		j = y.tokset[i2].value
		if j >= 0 && j < 256 {
			if y.temp1[j] != 0 {
				print('yacc bug -- cannot have 2 different Ts with same value\n')
				print('	${y.tokset[i2].name} and ${y.tokset[y.temp1[j]].name}\n')
				y.nerrors++
			}
			y.temp1[j] = i2
			if j > c {
				c = j
			}
		}
	}
	for i = 0; i <= c; i++ {
		if y.temp1[i] == 0 {
			y.temp1[i] = yylexunk
		}
	}
	y.arout('_tok1', y.temp1, c + 1)!

	// table 2 has private-private+256
	aryfil(mut y.temp1, 256, 0)
	c = 0
	for i = 1; i <= y.ntokens; i++ {
		j = y.tokset[i].value - private
		if j >= 0 && j < 256 {
			if y.temp1[j] != 0 {
				print('yacc bug -- cannot have 2 different Ts with same value\n')
				print('	${y.tokset[i].name} and ${y.tokset[y.temp1[j]].name}\n')
				y.nerrors++
			}
			y.temp1[j] = i
			if j > c {
				c = j
			}
		}
	}
	y.arout('_tok2', y.temp1, c + 1)!

	// table 3 has everything else
	y.ftable.write_string('\n')!
	mut v := []int{}
	for i = 1; i <= y.ntokens; i++ {
		j = y.tokset[i].value
		if j >= 0 && j < 256 {
			continue
		}
		if j >= private && j < 256 + private {
			continue
		}

		v << j
		v << i
	}
	v << 0
	y.arout('_tok3', v, v.len)!
	y.ftable.write_string('\n')!

	// Custom error messages.
	y.ftable.write_string('\n')!
	y.ftable.write_string('struct ErrorMessage {\n')!
	y.ftable.write_string('\tstate int\n')!
	y.ftable.write_string('\ttoken int\n')!
	y.ftable.write_string('\tmsg   string\n')!
	y.ftable.write_string('}\n\n')!
	if y.errors.len == 0 {
		y.ftable.write_string('const ${y.prefix}_error_messages = []ErrorMessage{}\n')!
	} else {
		y.ftable.write_string('const ${y.prefix}_error_messages = [\n')!
		for _, err in y.errors {
			y.lineno = err.lineno
			state, token := y.run_machine(err.tokens)
			y.ftable.write_string('\tErrorMessage{${state}, ${token}, ${err.msg}},\n')!
		}
		y.ftable.write_string(']\n')!
	}

	// copy parser text
	mut ch := y.getrune(mut y.finput)
	for ch != eof {
		y.ftable.write_string(ch.str())!
		ch = y.getrune(mut y.finput)
	}

	// copy yaccpar
	if !y.lflag {
		y.ftable.write_string('\n//line yaccpar:1\n')!
	}

	parts := y.yaccpar.split_n(y.prefix + 'run()', 2)
	y.ftable.write_string('${parts[0]}')!
	y.ftable.write_string(y.fcode.str())!
	y.ftable.write_string('${parts[1]}')!
}

fn (mut y Vyacc) run_machine(tokens []string) (int, int) {
	mut state := 0
	mut token := 0
	mut stack := []int{}
	mut i := 0
	token = -1

	Loop:
	if token < 0 {
		token = y.chfind(2, tokens[i])
		i++
	}

	row := y.state_table[state]

	mut c := token
	if token >= ntbase {
		c = token - ntbase + y.ntokens
	}
	mut action := row.actions[c]
	if action == 0 {
		action = row.default_action
	}

	match true {
		action == acceptcode {
			y.errorf('tokens are accepted')
			return state, token
		}
		action == errcode {
			if token >= ntbase {
				y.errorf('error at non-terminal token ${y.symnam(token)}')
			}
			return state, token
		}
		action > 0 {
			// Shift to state action.
			stack << state
			state = action
			token = -1
			unsafe {
				goto Loop
			}
		}
		else {
			// Reduce by production -action.
			prod := y.prdptr[-action]
			rhs_len := prod.len - 2
			if rhs_len > 0 {
				n := stack.len - rhs_len
				state = stack[n]
				stack = stack.clone()[..n]
			}
			if token >= 0 {
				i--
			}
			token = prod[0]
			unsafe {
				goto Loop
			}
		}
	}

	return state, token
}

fn min_max(v []int) (int, int) {
	mut min := 0
	mut max := 0
	if v.len == 0 {
		return min, max
	}
	min = v[0]
	max = v[0]
	for _, i in v {
		if i < min {
			min = i
		}
		if i > max {
			max = i
		}
	}
	return min, max
}

// return the smaller integral base type to store the values in v
fn min_type(v []int, allow_unsigned bool) string {
	mut typ := 'int'
	mut type_len := 8
	min, max := min_max(v)

	if min >= min_int32 && max <= max_int32 && type_len > 4 {
		typ = 'int32'
		type_len = 4
	}
	if min >= min_int16 && max <= max_int16 && type_len > 2 {
		typ = 'int16'
		type_len = 2
	}
	if min >= min_int8 && max <= max_int8 && type_len > 1 {
		typ = 'int8'
		type_len = 1
	}

	if allow_unsigned {
		// Do not check for uint32, not worth and won't compile on 32 bit systems

		if min >= 0 && max <= max_uint16 && type_len > 2 {
			typ = 'uint16'
			type_len = 2
		}
		if min >= 0 && max <= max_uint8 && type_len > 1 {
			typ = 'uint8'
			type_len = 1
		}
	}
	return typ
}

fn (mut y Vyacc) array_out_columns(s_ string, v []int, columns int, allow_unsigned bool) ! {
	mut s := y.prefix + s_
	y.ftable.write_string('\n')!
	// min_typ := min_type(v, allow_unsigned)
	y.ftable.write_string('const ${s} = [')!
	for i, val in v {
		if i % columns == 0 {
			y.ftable.write_string('\n\t')!
		} else {
			y.ftable.write_string(' ')!
		}
		y.ftable.write_string('${val},')!
	}
	y.ftable.write_string('\n]\n')!
}

fn (mut y Vyacc) arout(s string, v []int, n int) ! {
	y.array_out_columns(s, v[..n], 10, true)!
}

// output the summary on y.output
fn (mut y Vyacc) summary() {
	if y.foutput != none {
		y.foutput.write_string('\n${y.ntokens} terminals, ${y.nnonter + 1} nonterminals\n') or {
			panic(err)
		}
		y.foutput.write_string('${y.nprod} grammar rules, ${y.nstate}/${nstates} states\n') or {
			panic(err)
		}
		y.foutput.write_string('${y.zzsrconf} shift/reduce, ${y.zzrrconf} reduce/reduce conflicts reported\n') or {
			panic(err)
		}
		y.foutput.write_string('${y.wsets.len} working sets used\n') or { panic(err) }
		y.foutput.write_string('memory: parser ${y.memp}/${actsize}\n') or { panic(err) }
		y.foutput.write_string('${y.zzclose - 2 * y.nstate} extra closures\n') or { panic(err) }
		y.foutput.write_string('${y.zzacent} shift entries, ${y.zzexcp} exceptions\n') or {
			panic(err)
		}
		y.foutput.write_string('${y.zzgoent} goto entries\n') or { panic(err) }
		y.foutput.write_string('${y.zzgobest} entries saved by goto default\n') or { panic(err) }
	}
	if y.zzsrconf != 0 || y.zzrrconf != 0 {
		print('\nconflicts: ')
		if y.zzsrconf != 0 {
			print('${y.zzsrconf} shift/reduce')
		}
		if y.zzsrconf != 0 && y.zzrrconf != 0 {
			print(', ')
		}
		if y.zzrrconf != 0 {
			print('${y.zzrrconf} reduce/reduce')
		}
		print('\n')
	}
}

// write optimizer summary
fn (mut y Vyacc) osummary() ! {
	if y.foutput != none {
		mut i := 0
		for p := y.maxa; p >= 0; p-- {
			if y.amem[p] == 0 {
				i++
			}
		}

		y.foutput.write_string('Optimizer space used: output ${y.maxa + 1}/${actsize}\n')!
		y.foutput.write_string('${y.maxa + 1} table entries, ${i} zero\n')!
		y.foutput.write_string('maximum spread: ${y.maxspr}, maximum offset: ${y.maxoff}\n')!
	}
}

// copies and protects "'s in q
fn chcopy(q string) string {
	mut s := ''
	mut i := 0
	mut j := 0
	for i = 0; i < q.len; i++ {
		if q[i] == `"` {
			s += q[j..i] + '\\'
			j = i
		}
	}
	return s + q[j..i]
}

fn (mut y Vyacc) usage() {
	y.stderr.write_string('usage: yacc [-o output] [-v parsetable] input\n') or { panic(err) }
	exit_(1)
}

fn bitset(set Lkset, bit int) int {
	return set[bit >> 5] & (1 << u32(bit & 31))
}

fn setbit(mut set Lkset, bit int) {
	set[bit >> 5] |= (1 << u32(bit & 31))
}

fn (y Vyacc) mkset() Lkset {
	return []int{len: y.tbitset}
}

// set a to the union of a and b
// return 1 if b is not a subset of a, 0 otherwise
fn (mut y Vyacc) setunion(mut a []int, b []int) int {
	mut sub := 0
	for i := 0; i < y.tbitset; i++ {
		x := a[i]
		y_ := x | b[i]
		a[i] = y_
		if y_ != x {
			sub = 1
		}
	}
	return sub
}

fn (mut y Vyacc) prlook(p Lkset) ! {
	if y.foutput != none {
		// if p == none {
		// 	y.foutput.write_string("\tNULL")!
		// 	return
		// }
		y.foutput.write_string(' { ')!
		for j := 0; j <= y.ntokens; j++ {
			if bitset(p, j) != 0 {
				y.foutput.write_string('${y.symnam(j)} ')!
			}
		}
		y.foutput.write_string('}')!
	}
}

fn isdigit(c rune) bool {
	return c >= `0` && c <= `9`
}

fn isword(c rune) bool {
	return c >= 0xa0 || c == `_` || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

// return 1 if 2 arrays are equal
// return 0 if not equal
fn aryeq(a []int, b []int) int {
	n := a.len
	if b.len != n {
		return 0
	}
	for ll := 0; ll < n; ll++ {
		if a[ll] != b[ll] {
			return 0
		}
	}
	return 1
}

fn (mut y Vyacc) getrune(mut f os.File) rune {
	mut r := rune(0)

	if y.peekrune != 0 {
		if y.peekrune == eof {
			return eof
		}
		r = y.peekrune
		y.peekrune = 0
		return r
	}

	if f.eof() {
		return eof
	}

	mut buf := []u8{len: 1}

	f.read(mut buf) or { return eof }
	return buf[0]
}

fn (mut y Vyacc) ungetrune(f os.File, c rune) {
	if f != y.finput {
		panic('ungetc - not y.finput')
	}
	if y.peekrune != 0 {
		panic('ungetc - 2nd unget')
	}
	y.peekrune = c
}

fn (mut y Vyacc) open(s string) !os.File {
	return os.open(s)
}

fn (mut y Vyacc) create(s string) !os.File {
	return os.create(s)
}

// write out error comment
fn (mut y Vyacc) lerrorf(lineno int, s string) {
	y.nerrors++
	y.stderr.write_string(s) or { panic(err) }
	y.stderr.write_string(': ${y.infile}:${lineno}\n') or { panic(err) }
	if y.fatfl != 0 {
		y.summary()
		exit_(1)
	}
}

fn (mut y Vyacc) errorf(s string) {
	y.lerrorf(y.lineno, s)
}

fn exit_(status int) {
	// if y.ftable != none {
	// 	y.ftable.flush()
	// }
	// if y.foutput != none {
	// 	y.foutput.flush()
	// }
	// if y.stderr != none {
	// 	y.stderr.flush()
	// }
	exit(status)
}

fn unquote(s string) !string {
	return s[1..s.len - 2]
}

const yaccpartext = '
// parser for yacc output

const $\$_debug        = 0
const $\$_error_verbose = true

interface YYLexer {
mut:
	lex(mut lval YYSymType) int
	error(s string)!
}

interface YYParser {
mut:
	parse(mut YYLexer) !int
	lookahead() int
}

struct YYParserImpl {
mut:
	lval  YYSymType
	stack [$\$_initial_stack_size]YYSymType
	char  int
}

fn (mut p YYParserImpl) lookahead() int {
	return p.char
}

fn $\$_new_parser() YYParser {
	return YYParserImpl{}
}

const $\$_flag = -1000

fn $\$_tokname(c int) string {
	if c >= 1 && c-1 < $\$_toknames.len {
		if $\$_toknames[c-1] != "" {
			return $\$_toknames[c-1]
		}
	}
	return "tok-\$c"
}

fn $\$_statname(s int) string {
	if s >= 0 && s < $\$_statenames.len {
		if $\$_statenames[s] != "" {
			return $\$_statenames[s]
		}
	}
	return "state-\$s"
}

const tokstart = 4

fn $\$_error_message(state int, look_ahead int) string {
	if !$\$_error_verbose {
		return "syntax error"
	}

	for e in $\$_error_messages {
		if e.state == state && e.token == look_ahead {
			return "syntax error: " + e.msg
		}
	}

	mut res := "syntax error: unexpected " + $\$_tokname(look_ahead)

	// To match Bison, suggest at most four expected tokens.
	mut expected := []int{cap: 4}

	// Look for shiftable tokens.
	base := int($\$_pact[state])
	for tok := tokstart; tok-1 < $\$_toknames.len; tok++ {
		n := base + tok
		if n >= 0 && n < $\$_last && int($\$_chk[int($\$_act[n])]) == tok {
			if expected.len == expected.cap {
				return res
			}
			expected << tok
		}
	}

	if $\$_def[state] == -2 {
		mut i := 0
		for $\$_exca[i] != -1 || int($\$_exca[i+1]) != state {
			i += 2
		}

		// Look for tokens that we accept or reduce.
		for i += 2; $\$_exca[i] >= 0; i += 2 {
			tok := int($\$_exca[i])
			if tok < tokstart || $\$_exca[i+1] == 0 {
				continue
			}
			if expected.len == expected.cap {
				return res
			}
			expected << tok
		}

		// If the default action is to accept or reduce, give up.
		if $\$_exca[i+1] != 0 {
			return res
		}
	}

	for i, tok in expected {
		if i == 0 {
			res += ", expecting "
		} else {
			res += " or "
		}
		res += $\$_tokname(tok)
	}
	return res
}

fn $\$lex1(mut lex YYLexer, mut lval YYSymType) (int, int) {
	mut token := 0
	mut ch := lex.lex(mut lval)
	if ch <= 0 {
		token = int($\$_tok1[0])
		unsafe { goto out }
	}
	if ch < $\$_tok1.len {
		token = int($\$_tok1[ch])
		unsafe { goto out }
	}
	if ch >= $\$_private {
		if ch < $\$_private+$\$_tok2.len {
			token = int($\$_tok2[ch-$\$_private])
			unsafe { goto out }
		}
	}
	for i := 0; i < $\$_tok3.len; i += 2 {
		token = int($\$_tok3[i+0])
		if token == ch {
			token = int($\$_tok3[i+1])
			unsafe { goto out }
		}
	}

out:
	if token == 0 {
		token = int($\$_tok2[1]) // unknown char
	}
	if $\$_debug >= 3 {
		println("lex \${$\$_tokname(token)}(\${u8(ch)})")
	}
	return ch, token
}

fn $\$_parse(mut $\$lex YYLexer) !int {
	mut parser := $\$_new_parser()
	return parser.parse(mut $\$lex)
}

fn (mut $\$rcvr YYParserImpl) parse(mut $\$lex YYLexer) !int {
	mut $\$n := 0
	mut $\$_val := YYSymType{}
	mut $\$_dollar := []YYSymType{}
	_ = $\$_dollar // silence set and not used
	mut $\$_s := $\$rcvr.stack[..]

	mut n_errs := 0   // number of errors
	mut err_flag := 0 // error recovery flag
	mut $\$state := 0
	$\$rcvr.char = -1
	mut $\$token := -1 // $\$rcvr.char translated into internal numbering
	defer {
		// Make sure we report no lookahead when not parsing.
		$\$state = -1
		$\$rcvr.char = -1
		$\$token = -1
	}
	mut $\$p := -1
	unsafe { goto $\$stack }

ret0:
	return 0

ret1:
	return 1

$\$stack:
	// put a state and value onto the stack
	if $\$_debug >= 4 {
		println("char \${$\$_tokname($\$token)} in \${$\$_statname($\$state)}")
	}

	$\$p++
	if $\$p >= $\$_s.len {
		mut nyys := []YYSymType{len: $\$_s.len*2}
		gocopy(mut nyys, $\$_s)
		$\$_s = nyys.clone()
	}
	$\$_s[$\$p] = $\$_val
	$\$_s[$\$p].yys = $\$state

$\$newstate:
	$\$n = int($\$_pact[$\$state])
	if $\$n <= $\$_flag {
		unsafe {
			goto $\$default // simple state
		}
	}
	if $\$rcvr.char < 0 {
		$\$rcvr.char, $\$token = $\$lex1(mut $\$lex, mut $\$rcvr.lval)
	}
	$\$n += $\$token
	if $\$n < 0 || $\$n >= $\$_last {
		unsafe { goto $\$default }
	}
	$\$n = int($\$_act[$\$n])
	if int($\$_chk[$\$n]) == $\$token {
		// valid shift
		$\$rcvr.char = -1
		$\$token = -1
		$\$_val = $\$rcvr.lval
		$\$state = $\$n
		if err_flag > 0 {
			err_flag--
		}
		unsafe { goto $\$stack }
	}

$\$default:
	// default state action
	$\$n = int($\$_def[$\$state])
	if $\$n == -2 {
		if $\$rcvr.char < 0 {
			$\$rcvr.char, $\$token = $\$lex1(mut $\$lex, mut $\$rcvr.lval)
		}

		// look through exception table
		mut xi := 0
		for {
			if $\$_exca[xi+0] == -1 && int($\$_exca[xi+1]) == $\$state {
				break
			}
			xi += 2
		}
		for xi += 2; ; xi += 2 {
			$\$n = int($\$_exca[xi+0])
			if $\$n < 0 || $\$n == $\$token {
				break
			}
		}
		$\$n = int($\$_exca[xi+1])
		if $\$n < 0 {
			unsafe { goto ret0 }
		}
	}
	if $\$n == 0 {
		// error ... attempt to resume parsing
		match err_flag {
		0 {
			// brand new error
			$\$lex.error($\$_error_message($\$state, $\$token))!
			n_errs++
			if $\$_debug >= 1 {
				print($\$_statname($\$state))
				println(" saw \${$\$_tokname($\$token)}")
			}

			// Note: fallthrough copies the next case:
			err_flag = 3

			// find a state where "error" is a legal shift action
			for $\$p >= 0 {
				$\$n = int($\$_pact[$\$_s[$\$p].yys]) + $\$_err_code
				if $\$n >= 0 && $\$n < $\$_last {
					$\$state = int($\$_act[$\$n]) // simulate a shift of "error"
					if int($\$_chk[$\$state]) == $\$_err_code {
						unsafe { goto $\$stack }
					}
				}

				// the current p has no shift on "error", pop stack
				if $\$_debug >= 2 {
					println("error recovery pops state \${$\$_s[$\$p].yys}")
				}
				$\$p--
			}
			// there is no state on the stack with an error shift ... abort
			unsafe { goto ret1 }
		}

		1, 2 {
			// incompletely recovered error ... try again
			err_flag = 3

			// find a state where "error" is a legal shift action
			for $\$p >= 0 {
				$\$n = int($\$_pact[$\$_s[$\$p].yys]) + $\$_err_code
				if $\$n >= 0 && $\$n < $\$_last {
					$\$state = int($\$_act[$\$n]) // simulate a shift of "error"
					if int($\$_chk[$\$state]) == $\$_err_code {
						unsafe { goto $\$stack }
					}
				}

				// the current p has no shift on "error", pop stack
				if $\$_debug >= 2 {
					println("error recovery pops state \${$\$_s[$\$p].yys}")
				}
				$\$p--
			}
			// there is no state on the stack with an error shift ... abort
			unsafe { goto ret1 }
		}

		3 {
			// no shift yet; clobber input char
			if $\$_debug >= 2 {
				println("error recovery discards \${$\$_tokname($\$token)}")
			}
			if $\$token == $\$_eof_code {
				unsafe { goto ret1 }
			}
			$\$rcvr.char = -1
			$\$token = -1
			unsafe {
				goto $\$newstate
				// try again in the same state
			}
		}

		else {}
		}
	}

	// reduction by production $\$n
	if $\$_debug >= 2 {
		println("reduce \${$\$n} in:\\n\\t\${$\$_statname($\$state)}")
	}

	$\$nt := $\$n
	$\$pt := $\$p
	_ = $\$pt // guard against "declared and not used"

	$\$p -= int($\$_r2[$\$n])
	// $\$p is now the index of \$0. Perform the default action. Iff the
	// reduced production is ε, \$1 is possibly out of range.
	if $\$p+1 >= $\$_s.len {
		mut nyys := []YYSymType{len: $\$_s.len*2}
		gocopy(mut nyys, $\$_s)
		$\$_s = nyys.clone()
	}
	$\$_val = $\$_s[$\$p+1]

	// consult goto table to find next state
	$\$n = int($\$_r1[$\$n])
	$\$g := int($\$_pgo[$\$n])
	$\$j := $\$g + $\$_s[$\$p].yys + 1

	if $\$j >= $\$_last {
		$\$state = int($\$_act[$\$g])
	} else {
		$\$state = int($\$_act[$\$j])
		if int($\$_chk[$\$state]) != -$\$n {
			$\$state = int($\$_act[$\$g])
		}
	}
	// dummy call; replaced with literal code
	$\$run()
	unsafe {
		goto $\$stack
		// stack new state and value
	}
}

fn gocopy[T](mut dst []T, src []T) int {
	mut min := dst.len
	if src.len < min {
		min = src.len
	}
	for i := 0; i < min; i++ {
		dst[i] = src[i]
	}
	return src.len
}
'

fn slice_str[T](ss []T) string {
	mut s := '['
	for i, a in ss {
		if i > 0 {
			s += ' '
		}
		s += '${a}'
	}
	s += ']'
	return s
}

fn (y Vyacc) dump(msg string) {
	println('--- ${msg}')
	println('nstate = ${y.nstate}')
	println('tystate = ${slice_str(y.tystate[..y.nstate])}')
	println('wsets (${y.ntokens})')
	for i, w in y.wsets[..y.ntokens] {
		println('  ${i}: ${pitem_str(w.pitem)} ${w.flag} ${w.ws}')
	}
	println('temp1 = ${slice_str(y.temp1[..50])}')
}

fn pitem_str(p Pitem) string {
	if p.prod.len == 0 {
		return '{[] ${p.off} ${p.first} ${p.prodno}}'
	}
	if p.prod.len == 2 {
		return '{[${p.prod[0]} ${p.prod[1]}] ${p.off} ${p.first} ${p.prodno}}'
	}
	if p.prod.len == 4 {
		return '{[${p.prod[0]} ${p.prod[1]} ${p.prod[2]} ${p.prod[3]}] ${p.off} ${p.first} ${p.prodno}}'
	}
	return 'BAD ${p.prod.len}'
}

module vsql

import crypto.blake2b
import crypto.blake2s
import crypto.blake3
import crypto.md5
import crypto.ripemd160
import crypto.sha1
import crypto.sha256
import crypto.sha3
import crypto.sha512
import hash
import math

// The functions that hash a value (V408-01 to V408-05). The SQL standard
// doesn't have them. HASH returns the digest as a binary string, and MD5, SHA1,
// SHA256 and SHA512 return it as lower case hexadecimal digits, which is how
// they're usually shown. A character string is hashed as its UTF-8 octets, and
// a BINARY or CHARACTER argument is a BINARY VARYING or CHARACTER VARYING (see
// find_function), so its padding is hashed too.

// longest_digest is the length of the longest digest of HASH (SHA512 and
// SHA3_512), in octets.
const longest_digest = 64

fn register_hash_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}
	digest := Type{SQLType.is_varbinary, longest_digest, 0, false, false}

	for value in [varbinary, blob, varchar, clob] {
		conn.register_func(Func{'HASH', [value, varchar], false, fn (_ FunctionContext, args []Value) !Value {
			return new_binary_string_value(.is_varbinary, hash_value(args[1].string_value(),
				args[0])!.bytestr())
		}, digest, false, true, [vsql_hash]})!

		// Each shortcut has the name of its method.
		for method in hash_features.keys() {
			// Each digit is half of an octet.
			hex := Type{SQLType.is_character, hash_octets(method, [])!.len * 2, 0, false, false}
			conn.register_func(Func{method, [value], false, fn [method] (_ FunctionContext, args []Value) !Value {
				return new_character_value(hash_value(method, args[0])!.hex())
			}, hex, false, true, [hash_features[method]]})!
		}
	}
}

// hash_features are the methods that have their own function, and the code
// that it's flagged by.
const hash_features = {
	'MD5':    vsql_md5
	'SHA1':   vsql_sha1
	'SHA256': vsql_sha256
	'SHA512': vsql_sha512
}

// hash_value is the digest of a character string or binary string. A large
// value (see LargeValue) is hashed a few chunks at a time, so all of it is
// never in memory at once.
fn hash_value(method string, v Value) ![]u8 {
	if !v.is_large {
		return hash_octets(method, v.string_value().bytes())
	}

	mut hasher := new_hasher(method)!
	step := v.large_value().chunk_size * large_value_hash_chunks
	octets := v.octet_length()
	for start := 0; start < octets; start += step {
		hasher.write(v.octets(start, math.min(start + step, octets))!.bytes())!
	}

	return hasher.checksum()
}

// large_value_hash_chunks is how many chunks of a large value are read and
// hashed at a time.
const large_value_hash_chunks = 16

// hash_octets is the digest of the data with the method (in upper or lower
// case). A method that doesn't exist is a 22023 error.
fn hash_octets(method string, data []u8) ![]u8 {
	mut hasher := new_hasher(method)!
	hasher.write(data)!

	return hasher.checksum()
}

// A Hasher is the digest of a method that's written in pieces, see
// new_hasher.
interface Hasher {
mut:
	write(data []u8) !
	checksum() []u8
}

// A HashDigest is a Hasher for the digests that are a hash.Hash.
struct HashDigest {
mut:
	digest hash.Hash
}

fn (mut h HashDigest) write(data []u8) ! {
	h.digest.write(data)!
}

fn (mut h HashDigest) checksum() []u8 {
	return h.digest.sum([])
}

// A Blake3Digest is a Hasher for BLAKE3, which can have any length.
struct Blake3Digest {
mut:
	digest blake3.Digest
}

fn (mut h Blake3Digest) write(data []u8) ! {
	h.digest.write(data)!
}

fn (mut h Blake3Digest) checksum() []u8 {
	return h.digest.checksum(32)
}

// new_hasher is an empty digest of the method (in upper or lower case). A
// method that doesn't exist is a 22023 error.
fn new_hasher(method string) !Hasher {
	return match method.to_upper() {
		'MD5' { Hasher(HashDigest{md5.new()}) }
		'SHA1' { HashDigest{sha1.new()} }
		'SHA224' { HashDigest{sha256.new224()} }
		'SHA256' { HashDigest{sha256.new()} }
		'SHA384' { HashDigest{sha512.new384()} }
		'SHA512' { HashDigest{sha512.new()} }
		'SHA3_224' { sha3.new224()! }
		'SHA3_256' { sha3.new256()! }
		'SHA3_384' { sha3.new384()! }
		'SHA3_512' { sha3.new512()! }
		'BLAKE2B_256' { blake2b.new256()! }
		'BLAKE2B_512' { blake2b.new512()! }
		'BLAKE2S_256' { blake2s.new256()! }
		'BLAKE3' { Blake3Digest{blake3.Digest.new_hash()!} }
		'RIPEMD160' { HashDigest{ripemd160.new()} }
		else { sqlstate_22023('HASH: ${method} is not a hash method') }
	}
}

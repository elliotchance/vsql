module vsql

import crypto.aes
import crypto.rand
import encoding.base64
import encoding.utf8
import x.crypto.chacha20
import x.crypto.chacha20poly1305

// The functions that encrypt and decrypt a value (V409-01 to V409-04). The SQL
// standard doesn't have them. Only authenticated encryption is supported, so
// data that's decrypted with the wrong key, or that was changed, is an error
// rather than garbage. The nonce of each encryption is random, from the
// operating system's cryptographically secure generator (crypto.rand), so the
// same value encrypted twice is different, and a nonce is never reused by
// mistake.
//
// The encrypted data is the nonce (12 octets), then the ciphertext (the same
// length as the value), then the authentication tag (16 octets), which is the
// layout that other libraries usually expect.

// encryption_nonce_size is the length of the nonce of every method, in octets.
const encryption_nonce_size = 12

// encryption_tag_size is the length of the authentication tag of every method,
// in octets.
const encryption_tag_size = 16

// encryption_shortcut_method is the method of ENCRYPT_AES and DECRYPT_AES.
const encryption_shortcut_method = 'AES_256_GCM'

fn register_encryption_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}
	longest_varbinary := Type{SQLType.is_varbinary, max_binary_length, 0, false, false}

	// A character string is encrypted as its UTF-8 octets.
	for value in [varbinary, varchar] {
		conn.register_func(Func{'ENCRYPT', [value, varbinary, varchar], false, fn (_ FunctionContext, args []Value) !Value {
			plaintext := args[0].string_value()
			if encrypted_length(plaintext.len) > max_binary_length {
				return sqlstate_22001(Type{.is_varbinary, max_binary_length, 0, false, false})
			}

			return new_binary_string_value(.is_varbinary, encrypt_octets(args[2].string_value(),
				args[1].string_value().bytes(), plaintext.bytes())!.bytestr())
		}, longest_varbinary, false, false, [vsql_encrypt]})!
	}
	for value in [blob, clob] {
		conn.register_func(Func{'ENCRYPT', [value, varbinary, varchar], false, fn (_ FunctionContext, args []Value) !Value {
			data := encrypt_octets(args[2].string_value(), args[1].string_value().bytes(),
				args[0].string_value().bytes())!
			return new_binary_string_value(.is_blob, data.bytestr())
		}, blob, false, false, [vsql_encrypt]})!
	}
	conn.register_func(Func{'DECRYPT', [varbinary, varbinary, varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_varbinary, decrypt_octets(args[2].string_value(),
			args[1].string_value().bytes(), args[0].string_value().bytes())!.bytestr())
	}, longest_varbinary, false, true, [vsql_decrypt]})!
	conn.register_func(Func{'DECRYPT', [blob, varbinary, varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_blob, decrypt_octets(args[2].string_value(),
			args[1].string_value().bytes(), args[0].string_value().bytes())!.bytestr())
	}, blob, false, true, [vsql_decrypt]})!

	// ENCRYPT_AES and DECRYPT_AES are for text: the encrypted data is base64.
	conn.register_func(Func{'ENCRYPT_AES', [varchar, varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		plaintext := args[0].string_value()
		// Each 3 octets (or fewer at the end) are 4 characters of base64.
		if (encrypted_length(plaintext.len) + 2) / 3 * 4 > max_character_length {
			return sqlstate_22001(Type{.is_varchar, max_character_length, 0, false, false})
		}

		return new_varchar_value(base64.encode(encrypt_octets(encryption_shortcut_method,
			args[1].string_value().bytes(), plaintext.bytes())!))
	}, varchar, false, false, [vsql_encrypt_aes]})!
	conn.register_func(Func{'ENCRYPT_AES', [clob, varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		return new_clob_value(base64.encode(encrypt_octets(encryption_shortcut_method,
			args[1].string_value().bytes(), args[0].string_value().bytes())!))
	}, clob, false, false, [vsql_encrypt_aes]})!
	conn.register_func(Func{'DECRYPT_AES', [varchar, varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		return new_varchar_value(decrypt_text(args[0].string_value(), args[1].string_value().bytes())!)
	}, varchar, false, true, [vsql_decrypt_aes]})!
	conn.register_func(Func{'DECRYPT_AES', [clob, varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		return new_clob_value(decrypt_text(args[0].string_value(), args[1].string_value().bytes())!)
	}, clob, false, true, [vsql_decrypt_aes]})!
}

// encrypted_length is the length of the encrypted data of a value, in octets,
// so a result that's too long is found before it's encrypted.
fn encrypted_length(octets int) int {
	return encryption_nonce_size + octets + encryption_tag_size
}

// encrypt_octets is the nonce, ciphertext and tag of the plaintext, encrypted
// with the method (in upper or lower case) and a new random nonce.
fn encrypt_octets(method string, key []u8, plaintext []u8) ![]u8 {
	nonce := rand.bytes(encryption_nonce_size)!
	ciphertext := match encryption_method(method, key)! {
		.aes_gcm { aes.new_aes_gcm(key)!.encrypt(plaintext, nonce, [])! }
		.chacha20_poly1305 {
			chacha20poly1305.encrypt(plaintext, key, nonce, [], chacha20.Options{})!
		}
	}

	mut data := nonce.clone()
	data << ciphertext
	return data
}

// decrypt_octets is the plaintext of the nonce, ciphertext and tag in data. A
// wrong key, the wrong method, or data that was changed (or isn't long enough
// to have a nonce and tag) is a 22V01 error.
fn decrypt_octets(method string, key []u8, data []u8) ![]u8 {
	algorithm := encryption_method(method, key)!
	if data.len < encryption_nonce_size + encryption_tag_size {
		return sqlstate_22v01()
	}

	nonce := data[..encryption_nonce_size]
	ciphertext := data[encryption_nonce_size..]
	return match algorithm {
		.aes_gcm {
			aes.new_aes_gcm(key)!.decrypt(ciphertext, nonce, []) or { return sqlstate_22v01() }
		}
		.chacha20_poly1305 {
			chacha20poly1305.decrypt(ciphertext, key, nonce, [], chacha20.Options{}) or {
				return sqlstate_22v01()
			}
		}
	}
}

// decrypt_text is the text of base64 data from ENCRYPT_AES. Text that isn't
// base64 is a 22018 error, and a plaintext that isn't UTF-8 (it was a binary
// string) is a 22021 error.
fn decrypt_text(text string, key []u8) !string {
	plaintext := decrypt_octets(encryption_shortcut_method, key, base64_octets(text)!.bytes())!.bytestr()
	if !utf8.validate_str(plaintext) {
		return sqlstate_22021()
	}

	return plaintext
}

enum EncryptionAlgorithm {
	aes_gcm
	chacha20_poly1305
}

// encryption_method is the algorithm of the method (in upper or lower case). A
// method that doesn't exist, or a key that isn't the length of the method, is a
// 22023 error.
fn encryption_method(method string, key []u8) !EncryptionAlgorithm {
	algorithm, key_length := match method.to_upper() {
		'AES_128_GCM' { EncryptionAlgorithm.aes_gcm, 16 }
		'AES_256_GCM' { EncryptionAlgorithm.aes_gcm, 32 }
		'CHACHA20_POLY1305' { EncryptionAlgorithm.chacha20_poly1305, 32 }
		else { return sqlstate_22023('${method} is not an encryption method') }
	}
	if key.len != key_length {
		return sqlstate_22023('${method} needs a key of ${key_length} octets, not ${key.len}')
	}

	return algorithm
}

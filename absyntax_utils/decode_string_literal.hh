/*
 *  matiec - a compiler for the programming languages defined in IEC 61131-3
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 * This code is made available on the understanding that it will not be
 * used in safety-critical situations without a full and competent review.
 */

/* Decode a single-byte ST string literal's $-escapes ($$, $', $L, $N, $P, $R, $T, $xx). */

#ifndef _DECODE_STRING_LITERAL_HH
#define _DECODE_STRING_LITERAL_HH

#include <string>

/* raw_value includes the surrounding quotes (e.g. "'a$Tb'"). If out is non-NULL, the
 * decoded value's C-double-quoted spelling is written into *out. Returns the decoded
 * character count; pass out == NULL for a count-only call.
 */
unsigned int decode_string_literal(const char *raw_value, std::string *out);

#endif /* _DECODE_STRING_LITERAL_HH */

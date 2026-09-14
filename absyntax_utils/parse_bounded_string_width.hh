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

/* Parse the declared width `n` of a STRING[n] / WSTRING[n] storage specifier. */

#ifndef _PARSE_BOUNDED_STRING_WIDTH_HH
#define _PARSE_BOUNDED_STRING_WIDTH_HH

#include "../absyntax/absyntax.hh"

/* Strips '_' digit separators before parsing (STRING[1_000] means 1000; see
 * function_param_iterator.cc's extract_first_index_value() for the same pattern).
 * ERRORs out (never returns) on invalid input -- the grammar guarantees an <integer> token.
 */
long parse_bounded_string_width(token_c *width_token);

#endif /* _PARSE_BOUNDED_STRING_WIDTH_HH */

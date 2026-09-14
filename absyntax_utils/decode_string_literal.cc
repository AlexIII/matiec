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

#include "decode_string_literal.hh"
#include <string.h>
#include <ctype.h>
#include "../main.hh" // required for ERROR()

unsigned int decode_string_literal(const char *raw_value, std::string *out) {
  if (NULL != out) {*out = ""; *out += '"';}
  unsigned int count = 0;
  /* the first and last bytes are the quote characters */
  for (unsigned int i = 1; i < strlen(raw_value) - 1; i++) {
    char c = raw_value[i];
    if (c != '$') {
      if (NULL != out) {
        if ((c == '\\') || (c == '"')) *out += '\\';
        *out += c;
      }
      count++;
      continue;
    }
    /* this should be safe, since the code has passed the syntax parser!! */
    c = raw_value[++i];
    switch (c) {
      case '$':
      case '\'':
        {if (NULL != out) *out += c; count++; continue;}
      case 'L':
      case 'l':
        {if (NULL != out) *out += "\x0A"; /* LF */; count++; continue;}
      case 'N':
      case 'n':
        {if (NULL != out) *out += "\\x0A"; /* NL */; count++; continue;}
      case 'P':
      case 'p':
        {if (NULL != out) *out += "\\f"; /* FF */; count++; continue;}
      case 'R':
      case 'r':
        {if (NULL != out) *out += "\\r"; /* CR */; count++; continue;}
      case 'T':
      case 't':
        {if (NULL != out) *out += "\\t"; /* tab */; count++; continue;}
      default: {
        if (isxdigit(c)) {
          /* this should be safe, since the code has passed the syntax parser!! */
          char c2 = raw_value[++i];
          if (isxdigit(c2)) {
            if (NULL != out) {*out += '\\'; *out += 'x'; *out += c; *out += c2;}
            count++; continue;
          }
        }
      }
      /* otherwise we have an invalid string!! */
      /* This should not have got through the syntax parser! */
      ERROR;
    } /* switch() */
  } /* for() */

  if (NULL != out) *out += '"';
  return count;
}

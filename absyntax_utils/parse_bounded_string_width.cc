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

#include "parse_bounded_string_width.hh"
#include <string>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <limits>
#include "../main.hh" // required for ERROR()

/* NOTE: it must ignore underscores! (mirrors extract_first_index_value() in function_param_iterator.cc) */
long parse_bounded_string_width(token_c *width_token) {
  if (NULL == width_token) ERROR;
  std::string str = "";
  for (unsigned int i = 0; i < strlen(width_token->value); i++)
    if (width_token->value[i] != '_')  str += width_token->value[i];

  errno = 0; // since strtol() may legally return 0, we must set errno to 0 to detect errors correctly!
  long ret = strtol(str.c_str(), NULL, 10);
  if (errno != 0) ERROR;
  if (ret < 0) ERROR; // the grammar only ever produces unsigned integer literals here
  if (ret > std::numeric_limits<int>::max()) ERROR;
  return ret;
}

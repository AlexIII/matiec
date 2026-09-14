/* R1: a STRING[20] occupies 21 bytes, not STR_MAX_LEN+1. */
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
#include <assert.h>
#include <stdio.h>

TIME __CURRENT_TIME;
extern void config_init__(void);
extern PROG0 RES__INST0;

int main(void) {
    assert(sizeof(__STRING_20) == 21);
    assert(sizeof(STRING) == STR_MAX_LEN + 1);
    config_init__();
    assert(RES__INST0.B.value.len == 2);
    assert(RES__INST0.B.value.body[0] == 'h');
    printf("sizeof __STRING_20=%u PROG0=%u (STRING=%u)\n",
           (unsigned)sizeof(__STRING_20), (unsigned)sizeof(PROG0), (unsigned)sizeof(STRING));
    return 0;
}

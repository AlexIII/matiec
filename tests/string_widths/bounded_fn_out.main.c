/* A function output parameter written back into a bounded variable truncates. */
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
#include <assert.h>
#include <stdio.h>

TIME __CURRENT_TIME;
extern void config_init__(void);
extern PROG0 RES__INST0;

int main(void) {
    PROG0 *p = &RES__INST0;
    config_init__();
    PROG0_body__(p);
    printf("N.len=%u R=%d\n", (unsigned)p->N.value.len, (int)p->R.value);
    assert(p->N.value.len == 10);
    assert(p->R.value == 1);
    return 0;
}

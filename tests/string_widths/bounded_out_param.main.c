/* A function block output bound to a bounded variable truncates on the way out. */
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
    printf("N.len=%u\n", (unsigned)p->N.value.len);
    assert(p->N.value.len == 10);
    return 0;
}

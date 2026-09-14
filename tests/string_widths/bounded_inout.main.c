/* VAR_IN_OUT is copy-in/copy-out, so a bounded actual truncates on the way back. */
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
    printf("N.len=%u N='%.*s'\n", (unsigned)p->N.value.len,
           (int)p->N.value.len, p->N.value.body);
    assert(p->N.value.len == 10);
    assert(p->N.value.body[9] == 'j');
    return 0;
}

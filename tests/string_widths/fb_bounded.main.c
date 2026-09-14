/* A bounded STRING as a function block input: the call truncates at the width. */
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
    printf("F.NAME.len=%u R.len=%u M.len=%u\n",
           (unsigned)p->F.NAME.value.len, (unsigned)p->R.value.len, (unsigned)p->M.value.len);
    assert(sizeof(__STRING_15) == 16);
    assert(p->F.NAME.value.len == 15);
    assert(p->R.value.len == 15);
    assert(p->M.value.len == 15);
    return 0;
}

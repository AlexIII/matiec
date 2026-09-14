/* A 15-character input truncates to the declared width through the function. */
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

    printf("R.F.len=%u R.F='%.*s'\n",
           (unsigned)p->R.value.F.len, (int)p->R.value.F.len, p->R.value.F.body);

    assert(sizeof(p->R.value.F) == 11);
    assert(p->R.value.F.len == 10);
    assert(p->R.value.F.body[9] == '0');
    return 0;
}

/* A bounded struct member is sized to its declared width and default-initialises empty. */
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

    printf("sizeof(REC.F)=%u REC.F.len=%u sizeof(REC)=%u (STRING=%u)\n",
           (unsigned)sizeof(p->R.value.F), (unsigned)p->R.value.F.len,
           (unsigned)sizeof(p->R.value), (unsigned)sizeof(STRING));

    assert(sizeof(p->R.value.F) == 11);
    assert(p->R.value.F.len == 0);
    return 0;
}

/* Bounded struct members: member default, no default, and per-instance override. */
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

    printf("R1.F='%.*s' R1.G.len=%u R1.N=%d R2.F='%.*s' R2.N=%d\n",
           (int)p->R1.value.F.len, p->R1.value.F.body,
           (unsigned)p->R1.value.G.len, (int)p->R1.value.N,
           (int)p->R2.value.F.len, p->R2.value.F.body,
           (int)p->R2.value.N);

    assert(sizeof(p->R1.value.F) == 11);
    assert(p->R1.value.F.len == 3 && p->R1.value.F.body[0] == 'a');
    assert(p->R1.value.G.len == 0);
    assert(p->R1.value.N == 7);
    assert(p->R2.value.F.len == 2 && p->R2.value.F.body[0] == 'x');
    assert(p->R2.value.N == 9);
    return 0;
}

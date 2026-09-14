/* Narrowing writes and widening reads work through direct, nested and FB-input members. */
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

    printf("O.T.len=%u O.I.D.len=%u BACK.len=%u SEEN.len=%u sizeof(OUTER)=%u\n",
           (unsigned)p->O.value.T.len, (unsigned)p->O.value.I.D.len,
           (unsigned)p->BACK.value.len, (unsigned)p->S.SEEN.value.len,
           (unsigned)sizeof(p->O.value));

    /* Storage is the declared width, not STR_MAX_LEN. */
    assert(sizeof(p->O.value.T) == 11);
    assert(sizeof(p->O.value.I.D) == 11);

    /* A 30-character source truncates at the declared width on the way in ... */
    assert(p->O.value.T.len == 10);
    assert(p->O.value.T.body[9] == '0');
    assert(p->O.value.I.D.len == 10);
    assert(p->O.value.I.D.body[9] == '0');

    /* ... and widens back out without corruption, directly and through the FB. */
    assert(p->BACK.value.len == 10);
    assert(p->BACK.value.body[9] == '0');
    assert(p->S.SEEN.value.len == 10);
    assert(p->S.SEEN.value.body[9] == '0');
    return 0;
}

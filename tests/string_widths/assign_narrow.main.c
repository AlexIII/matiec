/* Wider -> narrower truncates at the declared width; narrower -> wider widens. */
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

    printf("NARROW.len=%u OUT.len=%u OUT='%.*s'\n",
           (unsigned)p->NARROW.value.len, (unsigned)p->OUT.value.len,
           (int)p->OUT.value.len, p->OUT.value.body);

    assert(p->NARROW.value.len == 10);
    assert(p->NARROW.value.body[9] == '0');
    assert(p->OUT.value.len == 11);
    assert(p->OUT.value.body[10] == 'X');
    return 0;
}

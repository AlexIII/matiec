/* Drives one cycle of f_trig_init.st's generated config and checks q_out.
 * See f_trig_init.st for what this actually tests.
 */
#include "iec_std_lib.h"
#include <stdio.h>

void config_run__(unsigned long tick);
void config_init__(void);
BOOL* __GET_GLOBAL_Q_OUT(void);

TIME __CURRENT_TIME;

int main(void) {
    config_init__();
    config_run__(0);
    BOOL q = *__GET_GLOBAL_Q_OUT();
    printf("Q on cycle 1 (CLK starts FALSE) = %s\n", q ? "TRUE" : "FALSE");
    return q ? 1 : 0; /* non-zero = spurious trigger = FAIL */
}

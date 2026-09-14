/* Contract test for the per-width IEC string type family. */
#include "iec_std_lib.h"
#include "accessor.h"
#include <assert.h>

TIME __CURRENT_TIME; /* referenced by iec_std_lib.h */

__DECLARE_STRING_TYPE(20)

int main(void) {
    __STRING_20 s;
    STRING wide = __STRING_LITERAL(5, "hello");
    STRING toolong = __STRING_LITERAL(30, "123456789012345678901234567890");

    assert(sizeof(__STRING_20) == 21);

    __string_narrow_20(&s, wide);
    assert(s.len == 5);
    assert(__string_widen_20(s).len == 5);
    assert(__string_widen_20(s).body[0] == 'h');

    /* the setter macro the compiler emits for a bounded target */
    {
        __DECLARE_VAR(__STRING_20,V)
        __SET_STRVAR(,V,,20,wide);
        assert(V.value.len == 5);
    }

    __string_narrow_20(&s, toolong);
    assert(s.len == 20);
    assert(s.body[19] == '0');
    return 0;
}

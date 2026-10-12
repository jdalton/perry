Computed `super[key] = value` must evaluate the key expression before `value`, but defer `ToPropertyKey` until PutValue. The compiled #12211 baseline at 034b coerced the key before the RHS and skipped the RHS when key conversion threw. This change keeps the raw key rooted in the existing operand group, evaluates the RHS, captures the live home prototype, then passes the refreshed key to `js_put_value_set` for coercion.

The focused fixture covers instance and static writes, side effects in the key expression and `Symbol.toPrimitive`, a home-prototype change in the RHS followed by another during key coercion, receiver identity, and a throwing key conversion. The codegen IR test checks RHS, late home-prototype capture, and PutValue order.

At `19c7d980436e99e52fd141ff9a9c66e7dfd67575`, the fresh debug build trio and focused IR test pass. The new #12211 fixture, the upstream class/super regression fixture, and the original same-scope discriminator each match pinned Node 26.5.1 byte-for-byte. The registration checker reports the same six unrelated findings on this head and its exact base. Two earlier test-build attempts ended before the requested test: an intentional disk-pressure stop (143), then an unrelated integration-target link failure when `/tmp` filled (101). The focused `--lib` retry passed. Full lint, auto-opt validation, and GC stress were not run; validation was on Linux only.

This is a partial #12211 repair for computed super key/RHS ordering. It does not claim that every issue case is closed.

Refs #12211.

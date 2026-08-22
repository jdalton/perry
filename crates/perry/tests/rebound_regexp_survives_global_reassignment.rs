//! Regression test: `identify_global_builtin_constructor` recognizing
//! RegExp's constructor thunk in `is_global_builtin_func` is not enough on
//! its own — the function also falls back to a `globalThis` singleton walk
//! when the `direct` mapping (`#5989`) doesn't name the thunk. That walk
//! fails the moment `globalThis.RegExp` itself is reassigned, exactly the
//! way `#5989`'s `Date = createDate(Date)` case did before its direct
//! mapping was added.
//!
//! This captures the ORIGINAL RegExp constructor into a variable BEFORE
//! reassigning the global binding, then constructs through the captured
//! reference. The singleton walk alone cannot recover "RegExp" once
//! `globalThis.RegExp` no longer holds the original value; only the direct,
//! `globalThis`-independent mapping can.

use std::path::PathBuf;
use std::process::Command;

fn perry_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_perry"))
}

fn compile_and_run(dir: &std::path::Path, source: &str) -> String {
    let entry = dir.join("main.ts");
    let output = dir.join("main_bin");
    std::fs::write(&entry, source).expect("write entry");

    let compile = Command::new(perry_bin())
        .current_dir(dir)
        .arg("compile")
        .arg(&entry)
        .arg("-o")
        .arg(&output)
        .output()
        .expect("run perry compile");
    assert!(
        compile.status.success(),
        "perry compile failed\nstdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&compile.stdout),
        String::from_utf8_lossy(&compile.stderr)
    );

    let run = Command::new(&output)
        .current_dir(dir)
        .output()
        .expect("run compiled binary");
    assert!(
        run.status.success(),
        "compiled binary failed\nstatus: {:?}\nstdout:\n{}\nstderr:\n{}",
        run.status,
        String::from_utf8_lossy(&run.stdout),
        String::from_utf8_lossy(&run.stderr)
    );
    assert!(
        run.stderr.is_empty(),
        "compiled binary wrote to stderr\nstderr:\n{}",
        String::from_utf8_lossy(&run.stderr)
    );
    String::from_utf8_lossy(&run.stdout).into_owned()
}

#[test]
fn captured_regexp_constructor_survives_global_reassignment() {
    let dir = tempfile::tempdir().expect("tempdir");
    let stdout = compile_and_run(
        dir.path(),
        r#"
"use strict";
const OriginalRegExp = RegExp;
// @ts-expect-error deliberate global builtin reassignment
RegExp = function FakeRegExp() {
  throw new Error("the fake constructor must never run");
};
const re = new OriginalRegExp("^[a-z]+$", "i");
console.log("source:", re.source);
console.log("flags:", re.flags);
console.log("test:", re.test("ABC"));
console.log("instanceof:", re instanceof OriginalRegExp);
"#,
    );
    assert_eq!(
        stdout,
        "source: ^[a-z]+$\nflags: i\ntest: true\ninstanceof: true\n"
    );
}

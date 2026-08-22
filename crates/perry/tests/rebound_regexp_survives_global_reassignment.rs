//! Contract test: constructing through a RegExp reference captured BEFORE
//! `globalThis.RegExp` is reassigned must still produce a real, correctly
//! branded regex.
//!
//! `identify_global_builtin_constructor` has three tiers once a thunk is
//! recognized in `is_global_builtin_func`: the `direct` mapping (`#5989`),
//! the closure's own `.name` dynamic property checked against
//! `GLOBAL_THIS_BUILTIN_CONSTRUCTORS`, and a `globalThis` singleton walk.
//! `"RegExp"` is in `GLOBAL_THIS_BUILTIN_CONSTRUCTORS`, so the name-record
//! tier already survives a reassigned global on its own — this test passes
//! whether or not `direct` also names RegExp. Its `direct` arm (added
//! alongside the `is_global_builtin_func` recognition, matching every
//! sibling constructor already listed there) is correct and consistent with
//! that architecture, but not independently exercisable through a realistic
//! JS reproduction: the name-record tier always intercepts first for an
//! unmodified constructor closure.

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

//! Two jobs. (1) Fingerprint of the translator's own source, for the shader
//! cache key (`victory-gpu`'s `shader_cache`): a rebuilt executable whose
//! translator did not change keeps its cached translations. Also lists every
//! `VICTORY_*` switch the translator reads, whose values join the key at run
//! time. (2) With the `host` feature, export `D3D12SDKVersion`/`D3D12SDKPath`
//! and stage the DirectX 12 Agility SDK beside the test binary so the
//! `host`-feature GPU tests get shader model 6.6 (same fix as
//! `apps/victory/build.rs`). Reads only this crate's `src` folder for the
//! fingerprint; writes nothing but cargo directives and the staged DLLs.

use std::path::{Path, PathBuf};

fn files(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for e in entries.flatten() {
        let p = e.path();
        if p.is_dir() {
            files(&p, out);
        } else if p.extension().is_some_and(|x| x == "rs") {
            out.push(p);
        }
    }
}

/// FNV-1a, 64 bits, two lanes with different offsets: a mismatch only costs
/// a cache miss, so this need not be cryptographic.
fn fnv(state: &mut [u64; 2], bytes: &[u8]) {
    for &b in bytes {
        for (i, s) in state.iter_mut().enumerate() {
            *s ^= u64::from(b) ^ (i as u64 * 0x9e);
            *s = s.wrapping_mul(0x0000_0100_0000_01b3);
        }
    }
}

fn main() {
    let src = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    println!("cargo:rerun-if-changed=src");
    println!("cargo:rerun-if-changed=Cargo.toml");
    let mut list = Vec::new();
    files(&src, &mut list);
    list.sort();
    let mut state = [0xcbf2_9ce4_8422_2325u64, 0x8422_2325_cbf2_9ce4u64];
    let mut switches = std::collections::BTreeSet::new();
    for p in &list {
        let rel = p.strip_prefix(&src).unwrap_or(p).to_string_lossy().replace('\\', "/");
        let text = std::fs::read(p).unwrap_or_default();
        fnv(&mut state, rel.as_bytes());
        fnv(&mut state, &(text.len() as u64).to_le_bytes());
        fnv(&mut state, &text);
        let s = String::from_utf8_lossy(&text);
        let mut rest = &s[..];
        while let Some(at) = rest.find("\"VICTORY_") {
            let tail = &rest[at + 1..];
            let end = tail
                .find(|c: char| !(c.is_ascii_uppercase() || c.is_ascii_digit() || c == '_'))
                .unwrap_or(tail.len());
            if tail[end..].starts_with('"') {
                switches.insert(tail[..end].to_string());
            }
            rest = &tail[end..];
        }
    }
    println!("cargo:rustc-env=VICTORY_SHADER_SOURCE_HASH={:016x}{:016x}", state[0], state[1]);
    let joined: Vec<_> = switches.into_iter().collect();
    println!("cargo:rustc-env=VICTORY_SHADER_SWITCHES={}", joined.join(","));
    agility_sdk();
}

/// Export the Agility SDK symbols and stage its DLLs for `host`-feature tests
/// that need shader model 6.6. Without `cargo xtask agility-sdk` having
/// fetched it, exports still compile and the tests just keep skipping.
fn agility_sdk() {
    if std::env::var_os("CARGO_FEATURE_HOST").is_none() {
        return;
    }
    println!("cargo:rustc-link-arg=/EXPORT:D3D12SDKVersion,DATA");
    println!("cargo:rustc-link-arg=/EXPORT:D3D12SDKPath,DATA");

    let out_dir = PathBuf::from(std::env::var("OUT_DIR").expect("cargo sets OUT_DIR"));
    // OUT_DIR is target/<profile>/build/victory-shader-<hash>/out; test
    // binaries for this crate land in target/<profile>/deps/.
    let deps_dir = out_dir
        .ancestors()
        .nth(3)
        .expect("OUT_DIR has the usual cargo-build depth")
        .join("deps");
    let workspace_root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .expect("crates/victory-shader lives two levels under the workspace root");
    let cached = workspace_root.join("target/agility-sdk/x64");

    let dest = deps_dir.join("D3D12");
    for name in ["D3D12Core.dll", "d3d12SDKLayers.dll"] {
        if !cached.join(name).is_file() {
            println!(
                "cargo:warning=Agility SDK not fetched (missing {}); run `cargo xtask agility-sdk` \
                 for shader model 6.6 on hosts whose OS d3d12.dll does not provide it.",
                cached.join(name).display()
            );
            return;
        }
    }
    std::fs::create_dir_all(&dest).expect("creating target/<profile>/deps/D3D12");
    for name in ["D3D12Core.dll", "d3d12SDKLayers.dll"] {
        std::fs::copy(cached.join(name), dest.join(name))
            .unwrap_or_else(|e| panic!("copying {name} next to the test binaries: {e}"));
    }
}

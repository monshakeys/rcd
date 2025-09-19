## Publishing a Release

```sh
# build
cargo build --locked --release
# Create the release and upload the binary
gh release create v0.1.0 \
  ./target/release/lscmd \
  --title "lscmd v0.1.0" \
  --notes "Initial release of lscmd - Shell command visualization tool"
```


## Creating a Tag

```sh
git tag v0.4.0
git push origin v0.4.0
```


---


## Maintenance & Troubleshooting

```sh
# conficts: resolves dependency conflicts or stubborn build errors
cargo clean
rm -f Cargo.lock

# up-to-date: updates all dependencies to their latest compatible versions
cargo update

# check: quickly checks if the code compiles without building an executable
cargo check

# version: verifies version number consistency across all packages
grep -r "version" . --include="*.toml"
```


---


## Versioning Scheme

- Patch (e.g., 0.1.0 → 0.1.1): For bug fixes and backward-compatible changes.
- Minor (e.g., 0.1.1 → 0.2.0): For new features that are backward-compatible.
- Major (e.g., 0.2.0 → 1.0.0): For breaking changes that are not backward-compatible.

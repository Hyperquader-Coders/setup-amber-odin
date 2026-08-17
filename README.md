# setup-amber-odin

**[Available on the GitHub Marketplace →](https://github.com/marketplace/actions/setup-amber-odin)**

Install the [Odin](https://odin-lang.org) compiler on an Ubuntu GitHub Actions
runner, from the [Amber Linux](https://amberlinux.org) apt archive.

No source build and no LLVM toolchain: the compiler is a signed Debian package,
so a run costs an `apt-get install` rather than a compile.

```yaml
- uses: Hyperquader-Coders/setup-amber-odin@v1
- run: odin version
```

## Why an apt package

The package is [`amber-odin`](https://github.com/Hyperquader-Coders/amber-odin) —
the **official** compiled Odin release, sha256-verified against upstream's own
release digest, wrapped for Debian. You get upstream's binary with upstream's
`core`, `base` and `vendor` collections; nothing is rebuilt or patched.

The archive is signed with the Amber Linux Archive Signing Key
(`481A11AA548332196B290D09C5B067A799C43065`) and this action pins apt to that key
with `signed-by`. It does not use `[trusted=yes]`.

## Inputs

| input | default | description |
|---|---|---|
| `version` | *newest in the archive* | `amber-odin` version, e.g. `2026.08+dev-1`. Pin it when a build must be reproducible. |
| `ols` | `false` | Also install `amber-ols`, the Odin language server. |

## Outputs

| output | description |
|---|---|
| `odin-version` | The `odin version` string of the installed compiler. |

## Examples

Pin the compiler so a green build stays green:

```yaml
- uses: Hyperquader-Coders/setup-amber-odin@v1
  with:
    version: 2026.08+dev-1
```

With the language server, for a job that checks or formats:

```yaml
- uses: Hyperquader-Coders/setup-amber-odin@v1
  with:
    ols: 'true'
- run: ols --version
```

Reading the installed version back out:

```yaml
- uses: Hyperquader-Coders/setup-amber-odin@v1
  id: odin
- run: echo "built with ${{ steps.odin.outputs.odin-version }}"
```

## Release cadence

`amber-odin` follows a **monthly** cadence, tracking upstream Odin's
`dev-YYYY-MM` releases rather than nightlies — so `version: ''` moves about once a
month, not once a day.

This action stays at `@v1` across those releases: the tag versions the action's
*interface*, the `version` input selects the *compiler*. Pin the input, not the
action.

## Requirements

- An **Ubuntu** runner (`ubuntu-latest`, `ubuntu-24.04`). The package is
  `amd64`-only.
- `sudo`, which GitHub-hosted runners have.

## Licence

BSD-3-Clause — the same licence as the compiler it installs. See
[LICENSE](LICENSE).

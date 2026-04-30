# Agent Helm — Version

**Current:** `0.0.1` (pre-release, scaffold only)

## Changelog

### 0.0.1 — 2026-04-30
- Initial scaffold.
- Repository created, doc set populated, MIT license, SwiftPM skeleton.
- No functional code yet.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- Pre-1.0: minor bumps for new features, patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.

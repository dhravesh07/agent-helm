# Agent Helm — Version

**Current:** `0.0.6` (read & edit any text file; markdown Preview/Source toggle)

## Changelog

### 0.0.6 — 2026-04-30
**File reading & editing — full rewrite of the right pane.**
- All UTF-8 text files are now editable, not just `.md`. Code, JSON, YAML, TOML, configs, plain text — anything decodable as UTF-8.
- Markdown files get a **Preview / Source** segmented toggle. Default = Preview when opening a `.md`; switch to Source to edit. The preview renders the in-memory buffer, so toggling Preview after edits shows your changes immediately.
- Source editor uses monospaced font for non-markdown text and proportional for `.md` source.
- **Save** button + Cmd+S shortcut; **Discard** button reverts the buffer to the original. A "Modified" indicator appears in the header while the buffer is dirty.
- Save-status line: shows "Saving…" → "Saved {time ago}" → or surfaces a save failure inline.
- File size cap: 5 MB. Larger files surface as "too large to display" with size shown.
- Binary files (anything that fails UTF-8 decode) surface as "Binary file — not shown" instead of garbage.

**Service-layer additions:**
- `RemoteFileService` protocol gains `statFile`, `readFile(at:maxBytes:) -> Data`, `writeFile(at:contents: Data)`. The text/binary decision moves to the caller (SessionState) instead of the service.
- `LocalFileService` writes use `Data.write(to:options: .atomic)`.
- `SSHService` writes use Citadel's `withFile(filePath:flags: [.write, .create, .truncate])` + `file.write(byteBuffer, at: 0)`.
- New `RemoteFileMetadata` (size + optional mtime) used by the integrity baseline that lock-for-editing will plug into in v0.1.

**State model:**
- New `FileBufferState` enum (`.empty / .loading / .text(original:) / .binary(size:) / .tooLarge(size:) / .error(message:)`) replaces nilable strings.
- New `FileViewMode` enum (`.preview / .source`).
- New `SaveStatus` enum (`.idle / .saving / .saved(at:) / .failed(message:)`).
- `SessionState.editText` holds the live edit buffer; `isDirty` is computed against the original.
- Switching files while dirty is refused with a "save your changes" message — a confirmation dialog lands in v0.0.7.

### 0.0.5 — 2026-04-30
- Fix: local hosts auto-connect on selection (no more "Not connected" until manual click).
- Docs corrections from architectural review: supervisor profiles, workspace paths, editing model, connection lifecycle, stop/uninstall/prune lifecycle.

### 0.0.4 — 2026-04-30
- Local-Mac connection kind alongside remote SSH.
- `RemoteFileService` protocol; `LocalFileService` actor backed by `FileManager`.

### 0.0.3 — 2026-04-30
- First functional slice. SSH connect (OpenSSH ed25519 / RSA), SFTP file tree, markdown viewer.

### 0.0.2 — 2026-04-30
- Add Xcode project generated from `src/project.yml` via xcodegen.
- Add `AgentHelm.entitlements`, `Makefile`.

### 0.0.1 — 2026-04-30
- Initial scaffold.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- Pre-1.0: minor bumps for new features, patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.

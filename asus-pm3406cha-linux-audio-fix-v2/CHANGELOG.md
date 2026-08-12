# Changelog

## v2.0.0 - 2026-08-12

- Validated live audio on internal speakers and 3.5 mm headphones.
- Removed coefficient `0x18` from writes and hard verification.
- Kept coefficient `0x23` as best-effort only; removed it from hard verification.
- Changed profile application to complete the full sequence rather than aborting on dynamic readback mismatches.
- Treat EAPD readback as informational.
- Simplified daemon behavior to startup/resume initialization plus debounced jack transitions.
- Removed experimental early firmware and unrelated kernel/CS35L41 paths from the release.
- Added exact hardware gating and GitHub-oriented documentation.

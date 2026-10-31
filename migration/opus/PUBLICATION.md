# Source publication and fixtures

Load this file only for lane A publication or fixture work.

Source publication is serialized. Capture into a separate directory, then use
the canonical importer to validate original hashes, the captured generator and
offline runtime, native world inputs, required fixture keys and complete outputs
before publication. Keep that producer identity on every fixture section. Do not
relabel an older capture after editing the generator or copy source-editor
`.import` descriptors into the native project:

```powershell
node tools/import_source.mjs C:/path/to/steel_vs_swarm --output-root artifacts/source-capture
node tools/import_source.mjs C:/path/to/steel_vs_swarm --publish-stage artifacts/source-capture
godot --headless --path . res://tests/fixture_registry.tscn
```

`data/fixtures.json` is a section registry; its content-addressed JSON parts retain
the complete captured bytes and its numeric tapes preserve the JavaScript parser's
IEEE-754 values across Godot decimal decoding. Never edit either representation
by hand. A native suite change requires regenerating its consumer plan with
`node tools/import_source.mjs --refresh-fixture-consumers`. Isolate an existing
suite using `res://tests/run.tscn -- --fixture-suite=tests/snapshot_suite.gd`;
the full default run is still required. Console samples are bounded per suite;
every assertion failure is retained in `user://source-fixture-failures.jsonl`.

Generated captures use binary Git diffs and preserve their exact bytes. Producer
tools and native test consumers also retain their captured line endings; do not
normalize them independently of their SHA manifests. After staging, validate the
actual commit contents before pushing:

```powershell
node tools/check_git_storage.mjs --staged --verify-fixtures
```

The check rejects regular Git blobs above 100 MiB, raw blobs that bypass an LFS
filter, omitted fixture parts and staged-byte changes to pinned inputs. Keep the
existing oversized world files in LFS; changing diff attributes does not exempt a
file from GitHub's object-size limit.

Use `--status-references`, `--bot-references`, `--companion-references`,
`--missile-defense-references`, `--ability-route-references`, `--tick-references`
or `--death-references` / `--snapshot-event-references` with the source path for focused authority-oracle
publication. Each seals its
producer, rechecks all published original input
hashes and rejects a changed destination without replacing unrelated sections.

Story, loading and logo art (`tools/native_images.mjs`) publishes original PNGs
verbatim and decodes JPEG-under-PNG originals in Chromium into lossless PNGs at
their authored paths. The focused run first verifies every provenance input
against the source snapshot:

```powershell
node tools/import_source.mjs C:/path/to/steel_vs_swarm --native-images
godot --headless --path . --import
godot --headless --path . res://tests/native_images.tscn
```

It accepts the same `--playwright-module`/`--chrome` overrides as below. Godot
never retries an image whose `.import` records `valid=false`; after republishing,
remove only that stale marker and let `--import` regenerate the descriptor.
`assets/logo_flat.png` imports with `fix_alpha_border=false` so faint alpha edges
keep their original colour.

For the isolated procedural-envelope source comparison:

```powershell
node tools/import_source.mjs C:/path/to/steel_vs_swarm --audio-music-gain
godot --headless --path . res://tests/audio_music_envelope.tscn
```

The focused importer accepts `--playwright-module C:/path/to/playwright/index.mjs`
and `--chrome C:/path/to/chrome.exe` when the source development browser helper
is unavailable. It verifies the existing audio-source provenance before atomic
publication and rejects source or destination changes during capture. The scene
checks only the envelope; playback, resampling and audible integration require
the Sol consumer's acceptance.

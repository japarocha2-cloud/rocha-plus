# Rocha+ LAB — issue #34

Implementation remains on draft PR #33; do not merge into production. `main`,
frozen tags and installed production packages are not changed by these jobs.

## Reproducible inventory

`python3 tools/lab/catalog.py` reads all 25 sources listed in #34 and IPTV-org
channel metadata. Original source snapshots, hashes, per-origin counts and
failures are retained in `build/lab/`. Use `--offline` to reproduce from the
saved snapshots. The APK embeds the eligible candidate snapshot; it does not
silently substitute a changed live directory during a cohort.

The initial complete inventory contains 55,267 occurrences, 11,366 unique URLs,
43,901 duplicate occurrences, 479 eligible candidate URLs (77 beyond the current
BR + Sports sources), and 11 blocked URLs. These are inventory counts, NOT
playback results. See `issue34-inventory-summary.json` for source hashes/counts.
The previous 509 figure is not an approval count and is not reused here.

Normalization preserves query order and all signature parameters, lowercases
scheme/host and removes default ports/fragments. Channel IDs group alternative
URLs without dropping them. Portuguese eligibility uses language metadata or
Portuguese-source membership; Brazil membership is recorded separately and
never claimed as proof of Portuguese. Football uses explicit names with
NFL/rugby/American/Australian football exclusions. Football labels still require
editorial review; a generic sports category is insufficient. Permanent and
user-defined blocks are excluded. Incomplete source fetches remain explicit.

The six largest additional themes suitable for review are Filmes (33), Música
(23), Documentários (10), Entretenimento (38), Religiosos (28), Educação (23).
They are candidate distributions; categories in production are not modified.
Other existing metadata, including Séries/Cultura and ambiguous Outros, remains
visible for review rather than being forced into a misleading category.

## Ordered validated catalogues

The consolidated artifact contains `catalog-index.json`, ordered as TV ao Vivo,
Esportes, Infantil, Notícias, Filmes, Séries, Documentários, Música, Educação,
Cultura, Entretenimento, Religiosos, Futebol and Outros. The first four retain
the existing product order. Each category with measured audiovisual passes gets
its own JSON, CSV and M3U in `categories/`, with editorial priority for familiar
Brazilian channel brands first, followed by accent-insensitive alphabetical
order, and the preferred player in JSON/CSV. `PRIORITY` in `aggregate.py` records
the explicit order; it is editorial curation, not a measured audience ranking.
The same ordering applies to combined approved M3Us. Priority never overrides
validation or blocking. Empty categories have
an explicit pending entry in the index and no playlist. Pending, failed and
blocked candidates cannot enter these catalogues. Regeneration removes stale
category exports. These are LAB deliveries; production remains frozen.

## Android execution

`Rocha LAB Android evidence` builds a debug `com.rochaplus.app.lab` APK without
Firebase/login/Cast startup. Debug-only `LabActivity` exposes app-private export
storage and launch configuration. Its HTTP allowlist is generated only for the
candidate hosts plus the emulator-host fixture; release transport policy is
unchanged. This bridge cannot operate under the production package name.

The first gate runs a locally generated colour/motion + 440 Hz sine fixture and
a deliberate HTTP 404 URL. Both engines must play the positive fixture, reject
the negative fixture and produce observable output before the channel jobs run.
The supplied workflow progresses through 10 then 25 URLs, then the remaining
candidate URLs in cohorts of at most 25 with at most two emulators in parallel. Each URL runs 60 s
ExoPlayer, 60 s LibVLC and 180 s confirmation with the technical winner. Fatal
open errors can terminate a sample early and are recorded as errors, not passes.
This is at most 175 minutes of channel observation for the initial 35 URLs.
A full 479-URL serial pass would require approximately 40 playback hours before
setup/retries (approximately 20 hours elapsed at the two-emulator limit); do not
confuse the first cohorts with a completed full catalogue. Each shard has its own
155-minute job deadline and recoverable evidence; failed shards do not cancel others.

Every stage is checkpointed, results are exported after every channel, and an
exception on one URL is recorded while the loop continues. At a failed
infrastructure gate the downstream cohorts are deliberately blocked. A manual
stop preserves earlier completed stages. Device loss is detectable from the
driver deadline and preserves host-side downloaded checkpoints.

The Android driver launches without channel-by-channel manual interaction:

```
python3 tools/lab/run_android.py --stage smoke
python3 tools/lab/run_android.py --stage batch10
python3 tools/lab/run_android.py --stage batch25
```

It requires ADB, the generated LAB APK, Python numpy/Pillow, ffmpeg and a dedicated
PulseAudio sink `rocha_lab`. It assumes the fixture HTTP server at host port 8765.
See the reusable device workflow for exact setup and emulator flags.

Audiovisual cohorts use the full emulator binary on Xvfb, not `-no-window`:
the Android QEMU source contains `audio/paaudio-headless-impl.c` whose PulseAudio
constructors return NULL and whose connection function returns -1. Merely
starting a PulseAudio server cannot enable that stubbed implementation.
Source inspected: platform/external/qemu commit
`ae9d18d2b6261179fbd57fffec720a04f7bfb053` on android.googlesource.com.
The UI-only screenshot job may use headless/no-audio and makes no sound claim.

## Measurements and the meaning of a pass

- API metrics: monotonic request-to-first-progress startup, observed playhead
  advancement, buffering and stationary runs of at least 3 s. A technical
  preference requires the complete 180 s confirmation, at least 80% observed
  progress, video dimensions/track, no errors, at most 3 stalls and at most 10%
  buffering. These are explicit initial LAB thresholds, not a service SLA.
- Screenshots: ADB captures cropped to the measured video viewport every 10 s.
  Automated changing-pixel evidence requires at least three frames and two frame
  differences above 1/255 mean RGB amplitude. Inspect saved PNGs to verify actual
  content; moving graphics/spinners and static programmes require caution.
- Audio: signed 16-bit PCM recorded from the dedicated emulator PulseAudio sink
  monitor. Reports contain duration, RMS dBFS, peak and non-silent fraction.
  Output evidence requires at least 20 s, RMS above -60 dBFS and over 1% samples
  exceeding 0.001 amplitude. The known sine fixture calibrates this path first.
  PCM energy proves output signal, not human audibility or programme identity.
- ExoPlayer's plugin does not report audio-track presence; that field remains
  unknown/false rather than invented. Track detection is not given score credit
  because the APIs have unequal capabilities.

`automaticAudiovisualPass` combines stable confirmation with varying captured
pixels and measured audio output. It is conservative: static or quiet material
can be inconclusive. No result is marked production-approved. Human audio/picture
checks remain separate and cannot be asserted by track/position API readings.

## Recoverable exports

Each CI cohort uploads its APK reference, `device.txt`, logcat, per-stage JSON,
`status.json`, `phases.json`, `results.json`, `results.csv`, cropped PNGs, PCM WAV
samples with measurement JSON, `measured-results.json` and
`automatic-audiovisual-pass.m3u`. M3U records are sorted by category and name.
An additional `audiovisual-checked.m3u` contains only explicitly human-checked
stable results; it may correctly be empty. Candidate Portuguese/Brazil and
multilingual-football M3Us are exported separately by the inventory tool and
clearly labelled as unvalidated candidates. No playlist is imported into
production by this tooling.

Do not label a queued/running workflow, successful build, source HTTP 200,
track detection or an empty export as completed audiovisual validation.

`tools/lab/aggregate.py` merges recovered measured reports against the frozen
inventory snapshot, exports complete per-player metric columns and lists
pending URLs explicitly. It distinguishes failed/inconclusive evidence from
proven source unavailability. The final aggregate job runs even if a shard
fails; its M3Us contain only automatic audiovisual passes and never production
approval. Downloadable evidence excludes duplicate copies of the APK.

Network and geography: GitHub-hosted emulator runners are not guaranteed to be
in Brazil. A geoblocked/region-dependent response is not evidence that a channel
is unavailable worldwide. Retain raw errors and test environment details.

Audio analysis trims the first 5 s and last 10 s of recordings longer than 20 s
to exclude asynchronous player-transition boundaries. File duration and analysed
duration are reported separately. Consolidation re-measures available WAV/PNG
artifacts instead of trusting prior pass flags. Updated commits cancel obsolete
LAB workflow runs; always-upload steps preserve collected checkpoints.

The smoke gate also checks that the controlled scene exposes all three RGB
components in multiple captured frames and that the measured audio spectrum
contains the generated 440 Hz tone. A moving loader or unrelated system sound
is insufficient to calibrate the measurement path. A widget startup regression
test covers the debug assertion caused by returning a Future from setState.

VLC dependency pairing is pinned to flutter_vlc_player 7.4.3 and platform
interface 2.0.5. Version 7.4.4's Android source uses Pigeon 25.2.0, while the
published 2.0.5 Dart interface uses Pigeon 0.2.1; these have incompatible channel
names/codecs. The CI verifies source generator versions and initialization/
create/dispose channel names before building. Failed player cleanup is retained
as a sample error, so later channels can still run.

Device jobs use the AOSP Android 15/API 35 image to avoid Google/Pixel Launcher
background ANR dialogs. A frame counts as output evidence only when window
focus belongs to Rocha+ LAB; obstructed screenshots are saved separately. The
PulseAudio route uses an explicit private Unix socket, output sink and disabled
unused audio input.

## Feature laboratory: remote, preview and new category routes

The manual LAB player screen has a TV button (`Testar interface, controle e
Cast`) opening the feature laboratory in the same isolated debug package.
Existing release/login routes retain the frozen four-category navigation.
The feature Home adds Filmes, Séries, Documentários, Música, Educação, Cultura,
Entretenimento, Religiosos and Futebol, with real category routes even when
there are no validated channels. No candidate directory is used as a fallback.

`ValidatedLabRepository` reads `branding/lab_approved.json` (initially empty) or
an explicitly imported `validated-catalog.json` in the current LAB run directory.
It requires a measured audiovisual pass, a stable 180-second confirmation,
matching channel URL and pixel/PCM evidence flags; blocked/quarantined channels
remain excluded. The upstream aggregator retains/rechecks original evidence.
Use `python3 tools/lab/install_validated.py --report <consolidated-results.json>`
to import the aggregate snapshot into the debug app, or `--asset` before an
isolated debug APK build. This never writes to the production package/catalogue.

The channel preview opens real playback after user selection. It can expand
into fullscreen and uses the same approved playlist. Film category filters
use explicit `genres` metadata only; missing genres remain `Sem gênero informado`.
This is organization of live movie channels, not a VOD library of film titles.

The shared playback session supports CH+/CH- and PageUp/PageDown plus visible
previous/next buttons in both engines and the Cast controller. Arrow keys remain
available for focus traversal. Channel lists wrap, deduplicate URLs and skip
blocked/quarantined signals. During Cast a new selection sends a new load into
the existing receiver session; its label/content ID commits only after that
receiver confirms playback of the requested URL. Failed changes remain explicit
and do not claim the new channel is playing. The same Cast transport is exposed
from ExoPlayer and LibVLC. These unit/widget tests verify sender behavior only:
physical Chromecast/TV remote button delivery, network discovery, audiovisual
Cast quality and reconnection require a real receiver on the same network.
No receiver is available in the headless Android CI, so physical Cast is pending.

## Player/channel transition regression

The LAB now persists each completed phase before tearing down a native player,
then persists the complete channel/export before entering the next channel.
Decoder output is stopped while its surface still exists; the Flutter video
widget is removed for a frame before controller disposal. The pinned VLC 7.4.3
native dispose method released its texture before stopping/detaching the decoder.
`patch_vlc_lifecycle.py` copies that dependency into `build/lab-vlc-plugin` and
reorders the teardown in the isolated copy. A temporary pubspec override is used
only in LAB jobs; the package cache and frozen release are not modified. Original
and patched Java hashes are exported. Unexpected source code rejects the patch.
The Android smoke gate now uses two positive A/V URLs followed by a negative URL,
requiring the second full channel to finish after the first rather than only
checking a single successful channel. A native crash cannot be caught by Dart;
the saved phases/channel checkpoint is the recovery boundary.

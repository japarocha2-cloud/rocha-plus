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

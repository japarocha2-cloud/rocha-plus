# CazéTV: development status

Frozen main base: 231bca553bdd2417ae33bab68fd324d783febdf1.
Work stays on feat/cazetv-official-embed / PR #13. Do not merge before device validation.

The approved dark/gold screen has the title “CazéTV • Oficial”, a large 16:9
official YouTube player, loading status and retry. No catalog is displayed
until an official catalog is available.

CAZETV_YOUTUBE_VIDEO_ID remains unset by default. A candidate ID is checked
against YouTube's HTTPS oEmbed metadata before loading. Only the official
@CazeTV handle or channel UCZiYbVptd3PVPf4f6eR6UaQ is accepted.
Missing/malformed metadata, network failures and other publishers fail closed.
The returned HTML is never executed; the app constructs the official embed URL.
Metadata validation is not proof of current embed permission, regional access,
live status or successful playback. YouTube's own player shows playback errors.
A 20-second page-load timeout enables retry; page completion does not mean playing.

Source references:
- https://www.youtube.com/@CazeTV
- https://linktr.ee/VemPraCazeTV
- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/terms/required-minimum-functionality

Before configuring a release, obtain a current video from the official channel,
confirm embed permission and test it on Android phone and TV in the intended region.
Record commit, video URL, device/OS, date, audio/video progression, retry after
offline failure, and YouTube playback errors (including 101/150/153).
Regression-test existing player, Cast and fullscreen separately.
No stream extraction, retransmission, ad removal or custom Cast for YouTube.

CI runs static analysis, unit/widget tests and a clearly named visual preview build.
That artifact is not a functional CazéTV beta. Do not deliver it for playback testing.
A signed functional build and physical playback evidence remain pending.

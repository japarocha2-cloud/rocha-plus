# CazéTV: development status

Frozen main base: 231bca553bdd2417ae33bab68fd324d783febdf1.
Work stays on feat/cazetv-official-embed / PR #13. Do not merge before device validation.

The approved dark/gold screen has the title “CazéTV • Oficial”, a large
official YouTube player, loading status and retry. No catalog is displayed
until an official catalog is available.

CAZETV_YOUTUBE_VIDEO_ID remains unset by default. A candidate ID is checked
against YouTube's HTTPS oEmbed metadata before loading. Only the official
@CazeTV handle or channel UCZiYbVptd3PVPf4f6eR6UaQ is accepted.
Missing/malformed metadata, network failures and other publishers fail closed.
The returned oEmbed HTML is never executed. Our own local wrapper loads only
YouTube's official IFrame API, with the installed app ID as baseUrl/Referer and
origin. Controls and ads stay visible, with autoplay disabled.
Metadata validation is not proof of current embed permission, regional access,
live status or successful playback. Official onReady/onStateChange/onError events
update the screen; page completion never clears the player loading indicator.
A 20-second player-readiness timeout enables retry. YouTube errors 2/5/100/101/150/153
have clear messages. Retry clears status and ignores messages from the prior session.
The playing label reflects API state 1; it does not certify physical video/audio.
The player viewport is at least 200 pixels high on narrow phones.

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

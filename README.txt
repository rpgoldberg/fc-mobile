TYPE-1 before/after pairs (fc-mobile PR #46), round 2. Every pair is labelled by the step it shows.
Right side: the PR head. Left side, by file prefix:
  2xs_* / 2xs+xs_* / desktop_*: develop 7d1fad1 with only the PR's dev fixture switch (?fxsync=1, commit e8435c7) added, so both sides draw the same tile badges and counts.
  xs-only_*: the PR head with the xs pair (7e67350 + 2c9fb33) reverted, so only --font-xs (11 -> 12 px) differs.
Same seed on both sides: the 7 dev fixtures (x2 with ?fxsync=1), a fixed clock (2026-10-13 14:05 CDT, zone America/Chicago),
and a fixed storage estimate (Settings shows navigator.storage.estimate, which differs per browser context). The version row differs by build id.
Fold8 cover panel 444x701 CSS px at DPR 2.8125 (cover-*; Settings and Profile scaled 50 %), desktop 1280x800 (desktop-*).
Font: the capture machine has neither Inter nor a CJK font (fc-list :lang=ja is empty), so text is DejaVu Sans, as in CI.
The round-1 timestamp pairs (cover-asof-tiles, cover-detail-asof at 053ca2e) came from two different stack seeds,
and their boxes in place of a Japanese name were that missing CJK font on the capture machine, not the app. Round-1 files are removed here; they stay at 053ca2e.

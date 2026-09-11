# Plant mailbox

## Implemented frontend

- Home mailbox hit target opens an overlay above the current home.
- Unread mail shows the NEW mailbox. Tapping its envelope immediately opens it.
- No unread mail opens the list directly; an actually empty result has its own empty state.
- Closing the list shows the mailbox illustration; its envelope reopens the list.
- Closing an opened letter returns to the list. The outer close button exits to home.
- Opening runs closed envelope → vertical paper extraction → front-facing letter,
  using the static states from Figma 3852:4 and the revised Flutter-authored motion.
- Before opening, an 800 ms pull-in runs from the tapped envelope/visible list row:
  100 ms press, 280 ms upward lift with a 5° envelope tilt, then 420 ms of calm
  centered travel without overshoot. The departure scene fades out in proportion
  to those stages, then the 2300 ms opening starts automatically. Coordinates are converted from the
  actual render box into the 402×874 canvas, including scroll/scale transforms.
- The opening uses explicit normalized stages: flap reveal 0–20%, extraction
  18–62%, and presentation 62–100%, all with calm ease-in-out curves. One native
  348:253 paper is scaled from 212×154 inside the envelope, rises straight from
  `(95,365)` to `(95,185)`, then approaches the viewer upright at the unchanged
  final rectangle `(27,311,348,253)`. It never spins or overshoots.
- During extraction the paper is painted between the envelope backing and front
  layers and clipped at the pocket bottom. The clip releases only once its bottom
  clears the mouth; for presentation the paper is painted above the fading envelope.
- Reduced motion skips directly to the opened state. Read acknowledgement is requested only after opening completes, separately per letter, and can be retried.

## Integration boundary

Debug builds expose **편지 모션 미리보기** at the bottom of the mailbox.
It opens an isolated preview route with one explicitly labeled sample letter.
Tap its NEW envelope to run the actual pull/open animation; **처음부터** resets
to NEW and **미리보기 종료** restores the untouched original mailbox.
The preview never queries a repository or acknowledges reads. Both its controls
and sample-data branch are guarded by `kDebugMode` (absent in profile/release).

There is **no dedicated backend letter API** in this checkout. Chat messages and
notification counts are not letters and are not reused as mail. Production has
no fixture letters and shows “편지 서비스 연결을 준비 중이에요.” until a concrete
`PlantLetterRepository` is supplied to `HomeScreen.letterRepository`.

The repository must return the selected plant's letters (id, recipient, sender,
body, creation time, read status) and persist idempotent read acknowledgement.
The UI sorts newest first. Authentication, pagination and actual delivery need
the backend contract before an HTTP implementation can be added.

## Design and motion

Sources: 3725:19529 (mailbox), 3652:15470 (new), 3765:51829 (list),
3852:4 (opening states). Original SVG layers live in `assets/images/mail_*.svg`.
Figma returned no keyframe timelines, so the user-requested interpolation is
authored in Flutter with configurable 800 ms pull and 2300 ms opening tokens,
not an exported prototype timing.

Mailbox houses, foreground and animated envelope layers use transparent PNGs
exported directly with Figma `exportAsync(contentsOnly: true)` at 2x. This
preserves inner/drop shadows, noise, and the foreground Multiply texture mask
that Flutter SVG drops. Placement uses absolute render bounds (including effect
insets), not the unexpanded node bounds. Originals remain in `mail_*.svg`.
Sources: house 3725:21293, new house 3652:16040, foreground 3725:21316,
closed envelope 3725:21676; opening layers 3817:21/26/28/67/23.
The final text-bearing paper remains native Flutter for real letter content.
The deferred home device-connection panel visibility is unchanged.

## Verification

`flutter test test/mailbox_test.dart test/home_screen_test.dart test/home_nav_bar_test.dart`

Mailbox tests cover both branches, no integration versus empty data, retries,
cancelled opening, reduced motion, concurrent read acknowledgements, source-less
opening, extraction clipping/upright geometry/continuity, completion timing, and six
402×874 snapshots (house, new, closed, opening, opened, list), plus a pull-in
snapshot and a scrolled-row origin test at 2x screen size. Test fixtures are only in
the test directory. These tests are not proof of server delivery or simulator
end-to-end integration.

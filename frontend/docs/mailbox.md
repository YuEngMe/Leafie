# Plant mailbox

## Implemented frontend

- Home mailbox hit target opens an overlay above the current home.
- Unread mail shows the mailbox with the orange `!` marker. Tapping its visible
  envelope requests that letter's detail, then starts opening only after the full
  content arrives. A failed detail request shows retry/cancel actions and never
  substitutes the list preview for the body.
- No unread mail opens the list directly; an actually empty result has its own empty state.
- Closing the list shows the mailbox illustration; its envelope reopens the list.
- Closing an opened letter returns to the list. The outer close button exits to home.
- A left swipe reveals the trash action but does not delete. Deletion requires the
  `네/아니오` confirmation; the row disappears only after the server succeeds.
  Failure leaves the row in place with an explicit retry. Long press and a custom
  semantic action expose the same trash action without a swipe.
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
- Missing selected-plant state directs the user to plant registration instead of
  presenting it as a letter-service wait state.

## Integration boundary

Debug builds expose **편지 모션 미리보기** at the bottom of the mailbox.
It opens an isolated preview route with one explicitly labeled sample letter.
Tap its marked envelope to run the actual pull/open animation; **처음부터** resets
the preview and **미리보기 종료** restores the untouched original mailbox.
The preview never queries a repository or acknowledges reads. Both its controls
and sample-data branch are guarded by `kDebugMode` (absent in profile/release).

`LetterApi` is the production `PlantLetterRepository` used by home. It connects
the paginated plant-scoped list, detail, read acknowledgement, and delete routes.
List responses carry only `preview`; the full `content` comes from detail. The UI
sorts newest first and guards stale detail responses, cancelled openings,
concurrent read acknowledgements, and duplicate delete submissions.

The API route is available, and diary create/update calls the backend
`reserve_letter` producer when letter generation is enabled. Real letter delivery
is not yet verified end-to-end because the worker currently uses
`UnconfiguredLetterSensorSummary`, which raises `LETTER_SENSOR_NOT_CONFIGURED`.
The debug preview therefore remains until a real account receives, opens,
acknowledges, and deletes a generated letter.

## Design and motion

Current mailbox/list target: Figma section `4691:2` at 402×874. Opening motion
still derives from the static states in `3852:4`. Original SVG layers live in
`assets/images/mail_*.svg`.
Figma returned no keyframe timelines, so the user-requested interpolation is
authored in Flutter with configurable 800 ms pull and 2300 ms opening tokens,
not an exported prototype timing.

The current house/title/envelope, foreground, paper texture, and animated layers
use transparent exports from Figma (house at 2x, paper texture at 3x). The house is shared by read/unread states;
`mail_unread.svg` supplies the exact orange marker. The list close and delete
glyphs are the exact exports rather than Flutter-drawn substitutes. PNG layers
exported directly with Figma `exportAsync(contentsOnly: true)` at 2x. This
preserves inner/drop shadows, noise, and the foreground Multiply texture mask
that Flutter SVG drops. Placement uses absolute render bounds (including effect
insets), not the unexpanded node bounds. Originals remain in `mail_*.svg`.
Current house source: `4534:12042`; paper texture/effect source: `4534:16839`.
Opening layers remain `3817:21/26/28/67/23`.
The final text-bearing paper remains native Flutter for real letter content.
The deferred home device-connection panel visibility is unchanged.

## Verification

`flutter test test/mailbox_test.dart test/home_screen_test.dart test/home_nav_bar_test.dart`

Mailbox tests cover preview/list/empty/null-plant branches, detail-before-body,
long content, stale and failed detail requests, read failures, reduced motion,
cancelled opening, successful/failed/cancelled/duplicate/last-row deletion,
slow-drag reveal, scroll/scale origin conversion, upright opening geometry, and
ten 402×874 snapshots including the three-row list, revealed trash, and delete
confirmation states. Test fixtures are only in the test directory. These
tests are not proof of real generated-letter delivery or physical-device behavior.

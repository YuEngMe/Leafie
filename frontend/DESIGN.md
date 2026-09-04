# Leafie Flutter Design Contract

## 1. Product direction

Leafie is a bright, friendly plant companion. The current product surface follows the Figma `와프4차` orange system with white space, soft pill controls, and one clear primary action per screen.

## 2. Sources

- Figma file `KhDBMZrMNV5hisim2Kvr4x`, page `디자인방`, section `산뜻한 새출발~와프4차`.
- Component guide node `1994:4439` and the 12 audited auth, registration, and home frames.
- Target implementation viewport: iPhone 16 Pro logical size `402 x 874`. The current Figma frames are still `393 x 852`, so changeable geometry lives in `lib/theme/app_layout.dart`.

## 3. Color tokens

- `kOrangeMain`: `#FFB52A`, primary actions and active progress.
- `kBrightOrange`: `#FF8834`, form labels and small highlights.
- `kPaleYellow`: `#FFECA6`, selected rows and quiet emphasis.
- `kAppleGreen`: `#C1E25F`, home accents.
- `kTextDark`: `#444444`, `kTextLight`: `#A1A1A1`, `kGrayLightest`: `#CCCBCB`.

## 4. Typography and spacing

- Paperlogy is the product font.
- Page title: 21/600. Body and CTA: 16/500-600. Supporting copy: 14/400. Caption: 12/400.
- Auth horizontal padding is 34 px; registration content padding is 47 px; pill controls are 52 px high with radius 50.
- Login node `2395:31` (empty), `2395:32` (filled), `2395:33` (password error),
  `2395:34` (password revealed). The lockup is 118.58 px wide with a `0.98` mark
  ratio; links inset 11 px; link/button/divider weights are 500/500/600. Spacing
  runs logo 156 → email 382 → password 445 → links 506 → button 558 → divider 694
  → social 735, and those gaps live in `AppLayout`. The error state keeps its
  layout because `LoginCredentialsForm` positions the message over the links row.

## 5. Reusable primitives

- `PrimaryButton`: full-width 52 px orange/disabled-gray pill.
- `RoundedInputField`: borderless white pill with a soft shadow and optional orange label.
- `RegisterStepScaffold`: centered app bar, five-wave progress, title/subtitle, and fixed bottom CTA.
- `BrandLogo` and `PlantCharacterArt`: Figma-exported art kept separate from layout and icon slots.

### Figma onboarding component mapping

The canonical onboarding component section is node `2307:1815`. Screens use
semantic Dart enums while each enum value retains the original Figma property
value and variant node ID for traceability.

- `PrimaryButtonVariant`: enabled `2307:2086`, disabled `2307:2087`.
- `SignupEmailFieldVariant`: verification sent `2315:2421`, empty `2315:2430`, filled `2315:2439`.
- `SignupPasswordFieldVariant`: empty `2315:2441`, filled `2315:2443`, error `2315:2456`.
- `SignupNicknameFieldVariant`: empty `2315:2475`, filled `2315:2476`.
- `LoginEmailFieldVariant` and `LoginPasswordFieldVariant`: `2353:1018`, `2353:989`, `2353:1019`, `2353:990`.
- `TermsAgreementSheet`: `2315:2508`. Rows use `2315:2488`/`2492`/`2496`/`2500`.
- `ConfirmDialog`: the shared body behind `SignupAbortDialog` (`2353:1045`) and
  `SignOutConfirmDialog` (`2353:721`). Both nodes share every coordinate, so only
  the message differs. Absolute layout, so the widget mirrors the Figma
  coordinates in a `Stack` rather than a `Column`.

### My page components

Wired into `MyPageScreen` (`lib/screens/my_page_screen.dart`), reached from the
home screen's 마이 nav pill.

- `FigmaToggleSwitch`: `2353:575`, on `2353:574` / off `2353:573`. Track 48 x
  24.9231, knob r 10.6154. The Figma variants have their knob positions swapped —
  the designer confirmed this as a mistake on 2026-08-31 — so the widget puts the
  knob on the right when on and keeps every other value from the design.
- `ProfileSummaryCard`: `2353:710`. `kProfileCardYellow` is `kPaleYellow` at 43%
  already composited over white, so the card keeps its color on any background.
- `ProfileMenuCard`: `2353:711`. Rows sit 49 px apart. Figma draws the chevrons
  with a `Sandoll CreamPang` glyph the project does not ship, so the rows reuse
  `FigmaChevronRight` tinted to the node's `#A1A1A1`.
- `OnboardingCopy`: `2315:2514` (left aligned) and `2315:2275` (centered). Both
  put 10 px between the 21 px title and the 14 px `#757575` subtitle, so those
  are the widget defaults and only alignment differs per call site.

#### My page screen layout

`2319:2` (default), `2353:577` (notification toggle on), `2353:624` (sign-out
confirm). Screen is 402 x 874 with the 46 px status bar included; the golden runs
without one, so every mock y needs that offset subtracted.

Cards are 344 wide, which fixes the horizontal padding at `(402 - 344) / 2 = 29`.
Profile card top 119, height 77.762; menu card top 211, height 241; logout button
top 790, height 51.

The button is pinned to the bottom with a `Spacer`, not a fixed gap — the mock's
338 px between menu card and button overflows any viewport shorter than the
design frame. `myPageBottomGap` is `33 + 46`: the mock's 33 px below the button
plus the status bar height `SafeArea` reclaims, since `Spacer` hands that space
to the bottom.

The mock has **no bottom navigation bar** — this screen is pushed over the home
screen and left with the back arrow.

#### My page sub-screens

`3369:18` holds the whole my-page flow — 17 screens, not the 3 first built. Two
are now wired; the password-change chain (7 screens) is still open.

**내 정보 수정** (`2316:6397`, `2353:376`, `2353:440`): one nickname field.
Label at 45/145, field 34/169, button 34/244 — note the label is indented 11 px
past its field here, which signup does not do. The field starts empty with only
its hint, and the button stays disabled until something is typed. On save the
screen pops its new nickname and my page redraws the card with it (`2353:290`).

**회원 탈퇴** (`2570:1994`, `2570:11895`): headline 45/140, notice box 45/241
(312 wide, inset shadow rather than a border), consent row 45/357, divider at
y 446 spanning 354 from x 24, button 34/466. All three notices must be read and
the consent box ticked before the button unlocks; tapping the label toggles it
too. The box's height is left to its content — pinning the mock's 105 overflows
once the three 23 px lines and their gaps are laid out.

Both screens share `myPageSubHorizontalPadding` 34, which differs from my page's
own 29 (its cards are 344 wide, these are 334).

### Icons: assets vs. code

#### Back chevron (`3345:996`)

The designer replaced the app bar's back arrow on 2026-09-05 and asked whether
it could still be changed — it could, because all seven screens with a back
button share `YesoAppBar`, so the swap was one call site.

`Polygon 4 (Stroke)`, 11.4824 x 18.0019, `#CCCBCB`, left edge at x 21.5 and top
at y 60 (14 inside the bar, once the 46 px status bar is removed). Its tips are
rounded and the vertex is slightly blunt, so it ships as an asset rather than a
painter.

`download_assets` returns two SVGs for this node and only the smaller one is
usable: the `export` entry bakes in the canvas backdrop (an `#F5F5F5` rect, an
`#A0A0A0` page-sized path, the white screen frame), while `svgAssets` carries
the bare path. That one points up (18 x 11.48) rather than left, so the
committed file takes the rotated path out of the export and drops everything
else — the same canvas-artifact problem the social logos hit.

Setting this icon also fixed the bar itself: `YesoAppBar.height` is now **46**,
not Material's `kToolbarHeight` (56), which had been pushing both the chevron
and the centered title 5 px below the mock on every screen.

#### Bottom navigation (`3173:113`)

Delivered 2026-09-05, closing the `TODO(design)` that had blocked this bar since
`2346:2519` shipped without an icon layer. The redraw drops the yellow pills and
the text labels — four icons on white, bar height **79** (was 88).

| icon | node | x | y | size |
|---|---|---|---|---|
| 홈 | `3173:103` | 35 | 22 | 37 x 35 |
| 기록 | `3173:87` | 139 | 24 | 31 x 33 |
| 달력 | `3173:94` | 240 | 22 | 32 x 35 |
| 마이 | `3173:108` | 338 | 25 | 29 x 32 |

Centre-to-centre spacing runs 101 / 101.5 / 96.5, so the row is **not** evenly
distributed — the icons are placed at the mock's own x values rather than with
`spaceEvenly`.

Three icons come straight from `svgAssets`. 기록 has none (it is five rectangles,
not a vector) and its `export` carries all four canvas artifacts, so the
committed file keeps only the five `#FFB52A` rects: the notebook body, the
bookmark, and three rings.

The mock draws no selected state — all four icons are the same orange — so the
bar does not indicate the current tab. Confirmed as intended on 2026-09-05.
Icons are 29-37 px, smaller than a finger, so each one keeps its mock position
while padding its tap target out to 48.


Two files hold the designer's icons, split by what the icon is.

`lib/widgets/figma_asset_icons.dart` renders committed SVGs through
`flutter_svg`. Anything whose shape is itself the asset goes here — brand logos,
and icons whose curves or overlaps would only ever be approximated in code.
Figma bakes its canvas into every export, so each committed SVG has had the
`#F5F5F5` / `#EBEBEB` / `#A0A0A0` backdrop and the `#9747FF` selection outline
stripped out.

`lib/widgets/figma_glyphs.dart` reproduces the rest as `CustomPainter`
polylines, keeping the original Figma coordinates as constants. These are simple
shapes the screens recolor through a `color:` parameter — a check that is orange,
gray or white depending on state, a chevron in three grays — so one painter beats
one asset per color.

- `FigmaCheckedCircle`: `2315:2486` circle `#FFB222` plus the `2315:2487` white check.
- `FigmaCheckMark`: `2315:2494` orange check stroke, no surrounding circle.
- `FigmaChevronRight`: `2315:2495` gray chevron `#CCCBCB`.
- `FigmaEyeIcon`: `2315:2449`, four `#B1B1B1` layers — eye outline `2315:2450`,
  pupil `2315:2451`, and the white/gray slash pair `2315:2452`/`2315:2453`. The
  white slash sits 0.9 right and 1.15 above the gray one to carve the notch.
  Figma only ships the obscured state, so the visible state just drops the slash.
- `FigmaDialogDivider`: `2353:1042`, one `#FFB222` path holding the horizontal
  rule and the vertical split, inset 24.7 px on each side and 7.5 px above the
  card's bottom so it clears the 30 px corner radius.
- Assets: `icon_search` (`2318:3726`), `icon_camera` (`2318:3742`),
  `icon_moisture` (`2346:2536`), `social_naver` (`2353:41`) and `social_kakao`
  (`2353:39`). Apple was dropped from the row on
  the team's call, so the mock's third (empty) circle has no counterpart in code.

### Character registration

- `RegisterProgressBar`: `2307:2015`, five waves, active `#FFB52A` and inactive
  `#D9D9D9` (`kProgressInactive` — not the disabled-button gray).
- Species search dropdown: `2318:3750`. The result card (`2318:3721`) sits flush
  under the input pill with only its bottom corners rounded; rows are 36 px apart
  with a 33 px highlight band.
- Personality step: dots `2318:3925` turn `kOrangeMain` when active; tag chips
  `2318:3966` use `kTagOrange` (`#FF9F6D`) with a 0.827 px border, and that
  screen's title alone uses `kPersonalityTitle` (`#2E2E2E`).

### Modal barrier

`2307:785` is the full-screen dim behind every modal and bottom sheet:
`rgba(0,0,0,0.45)`, kept as `kModalBarrier`. Flutter's default barrier is 54%
and `Colors.black26` — which the terms sheet used — is only 15%, so every
`showDialog` / `showModalBottomSheet` call passes the token explicitly.

### Auth screen layout

Screen-level audit against `2395:38`–`2395:52`.

- Field pitch is 110: `authFieldGap` 35 plus a 75 px label+input group. The
  label's rendered ink sits 4 px lower than the mock's text box, so
  `authFormTopPadding` is 42 and `labelGap` is 1 — with those, all four labels
  land on the mock's 148 / 258 / 368 / 478 exactly.
- The bottom CTA sits 33 px above the frame edge; `authBottomActionPadding`
  is 79 once the home-indicator band is accounted for.
- `2395:46` keeps every label at the same y as `2395:40`, so the error message
  is drawn outside the layout flow — `RoundedInputField` stacks it under the pill
  with `Clip.none` rather than adding a sibling row.
- The eye toggle only shows once a password field has content (`2395:40`) —
  except on login (`2395:31`), where the mock draws it over an empty field.
  `RoundedInputField.alwaysShowEye` picks between the two. **Open with the
  designer (2026-09-05):** the two mocks disagree, and a reveal toggle over an
  empty field reads as a mistake. Login keeps the mock's behaviour until they
  answer; if they say "only when filled", drop `alwaysShowEye` at the call site.
- Password reset drives its send button label from the step —
  발송 / 재발송 / 완료 (`2395:52`, `2395:49`, `2395:51`) — and puts the
  countdown inside the email field rather than in the notice line.
- `2395:44` carries an app bar; its title comes from the entry path because the
  mock says "카카오톡 로그인" while the screen also serves email signup.

#### Login screen vertical rhythm

`2395:31`, measured against a simulator build that sat progressively lower than
the mock. Mock y values include the 46 px status bar; goldens do not.

| element | mock top |
|---|---|
| 로그인 title | 58 |
| logo (symbol + wordmark) | 162.42 |
| email field | 382 |
| password field | 445 |
| login button | 558 |
| divider | 694 |
| social buttons | 735 |

Four constants were wrong, and the errors compounded downward:

- `loginLogoMarkWidthFactor` 0.98 → **0.9174**. The symbol asset is 117x119, so
  a width of `118.581 * 0.98` renders 118.2 tall against the mock's 110.65. The
  factor is now derived from the target height, not eyeballed.
- `loginEmailFieldHeight` 49 → **51**. The mock leaves `2353:24` unsized but
  fixes the password field at 51, and the two pills match. The old 49 had been
  back-solved from a 14 px gap that was itself wrong.
- `loginEmailToPasswordGap` 14 → **12**, now that the field is its real height.
- `loginTitleTopGap` 17 → **12**, and `loginTitleToLogoGap` 65 → **81.42**.

A golden alone cannot catch the logo error: `Image.asset` renders nothing under
`flutter test`, so `BrandLogo` collapses to the 5 px spacer between its two
images and every element below it shifts up by ~150 px. Verify logo geometry
from a device screenshot, or by asserting on the constants.

### Home components

- `_RoomBubble` (`home_screen.dart`): `2346:2375`. White pill, radius 50, shadow
  `0 0 3.338 rgba(0,0,0,0.18)`, 13.353 px `kTextDark` text.
- `PlantRequestBubble`: `2346:2370`. The care-request twin of the bubble above —
  a `kBubbleDot` dot plus `kBubbleGreen` text. Separate widget because the dot,
  colors and metrics all differ.
- `EnvironmentGauge`: `2435:16798`, humidity `2435:16764` / light `2435:16765`.
  Three stacked bars — `kGaugeTrack`, the comfort-range gradient, then the
  current value. The mock's bar widths do not match its own printed percentages,
  so the widget drives the bar from the ratio the caller passes.
- Humidity card `2346:2542` and bottom nav `2346:2519` live in `home_screen.dart`.
  The nav pills are 37.85 x 35 and carry labels only: the Figma node has no icon
  layer yet, so the placeholder Material icons were removed until it does.
- `FigmaMoistureIcon` comes from the committed SVG — Figma exports the shapes as
  `#D9D9D9` placeholders, so redrawing them meant guessing the real colors.

### Diagnosis components

Built from the Figma nodes in `lib/widgets/diagnosis_components.dart`, not yet
wired into a screen — no diagnosis flow exists.

- `DiagnosisEmptyState`: `2346:2466`, which is an empty-state message despite the
  node being named 진단방. Its spec matches `OnboardingCopy` exactly.
- `DiagnosisRecordTile`: `2346:2459`. A 58.196 px pill with `kDiagnosisTitle`
  text and a `kChevronGray` chevron.
- `PrescriptionCard`: `2346:2450`. `get_metadata` reports the photo's pre-rotation
  box (y=240); the rendered position (y=98) is what the widget uses. The red tab,
  red cross and the glyphs inside the recommendation circles are still plain
  placeholders — Figma serves them as SVG assets whose colors could not be read.

### Photo search components

Built from the Figma nodes in `lib/widgets/plant_search_components.dart`, not yet
wired into a screen — the camera capture flow does not exist.

- `PlantResultCard`: `2318:3777`. A tilted `kProfileCardYellow` sheet behind the
  303 x 420 white card. Labels use `kResultLabel` (`#8D8D8D`) in a 44 px column —
  Figma's 35 px clips three Korean glyphs in Paperlogy.
- `PlantResultConfirmButtons`: `2318:3799`. Two 149.28 x 44 pills 27.44 px apart.
  The node is named "결과 항목" but holds the 맞아요/아니에요 pair, not a result row.
- `CameraViewfinderOverlay`: `2318:3948`. Four white corner marks and a centre
  plus, stroke 8 with round caps.
- `PlantDatePickerSheet`: `2318:3831`. An orange sheet with three wheels showing
  five rows; the confirm button inverts to a white pill with an orange label.
  Wired into the environment step, replacing Flutter's Material calendar.

The terms sheet has no unchecked variant in Figma, so unchecked rows fall back to
a gray check and the pill to a gray outlined circle.

`flutter_svg` is intentionally not a dependency. Add a new exported vector to
this file while it stays one or two single-color paths; reach for `flutter_svg`
only once an asset needs gradients, masks, or clip paths.

Code Connect publishing is intentionally separate from this runtime mapping.
It requires a Figma Organization or Enterprise plan with a Dev or Full seat.

## 6. Interaction states

- Every actionable control uses a Material button or tappable semantic widget.
- Registration keeps one mutable `PlantRegistrationDraft` through all steps.
- Completing registration replaces the wizard stack with home.
- Unfinalized action icons stay replaceable and are not treated as final brand assets.

## 7. Accessibility

- Text and controls must remain readable at platform text scaling.
- Primary controls have at least a 48 px touch target.
- Color is not the only carrier of state; labels accompany icons and progress.

## 8. Accepted MVP debt

- Plant creation is still a local dummy response, so the just-registered plant name is held only for the current route.
- Species search and character option identifiers remain local fixtures until their APIs are connected.

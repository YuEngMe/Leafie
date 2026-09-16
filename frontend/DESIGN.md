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

#### Profile data

The card's three lines come from the Supabase session, not the mock. `MyPageScreen`
reads `currentUser` and derives:

- **nickname** — `user_metadata['leafie_nickname']`, the key signup and the
  social-nickname screen already write. The mock draws "김윤지님", so the 님 is
  appended here rather than stored. Falls back to "식집사님" when unset.
- **email** — `user.email`.
- **tenure** — days since `user.createdAt`.

`user` can be injected for tests; `currentUser` is read inside a try/catch so a
widget test without `Supabase.initialize` still renders. `EditProfileScreen`
takes no nickname argument — the mock starts that field empty.

#### My page sub-screens

`3369:18` holds the whole my-page flow — 17 screens, not the 3 first built. Two
are now wired; the password-change chain (7 screens) is still open.

**내 정보 수정** (`2316:6397`, `2353:376`, `2353:440`): one nickname field.
Label at 45/145, field 34/169, button 34/244 — note the label is indented 11 px
past its field here, which signup does not do. The field starts empty with only
its hint. **변경하기 is orange in every frame**, including the empty one, so it
has no disabled state — an empty submit is refused with a snackbar instead.
(비밀번호 변경 does gate its button: `2353:142` draws it grey.) On save the
screen pops its new nickname and my page redraws the card with it (`2353:290`).

**회원 탈퇴** (`2570:1994`, `2570:11895`): headline 45/140, notice box 45/241
(312 wide, inset shadow rather than a border), consent row 45/357, divider at
y 446 spanning 354 from x 24, button 34/466. All three notices must be read and
the consent box ticked before the button unlocks; tapping the label toggles it
too. The box's height is left to its content — pinning the mock's 105 overflows
once the three 23 px lines and their gaps are laid out.

**비밀번호 변경** (`2353:142` … `2346:2722`, done `2346:2773`): the mock has no
field for a verification code, so the screen sends an **email link** — 발송
sends it, tapping it deep-links back and the `passwordRecovery` event flips the
button to 완료.

It calls the same `resetPasswordForEmail` as the logged-out
`PasswordResetScreen`: both mocks title the screen 비밀번호 재설정 and do the
same job, so they should not diverge into different APIs and different email
templates. An earlier attempt used `signInWithOtp` with its own code field —
both were removed.

Because both screens now receive `passwordRecovery`, `main.dart` would stack
its reset screen on top of this one. `ChangePasswordAuth.isOpen` says whether
this screen is mounted so it does not.

Seven mock frames, but one screen — all three fields are always visible and only the email
button's label walks 발송 → 재발송 → 완료. This is *not* `PasswordResetScreen`,
which swaps whole screens across four steps; that one is the logged-out reset
flow. Labels 45/145, 45/255, 45/365; fields at 169, 279, 389; the email field is
261 wide with a 68-wide send button beside it; submit at 34/790.

All three screens share `myPageSubHorizontalPadding` 34, which differs from my
page's own 29 (its cards are 344 wide, these are 334), and all three indent
their labels 11 px past the field — `RoundedInputField.labelIndent`, which
signup leaves at 0.

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

### Plant registration flow

`3369:20` holds 18 frames; six are built. Screens 1-3 were measured against the
mock on 2026-09-05 and had drifted badly — they predate the screen-level audits
the auth and my-page flows went through.

**What was wrong across all three:**

| | mock | was |
|---|---|---|
| field / button x, width | 34, 334 | 47, 308 |
| bottom button y | 790 | 830 |
| headline, subtitle x | 45 | 47 |
| subtitle gap | 5 | 14 |

`registrationHorizontalPadding` is now **34** and `bottomPadding` **0** (the
device's bottom inset covers the mock's 33 px — same double-count as my page).
Headline and subtitle indent 11 px past the fields, matching the my-page rule.

**The wave** (`2315:2237`) is a 238x15 frame whose SVG overflows it — the real
drawing is 243 x 21.425 starting at y 91.79, not 238 x 15 at y 95. The original
constants were right; only the gap around them was wrong.

**Per-screen fixes:**

- **1단계** (`2315:2189`) — the mock takes **only 애칭**; species moves to the
  next screen. Character is 175x150 at y 267, the field label at y 493. The old
  build had two fields crammed at y 248.
- **2단계** (`2315:2515`) — gained the mock's **다음 button** (y 790). Tapping a
  result now only highlights it; the button commits. Step number 1 → **2**,
  which had left the wave identical to screen 1 and step 2 unused.
- **3단계** (`2318:2981`) — copy was wrong throughout: app bar 키우는 장소 →
  **식물 정보**, headline → **내 식물을 챙긴 날은 언제인가요?**, hints 학교 →
  **예: 베란다** and the two dates → **선택하기**. Labels sit 110 apart, which
  needs a 31 px gap rather than the mock's 35 because the label+field group
  renders 79 tall, not 75.

`test/register_flow_layout_test.dart` locks these coordinates.

#### Photo identification (`2318:2815`, `2318:2890`)

The camera button in the species field was `onPressed: null` because these
screens did not exist; `CameraViewfinderOverlay`, `PlantResultCard` and
`PlantResultConfirmButtons` had been built for them and sat unused.

`image_picker` now opens the system camera or gallery — no custom viewfinder is
needed, so `CameraViewfinderOverlay` stays unused for now. iOS needs
`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`, both added.

`PlantPhotoIdentifyScreen` is one screen with two states: 분석 중 while the
identifier runs, then the result card. Headline 205, subtitle 241, character
375 (94 wide), progress bar 492 (180x7, filled 126.768 in the mock — animated
here with that ratio as its maximum). Result: question 169, card 238.62,
buttons 759. All coordinates are relative to the frame, and the screen's
`SafeArea` sits under a 46 px app bar, so the widgets are positioned at
`mock y - 92`.

`identifier` is injectable; the default returns the mock's own 바위채송화 /
돌나무과 / 8월 ~ 9월 until the recognition API exists. Rejecting the guess pops
back to search — the mock has no screen for that branch.


### Diary (`3373:21`)

Three frames: calendar (`2739:34592`), writing (`2739:39308`), reading
(`2739:39860`). The last two are one screen — the same paper, with or without
text — so `DiaryEntryScreen` covers both.

**The background is an asset, not vectors.** The mock draws the hills and clouds
with ~90 ellipses and 27 curves; exporting `2739:34593` as one PNG is both
faithful and a fraction of the work. Same for the book cover (`2739:38324`) and
the paper grain (`2739:34974`, laid at 30% opacity).

**Coordinates are absolute here**, unlike every other screen. The background
runs behind the status bar, so the screens set `extendBodyBehindAppBar` with a
transparent `YesoAppBar` and place widgets at the mock's own y — no `- 92`.

Re-measured against `3496:11674` (2026-09-06) — the earlier node's numbers had
drifted. Cover -57/119 (440x620), three stacked sheets at 132.94 (`#CCCCCC`
342 wide, `#E6E5E5` 345, white 334) plus a white→`#999999` spine at -2. Blue
bookmark 350/274, month buttons 350/535 and 351/603, pencil FAB 302/661.
Photo box 46/143 (304x242), body box 46/395 (304x266).

The mock lays those three buttons out with `rotateZ(3.14)`, so Figma prints
their `left` as 395 — the drawn edge is `395 - width`.

The calendar grid is **not** evenly divided: column widths run 44.30 / 44.30 /
44.30 / 42.19 / 45.36 / 43.25 / 44.30 and row heights alternate 66.95 / 65.90,
so both are tables rather than a multiplication. Grid lines are `#FF8834`,
matching the weekday headers, and there are only five rows — a month needing
six cannot draw its last one.
The date line sits *inside* the photo box's top strip, divided by a vertical
rule at x 212.63 and a horizontal one at y 179.

Weather is five SVGs at hand-placed x positions (217 / 243.09 / 271.99 / 302.23
/ 326.81) — their widths differ, so a row would not line up.

Entries use the diary API through the `DiaryStore` seam. A home diary tab is
keyed and scoped to the active plant, so retained tabs keep state for the same
plant but cannot reuse another plant's month or editor store. Leaving the editor
awaits save/delete before popping; a failed request keeps the complete draft on
screen for retry. A new untouched entry with no title, body or photo is not
deleted, while clearing an existing entry deletes that API record.

Four things only a device screenshot caught (2026-09-05):

- Grid lines are **orange** `#FCB27E`, not grey.
- The grid draws every cell in the weeks the month spans, including the blank
  ones before the 1st — but **only those weeks**. `2739:34987` is 332.65 tall
  over five rows, so a fixed six rows overflows the paper.
- The exported `diary_paper.png` came back pure white, so the paper grain is
  painted instead: fixed-seed dots at lightness 243-253, matching what the mock
  measures. The unusable asset was deleted.
- The mock keeps the **bottom navigation** on this screen. It moved out of
  `home_screen.dart` into `AppBottomNav` so both screens share it.

Three more from the writing/reading screens:

- The title reads **`제목: 귀여운 새싹이`** — the prefix sits in front of the
  value (`2739:39792`), not as a hint that vanishes once you type.
- Writing keeps the bottom nav, the green/pink page buttons *and* the pencil
  FAB. Only the calendar had them at first.
- The mock dates `2026년 7월 15일` as 토요일; it is a 수요일. The code computes
  the weekday, so the two differ on purpose.

### Calendar (`3341:2`, `2687:15303`, `3429:1163`)

Three frames: month, week, and the schedule-add sheet. `calendar_screen.dart`
holds the two calendar frames; the shared card/toggle/pin pieces live in
`calendar_pieces.dart` and the sheet in `calendar_new_event_sheet.dart`.

**Everything inside an event card is measured from the card's own left edge**,
which is why month (card x=13) and week (card x=14) can share one widget: title
+95.29, date +214.15, complete mark +336, and the icon +20 for 분갈이 but +24
for 비료 — the two glyphs have different widths and the mock nudges each.

Cards are 374 x 51 with **radius 50** — a stadium, not the rounded rectangle
28 suggests — a `0 0 4 rgba(0,0,0,0.18)` shadow with no offset, and a
**14 px** gap between them. Their titles are `#1F2E21`, not the usual `#444`.

The **complete mark is a chevron (∨), not a check (✓)**: a 26 px orange circle
with a white 12x8 stroke-2 round-cap V (`3429:1487`). Incomplete is a plain
white circle with no border.

The month/week toggle (`3341:484`) is a 48 x 24.923 orange pill with a
**21.23 px white knob** that slides between the two ends — not a circle sized
to half the track. Its `월`/`주` labels are 12 Regular, and the selected one
turns `#444` while the other goes white.

**Weekday headers do not line up with the grid columns.** The headers start at
x=43.08 (width 14.04, pitch 50.13) while the cells start at x=26.04, so the
header centres land at 50.10 / 100.23 / … — about 1 px left of each cell's
centre. Both are 16 SemiBold. Date numbers are 16 SemiBold whether selected or
not, sitting 8 px in and 7.76 px down inside each cell, and grid lines are a
full 1 px.

The pins differ between the two frames: month is a 332.876 x 52 group at
(35.06, 110) with 20 x 20 heads, week is 342 x 39 at (30, 120) with 10 x 30
bars. Both are `#FFF3C8` heads on `#D9D9D9` bars — the SVGs' inner shadows are
stripped because `flutter_svg` cannot draw them.

The `+` button's exported SVG carries **3.917 px of shadow margin on every
side**, so the 52.833 canvas is placed at (338.08, 726.08) to land the drawn
45 px circle at the mock's (342, 730).

**The schedule-add sheet is a floating card, not a bottom sheet** — 334 x 180
at (34, 590), radius 30, with the `확인` button as a separate 334 x 51 pill at
(34, 790). It is pushed as a transparent route rather than `showDialog`, whose
safe-area insets would shift every coordinate.

Inside it, a **three-column wheel** (`ListWheelScrollView`, `diameterRatio` 100
so the rows stay flat) replaces `showDatePicker`; the selected row is 18
SemiBold `#444` over a 230 x 40 `#FFF3CA` pill at (53, 660), the neighbours 16
Medium `#A1A1A1`. Schedule type is picked from **two 49 px icon buttons stacked
down the right edge** at x=301 — 분갈이 and 비료, the only two the mock offers.
`가지치기` is gone, and so is the `일정 추가` title the app had invented.

### Notifications (`3448:2`)

One flat list is wrong: the mock groups notifications into **`오늘의 알림`** and
**`지난 알림`**, split on whether `createdAt` falls on today's local date. Each
header is Paperlogy 16 SemiBold `#444` at x=34; the first header's ink sits at
y=140 and the first tile at y=169.

Tiles are **pills, not cards** (`3448:26`): 374 x 58.196 at x=14, radius 50,
white on both read and unread, with a `0 0 4 rgba(0, 0, 0, 0.18)` shadow and no
border. They stack 15 px apart, and the gap between one section's last tile and
the next header is 40.

Inside a tile, three things and nothing else:

- a character PNG (`3448:4408`) 30.9 x 46.5 at x=32, vertically centred;
- the title at x=109.293, Paperlogy 16 Medium `#1F2E21`, one line;
- a dot at x=355, diameter 8.188, vertically centred — `#FF5E5E` unread
  (`3448:113`), `#CCCBCB` read (`3456:4891`). Read notifications keep the dot;
  only its colour changes.

The mock has no filter chips, no "전체 읽음" action, no body line and no
timestamp, so the screen draws none of them. `markAllRead` stays on
`NotificationRepository` because the API contract still exposes it.

The character is one asset for every notification: `NotificationData` carries a
`type` string but no character or plant image, so there is nothing to pick a
per-character PNG with. Marked `TODO(design)` in `lib/widgets/notification_tile.dart`.

Flutter renders Paperlogy 16 at a 23 px line height where the mock's text box is
19, so the header-to-tile gap is coded as `29 - 23`, not `29 - 19`.

### My characters (plant management) flow

Eight frames, one entry point: home's `onManagePlants` opens
`PlantManagementScreen`. The old vertical card list is gone.

#### Shelf house (`2316:5103`)

Not a list — a **house**. `#FFECA6` background (`2316:5104`), a white house
silhouette SVG (`2316:5240`, drawn at 368.032 x 729.991 because its shadow
filter bleeds 3 px on each side), and three shelf rules at y=319 / 441 / 563
(`2316:5255`~`5257`: x=57, w=287, h=3, painted in the same yellow so they read
as gaps in the house). A cloud SVG (`2316:5225`) overhangs the top edge and is
clipped.

A white 41 x 86 chimney (`2316:5254`) sits at (278.036, 152.074); it is **not**
part of the house SVG. Both the house and the cloud are drawn `BoxFit.contain` —
`fill` stretched the cloud union and left a stray white ellipse under the title.

Characters sit in a 3 x 3 grid — column centres 98.5 / 200.5 / 305.5, each one
standing **on** its shelf. The first empty slot after the
last plant gets the `+` (`3345:886`, 29 x 29 framed but drawn at 34.048 with its
shadow); with nine plants there is no `+`. Everything the app had invented —
cards, the `선택됨` pill, radio buttons, the species/tenure line, the three
`TextButton` actions, the empty state — is deleted, because the mock has none of
it. Tapping a character selects it (so home follows) and pushes the detail
screen.

#### Character detail (`2564:947`)

`PlantDetailBody` is the shared spine for this flow: a `Stack` whose children
take the mock's **absolute** y minus a 92 px band (46 status bar + 46 app bar),
so every coordinate below is the number written in Figma.

Nickname at y=115 (Paperlogy 21 SemiBold `#2E2E2E`, not `kTextDark`), tenure at
y=146 (12 Regular), character at y=215, trash at (332, 426) 25.057 x 26.576, and
a 344 x 198 card at (29, 465) radius **20** with `0 0 5 rgba(0,0,0,0.2)`. Inside
it, a 12 Regular `#444` label at (52, 481) and three rows whose text tops are
518.762 / 567.762 / 616.762, each with a chevron whose ink ends at x=350.

The grass band is **not** a flat rectangle: `2564:1051` is `#C1E25F` from y=806,
but its top edge is a grass texture and two sprouts (`2568:1085`~`1087`,
`2568:1922`~`1924`) rise ~32 px above it. Those don't survive being re-drawn
from coordinates, so `plant_detail_grass.png` is the mock's own render cropped
to y=770..845 and hung at y=770 — the green starts 36 px into the asset, landing
the band on 806.

#### Character art is padded — compensate at every call site

`leafie_character.png` is 331 x 298 with the drawing occupying only 243 x 206
(73.41% wide); `leafie_character_sprout.png` is 512 x 512 around 362 x 413
(70.70% wide). Passing a Figma node's width straight to `PlantCharacterArt`
therefore renders the character at ~70% of the mock. `plantArtWidthFor(figmaW,
{sprouted})` in `plant_detail_components.dart` divides by that fraction; the
registration flow's hand-tuned 232 / 250 constants are the same correction.
Because the drawn box is bigger than the Figma frame, the shelf grid positions
by the sprout's **ink** bottom (7.03% of the drawn height is empty), not the box
bottom.

#### Delete (`2568:1926`)

Reused verbatim: `CharacterDeleteDialog` in `onboarding_overlays.dart` already
draws this exact 308 x 158.829 box with `삭제하시겠습니까?` / `네` / `아니오`.
The old Material `AlertDialog` (`식물 삭제` / `취소` / `삭제`) is gone.

#### Personality (`2568:1714`)

Read-only — the registration flow picks the personality, this screen shows the
one that stuck. Name at y=132, two 58.693 x 20.667 chips at y=170, character at
y=287, speech bubble 253 x 47.053 at y=475, six dots at y=561.05 with only the
current type lit. Labels, tags and dialogue are duplicated from the registration
copy (`2318:3129`~`3430`) into `kPlantPersonalities`.

#### Edit info (`2555:661`, `2568:1639`)

Four fields on the standard 110 px label pitch: labels at x=45 y=145 / 255 / 365
/ 475 in `kOrangeMain`, `RoundedInputField` at x=34 w=334 h=51.

Dates open `PlantDatePickerSheet`, and the sheet is **orange, not white**
(`2568:1686`: `#FFB52A`, 402 x 325 at y=549, top corners 35). Wheel text is
white at 80% / 16 Medium; the selected row sits on a `rgba(255,197,136,0.42)`
pill (`2568:1706`, 399.954 x 39.686, radius 20) in white 18 SemiBold. The button
(`2568:1711`) inverts: white background, `#FFB52A` label.

Two things must not be added inside this sheet, or it grows past 325 and the
button rides up over the wheels on a real device: `showModalBottomSheet` is
called with `useSafeArea: false`, and the button uses `PrimaryButton` directly
rather than `PlantDetailBottomAction` (which wraps a `SafeArea`). The sheet is
already flush to the bottom edge, so the 34 px inset is not its to pay. There is
a regression test at `FakeViewPadding(top: 62, bottom: 34)` for exactly this.

#### Appearance (`2568:1764`, `2568:1814`)

Full screen, not a bottom sheet. A 443 px white circle at (-25, 576) carries an
arc of **five** 60 px swatches (74 px with the selected ring, `2568:1799`, black
15% at width 4) whose colours come straight from the export: `#BAEEDC`,
`#E0B2FF`, `#FF9B9B`, `#FFDC9C`, `#FFCADC`. The bottom-centre position is **not**
a sixth swatch — it is the orange check circle (`2568:1811`, `#FFB222` r19,
drawn 46 x 46 with its shadow) at (182, 760), which **is** the apply button.
There is no `적용하기` bar, and the old nine-swatch `Wrap` sheet is deleted.

The `컬러` / `헤어` tab underline (`2568:1808`) is a **curve**, not a straight
rule: a `#D9D9D9` arc across 115 x 11 with the active half overpainted in
`#FFB52A`, round caps, 3 px. The exported SVG only has the left half filled, so
`_TabIndicatorPainter` redraws both curves and mirrors the canvas for the hair
tab.

#### API gaps (`TODO(design)`)

`PlantManagementRepository` only has `updateNickname` and `updateAppearance`.
Marked in code:

- `장소(별명)`, `마지막 물 준 날`, `분갈이 한 날` are drawn and hold local state
  but never reach the server (`plant_edit_info_screen.dart`).
- Personality has no `PATCH`, so that screen's `수정하기` stays disabled
  (`plant_detail_screen.dart`).
- The hair tab has no item PNGs and no agreed `hair_id` values, so it shows a
  placeholder line (`plant_edit_appearance_screen.dart`).
- Character art is still one shared `PlantCharacterArt`; there is no asset keyed
  by `personalityType` / `colorId`.

### Device safe area vs. the mock's status bar

The mocks are drawn on a 402 x 874 frame with a **46 px status bar**. Real
devices differ — iPhone 17 Pro reports 62 top / 34 bottom — and the two ends
need opposite treatment.

**Top: let `SafeArea` win.** On that device every screen starts 16 px lower than
the mock's absolute y. That is correct behaviour, confirmed 2026-09-05: pinning
the mock's coordinate would put content under a taller notch. Goldens run with
no status bar at all, so they compare against `mock y - 46`.

**Bottom: give no padding of your own.** The mock leaves 33 px under the bottom
button; the device's bottom inset (34 px) already fills that. Constants that
also subtracted their own gap were double-counting, and the button floated:

| constant | was | now |
|---|---|---|
| `authBottomActionPadding` | 79 | 0 |
| `signupCompleteBottomGap` | 33 | 0 |
| `myPageBottomGap` | 33 + 46 | 0 |

The old values were read off goldens, where there is no bottom inset to collide
with — the error is invisible until the app runs on a device. `myPageBottomGap`
was the worst of the three: its `+46` pushed the logout button 80 px up.

The bottom **navigation bar** is the opposite case: it must reach the very edge
(mock y 795-874). Inside `SafeArea` it floats 34 px up and leaves a blank strip
under it, so home sets `bottom: false` and pins the bar with a `Positioned` in
the outer `Stack`. Diary already placed it that way.

`test/device_safe_area_test.dart` fakes the device insets and asserts the bottom
button lands on the mock's y across all five screens that have one, plus the
nav bar reaching the bottom edge. Screen-level
coordinate tests that run without insets must **not** check a bottom button's y —
it is meaningless there.

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

- Species search and plant creation use the backend API. Until the home API is connected,
  the registration route passes the frozen server request snapshot directly to the home screen.
- The current Figma flow does not collect pot type, placement, hair, or accessory. Registration
  sends the backend's explicit fallback values `OTHER`, `OTHER`, `NONE`, and `NONE` until those
  controls and assets exist.

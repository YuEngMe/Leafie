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

Built from the Figma nodes, not yet wired into a screen — no my-page screen exists.

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

### Icons: assets vs. code

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
- The eye toggle only shows once a password field has content (`2395:40`).
- Password reset drives its send button label from the step —
  발송 / 재발송 / 완료 (`2395:52`, `2395:49`, `2395:51`) — and puts the
  countdown inside the email field rather than in the notice line.
- `2395:44` carries an app bar; its title comes from the entry path because the
  mock says "카카오톡 로그인" while the screen also serves email signup.

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

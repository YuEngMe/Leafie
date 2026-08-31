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
- Login node `2353:3` uses a 122 px wordmark lockup with a larger `0.98` mark ratio, 11 px inset links, asymmetric divider/social insets, and a 5 px password-to-link gap. Its link/button/divider weights are 500/500/600. These anchors live in `AppLayout` and the login text styles.

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

### Figma vector glyphs

`lib/widgets/figma_glyphs.dart` reproduces designer-exported vectors as
`CustomPainter` polylines, keeping the original Figma coordinates as constants.

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
- `FigmaSearchIcon`: `2318:3726`, a `#BFBFBF` circle and handle both rotated
  -35.36 degrees.
- `FigmaCameraIcon`: `2318:3742`, one `#FFB52A` path whose lens is punched out
  with an even-odd ring.

### Character registration

- `RegisterProgressBar`: `2307:2015`, five waves, active `#FFB52A` and inactive
  `#D9D9D9` (`kProgressInactive` — not the disabled-button gray).
- Species search dropdown: `2318:3750`. The result card (`2318:3721`) sits flush
  under the input pill with only its bottom corners rounded; rows are 36 px apart
  with a 33 px highlight band.
- Personality step: dots `2318:3925` turn `kOrangeMain` when active; tag chips
  `2318:3966` use `kTagOrange` (`#FF9F6D`) with a 0.827 px border, and that
  screen's title alone uses `kPersonalityTitle` (`#2E2E2E`).

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
- `FigmaMoistureIcon`: `2346:2541`. Figma exports both shapes as `#D9D9D9`
  placeholders; the rendered mint and yellow are kept as constants on the widget.

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

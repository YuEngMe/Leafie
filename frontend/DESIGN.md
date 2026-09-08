# Leafie Flutter Design Contract

## 1. Product direction

Leafie is a calm, friendly plant companion. The mobile UI uses a warm off-white/green atmosphere, generous spacing, and one clear primary action per screen.

## 2. Sources

- Figma file `KhDBMZrMNV5hisim2Kvr4x`, especially home frame `750:168` and registration frame `750:816`.
- Existing Flutter primitives in `lib/theme/app_colors.dart`, `lib/widgets/primary_button.dart`, and `lib/widgets/app_text_field.dart`.

## 3. Color tokens

- `kAppBackground`: `#F5FAF0`, page background.
- `kButtonGreen`: `#4E7F46`, primary actions and active progress.
- `kLabelGreen`: `#315E2D`, emphasized labels and plant icon.
- `kBorderGreen`: `#D6E2D4`, quiet surfaces and borders.
- Material neutral colors are allowed for body copy and disabled/placeholder states.

## 4. Typography and spacing

- Pretendard is the only product font.
- Page title: 22/600. Section title: 20/700. Body: 15-16/400-600.
- Layout follows a 4 px grid. Screen horizontal padding is 32 px; major vertical gaps are 24-40 px.

## 5. Reusable primitives

- `PrimaryButton`: full-width, 50 px high, green pill, white 18/600 label.
- `AppTextField`: labeled form field with green focus treatment.
- Home empty state: leaf icon, one headline, one supporting paragraph, and one primary registration action.

## 6. Interaction states

- Every actionable control uses a Material button or tappable semantic widget.
- Authenticated home remains below the registration wizard so system back returns home.
- Completing registration replaces the wizard stack with home.

## 7. Accessibility

- Text and controls must remain readable at platform text scaling.
- Primary controls have at least a 48 px touch target.
- Color is not the only carrier of state; labels accompany icons and progress.

## 8. Accepted MVP debt

- The home character artwork and full five-tab shell are deferred until their feature modules exist.
- Plant creation is still a local dummy response, so the just-registered plant name is held only for the current route.

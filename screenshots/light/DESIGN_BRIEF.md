# SetLog — Design Brief (Light Mode)

> Companion document to the light-mode screenshots in this folder. Use this
> to seed Claude Design with the intent, tokens, and screen taxonomy so it
> can reason about layouts beyond what is visually inferable.

---

## 1. App at a glance

- **Name:** SetLog
- **Platform:** iOS native (SwiftUI), iPhone-first, portrait only
- **Category:** Strength-training workout logger
- **Audience:** Gym-goers tracking sets / reps / weight / RPE per session
- **Tone:** Focused, no-nonsense, gym-floor friendly. High contrast, tap targets sized for sweaty / one-handed use.
- **Signature accent:** Orange `#FF7314` — used for the active/in-progress state, primary tabs, and brand highlights. The rest of the UI is near-neutral so orange always reads as "this is live / actionable".

## 2. Information architecture

Three root tabs (bottom tab bar):

1. **Home / Dashboard** — today's plan, quick-start, recent activity
2. **History** — calendar + list of past workouts, drill into detail
3. **Profile** — user stats, settings, theme, data

Cross-cutting flows:

- **Templates** (reachable from Home) → **Template Detail** → **Start Workout**
- **Current Workout** (modal-ish full-screen) → **Add Exercise** → **Workout Summary**

## 3. Screen ↔ file map

| File | Screen | Purpose / key elements |
| --- | --- | --- |
| `01-home-dashboard.png` | Home — empty state | Greeting, weekly streak, "Start workout" primary CTA, templates shortcut |
| `01b-home-with-completed.png` | Home — populated | Same layout, with today's completed workout card visible |
| `02-templates.png` | Templates list | Grouped templates (e.g. Push / Pull / Legs), per-card exercise count + last-used |
| `03-template-detail.png` | Template detail | Read-only exercise list with target sets/reps; "Start" CTA pinned bottom |
| `04-current-workout-empty.png` / `04a-current-workout-empty.png` | Live workout — no exercises yet | "Add exercise" CTA, timer chip, finish button disabled |
| `04-current-workout.png` | Live workout — collapsed cards | Stack of exercise cards, each summarising sets done |
| `04-current-workout-expanded.png` | Live workout — expanded card | Set rows: weight × reps × RPE, complete-set checkbox, rest timer |
| `04-current-workout-running.png` | Live workout — rest timer running | Orange running ring/pill, lock state on rest |
| `04d-workout-summary.png` | Post-workout summary | Total volume, duration, PRs, save/discard |
| `05-add-exercise.png` | Exercise picker | Searchable list, category filters, "+ Custom" entry |
| `05b-add-exercise-selected.png` | Exercise picker — multi-select state | Selected pills shown, confirm-add button |
| `05a-add-exercise-custom.png` / `05a-add-custom-exercise.png` | Custom exercise creation | Name, muscle group, equipment, save |
| `08-history-calendar.png` | History — calendar view | Month grid with dots for completed days |
| `09-history-list.png` | History — list view | Reverse-chrono cards: title, duration, exercises summary |
| `10-history-detail.png` | History — workout detail (top) | Title, date, duration, volume hero stats |
| `10b-history-detail-scrolled.png` | History — workout detail (scrolled) | Per-exercise breakdown with set table |
| `13-profile.png` | Profile (top) | Avatar, name, weekly stats, settings rows |
| `13b-profile-scrolled.png` | Profile (scrolled) | Theme, units, data export, about |

## 4. Design tokens (light mode)

These are the live values from `SetLog/AppTheme.swift`. Treat them as the
source of truth — they are what ship in the build, not approximations.

### 4.1 Color

| Role | Token | Hex |
| --- | --- | --- |
| Primary accent (active / in-progress / brand) | `orange` | `#FF7314` |
| Accent gradient end | `orangeDeep` | `#FF6D00` |
| Accent tint (chips, soft fills) | `orangeTint` | `#FFE8D6` |
| Accent @ 18% (translucent overlays) | `orange12` | `#FF7314` α 0.18 |
| Text — primary | `fg1` | `#1A1F2E` |
| Text — secondary | `fg2` | `#4A515F` |
| Text — tertiary / placeholder | `fg3` | `#8A8F9A` |
| Divider / disabled | `fg4` | `#C5C9D0` |
| Card surface | `bgCard` | `#FFFFFF` |
| Page background | `bgPage` | `#F2F2F7` |
| Subtle fill (input bg, soft chips) | `fillSubtle` | `#F7F7FB` |
| Medium fill (pressed / selected) | `fillMedium` | `#EBEBF0` |
| Confirm / set-completed | `confirm` | `#34C759` |
| Destructive | `danger` | `#FF3B30` |
| Primary CTA fill (Add / Apply / Copy) | `ctaFill` | `#1A1F2E` (dark navy) |

**RPE scale (Rate of Perceived Exertion)** — used on set rows and history:

| RPE | Token | Hex | Meaning |
| --- | --- | --- | --- |
| 6 | `fg2` | `#4A515F` | Warm-up / easy |
| 7 | `confirm` | `#34C759` | ~3 reps in reserve |
| 8 | `rpeAmber` | `#F2B01C` | ~2 RIR |
| 9 | `orange` | `#FF7314` | ~1 RIR |
| 10 | `rpeRed` | `#E53E3E` | Failure |

> Important: orange is **reserved** for active/in-progress state and RPE 9.
> The primary CTA is **dark navy** (`ctaFill`), not orange — orange would
> compete with the live-workout signal.

### 4.2 Typography

SF Pro (system). Approximate roles:

- **Hero stat** — 34pt, semibold, `fg1`
- **Screen title** — 28pt, bold, `fg1`
- **Section header** — 17pt, semibold, `fg1`
- **Body / row title** — 16pt, regular, `fg1`
- **Secondary / metadata** — 14pt, regular, `fg2`
- **Caption / unit** — 12pt, medium, `fg3`
- Numerals in set rows are **monospaced digits** (`.monospacedDigit()`) so columns align.

### 4.3 Spacing & shape

- Page horizontal padding: **16pt**
- Card padding: **16pt** all sides
- Card corner radius: **16pt** (cards), **12pt** (chips/buttons), **8pt** (inputs)
- Card shadow: very light — y=2, blur=8, black α 0.04. Borders preferred over shadows.
- Tap targets: minimum 44×44pt
- Section spacing: 24pt between cards / sections
- Tab bar: standard iOS height, icons + labels, active = `orange`

## 5. Recurring components

- **Stat card** — large numeric value + small caption underneath, optional delta chip on the right.
- **Exercise card (live workout)** — header row (name + menu), expandable set table, footer with "Add set" ghost button. Active card has a subtle `orangeTint` background.
- **Set row** — `[done checkbox] [set #] [weight] [× reps] [RPE pill] [rest icon]`. Completed rows: checkbox filled `confirm`, text dims to `fg2`.
- **Rest timer pill** — orange ring counting down, MM:SS centered. Pulses when <5s.
- **Primary CTA button** — full-width, 52pt tall, `ctaFill` background, white text, 12pt radius. Used for "Start workout", "Finish", "Save".
- **Secondary CTA** — same shape, `fillSubtle` background, `fg1` text.
- **Destructive action** — text-only `danger` color, never a filled red button (kept rare).
- **Numeric keyboard** — custom in-app number pad for weight/reps (see `NumericKeyboard.swift`); slides up over the workout view.
- **Calendar dots** — single orange dot per completed day; no count, no streak coloring.

## 6. Interaction & motion notes (not visible in stills)

- Tab switching: cross-fade, no slide.
- Live-workout entry: full-screen cover from bottom.
- Set completion: checkbox scale-bounce + haptic; set row animates to "done" style.
- Rest timer auto-starts on set completion; user can lock/unlock the timer.
- Pull-to-refresh on History list.
- Long-press on a history workout card → context menu (duplicate, delete).

## 7. What I want from Claude Design

(Edit this section before uploading — it steers the model.)

- [ ] Re-create each screen as Figma-ready frames using the tokens in §4.
- [ ] Produce a component library: stat card, exercise card, set row, rest timer, primary/secondary CTA, tab bar, calendar cell.
- [ ] Build a **dark-mode** counterpart using the dark hexes in `AppTheme.swift` (already defined — see source for `dynamic(light:dark:)` pairs).
- [ ] Suggest layout improvements only where the current screen has clear hierarchy / accessibility issues; otherwise mirror the existing layout faithfully.
- [ ] Keep orange strictly for **in-progress / active / RPE 9**. Do not promote it to the primary CTA color.

## 8. Out of scope

- Android / web layouts
- Marketing site
- Onboarding flow (not yet designed)
- Social / sharing features

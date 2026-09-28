# Family App — Release 2a: Chores, and a new look and feel

Date: 2026-09-28. Status: draft for Firas's review.
Builds on: `2026-09-27-family-app-shopping-design.md` (Release 1). Everything there still applies unless this spec changes it.

## 1. Why

Firas wants the family's day in one place: chores first, then a shared family calendar shown on an old wall-mounted tablet, then star rewards. Release 2 is split into three sub-projects, each with its own spec, plan and build:

1. **2a (this spec):** chores, plus a new look and feel across the whole app, so chores are built in the new style from day one.
2. **2b:** family calendar (day, week and month views; events and chores together), wall mode on a landscape tablet with the shared lists, and Google Calendar.
3. **2c:** star rewards built on chores (star value per chore, star goals, redeeming, a bonus for chores done on time).

Out of scope for all of Release 2: meal planning, AI import, server-sent notifications.

### Success looks like

- Parents set up each person's chores once, with repeats and an end date, and don't touch them again.
- Kids open the app (or look at the tablet), see their own chores in their colour, tick them off and get a small celebration.
- A phone reminds its person at the chore's time.
- The app feels like one product: shopping and chores share one style, in light and dark.

## 2. Decisions (all confirmed by Firas on 2026-09-28)

| Topic | Decision |
|---|---|
| Kinds of chores | Mostly fixed per person, plus some "anyone" chores |
| Repeats | One-time, or repeating every N days / N weeks on chosen weekdays / N months on a day of the month; end never or on a date |
| Missed chores | Repeating chores reset at the end of their day; one-time and "anyone" chores stay, marked Late, until done |
| Permissions | Parents create, edit and delete any chore and can tick or untick anyone's; children can add chores for themselves and tick their own and "anyone" chores |
| Storage approach | A chore "rule" plus one "done" record per chore per day (no server, works offline) |
| Time of day | Optional time on a chore; used for sorting, reminders, and later on-time star bonuses |
| Reminders | Scheduled on each phone (no server, free); limitation accepted |
| Photos | Google profile photo, falling back to a coloured letter; no uploads |
| Colours | Each member has a colour used everywhere (avatar, chores, later calendar events) |
| App structure | Bottom bar: Today · Chores · Lists · Family; shopping history moves into Lists |
| Themes | Light and dark; follows the phone by default, with a manual override |
| Visual style | "Mix": bright and playful on Chores and the tablet; soft and calm on Today, Lists and Family |
| Tablet layout | Landscape; one column per member side by side; each column scrolls on its own |

## 3. Data model additions (Cloud Firestore)

```
families/{familyId}
  members/{uid}
      + color       int, one of the 8 palette indexes (0–7)
      + photoUrl    string or null (Google profile photo, written by the member)

  chores/{choreId}
      title         string, 1–80 characters after trimming
      icon          string or null (a single emoji; shown big on kid tiles)
      assignee      member uid, or null = "anyone"
      time          "HH:mm" or null
      repeat        "once" | "daily" | "weekly" | "monthly"
      every         int ≥ 1 (1 for "once")
      weekdays      list of ints 1–7 (1 = Monday), required and non-empty for "weekly", else empty
      monthDay      int 1–31 for "monthly", else null
      startDate     "YYYY-MM-DD" (for "once", the chore's date)
      endDate       "YYYY-MM-DD" or null (never ends)
      createdBy, createdAt

  choreDone/{choreId}_{YYYY-MM-DD}
      choreId, date "YYYY-MM-DD",
      choreTitle, assignee      (own copies, so history survives edits and deletes)
      doneBy, doneByName, doneAt
      dayNumber     int, days since 1970-01-01 for `date` (lets the rules check "today or yesterday")
```

Rules of the model:
- A chore belongs to calendar days, not moments. Dates are local-date strings. The family is assumed to share one timezone.
- The done record's ID is the chore ID plus the date, so two phones ticking the same chore produce one record.
- Monthly on day 29–31 falls on the last day of shorter months.
- Editing a chore's rule changes future days only in effect: past done records are untouched and keep their own copied title.
- Deleting a chore deletes the chore document only; its done records stay as history (and for 2c stars).
- A child's own chore is a chore with `createdBy == assignee == child`.
- Member colour is assigned at create or join as the lowest palette index not used by another member (wrapping if more than 8 members). The existing member documents without a colour get one the first time a parent opens the Family screen after the update.

## 4. Core logic (pure Dart, `lib/core`, fully unit-tested)

- `occursOn(Chore, date) → bool`: applies startDate, endDate, repeat, every, weekdays and monthDay. "Every N weeks" counts weeks from the week containing startDate (weeks start on the family's week start, default Sunday).
- `choresForDay(chores, done, date, today) → DayView`: for each member, the chores occurring that day with done or not-done status, sorted: timed chores by time first, then untimed by title. Also an "Anyone" group.
- `lateChores(chores, done, today) → list`: one-time and "anyone" chores whose date is before today and that have no done record. A repeating "anyone" chore is late only for its most recent missed occurrence, never a pile of them.
- Progress per member for a day: done count over total.

## 5. Look and feel (applies to the whole app)

- **Design tokens:** one theme file defines colours, corner radii (cards 16, tiles 20), spacing and text styles, for light and dark. Every screen uses them, with no hard-coded colours.
- **Person palette:** 8 colours chosen to stay readable in both themes and distinguishable from each other; each has a light tint, a strong fill and a text-on-fill colour. Shopping keeps its coral (To buy) and teal (Recently used) tile meanings.
- **Font:** one bundled font family that covers Arabic and Latin well (for example IBM Plex Sans Arabic). The exact choice is made in the plan after checking licence and size.
- **Two moods from one system:** Chores and the tablet use tinted cards in the person's colour, big emoji tiles and rounder shapes; Today, Lists and Family use neutral cards and colour only for people, done states and warnings.
- **Shared behaviours:** ticking, Undo, edit sheets and confirm dialogs look and work the same for chores and shopping. Empty states are friendly ("No chores today 🎉") with an action where one makes sense.
- **Celebration:** completing a chore gives a short emoji burst and a light vibration; finishing all of a person's chores for the day gives a bigger one. Both respect the phone's "reduce motion" setting.
- **Accessibility:** tap targets of at least 48 dp, text scaling without overflow (tested at 1.3×), colour contrast checked for text on every palette colour, and full right-to-left layout in Arabic.

## 6. Screens

**Bottom bar:** Today · Chores · Lists · Family. The calendar adds a tab in 2b.

**Today (new home):**
- Header: date and each member's avatar with a progress ring and done count.
- Late: red strip of late chores, if any.
- Your chores: today's chores for the signed-in person, with tick buttons.
- Shopping: a summary card per list with items to buy, opening that list.

**Chores:**
- Top: day switcher (previous, Today, next; tapping the date opens a date picker) and an Everyone / Me toggle. Children open on Me, parents on Everyone.
- Phone (portrait): one section per member, stacked, then Anyone. Each section shows the avatar (photo or letter), name and done count.
- Tablet (landscape, width ≥ 840 dp): one column per member side by side, plus an Anyone column; each column scrolls on its own; columns share the screen evenly with a minimum width, and scroll sideways only if the family is too large to fit.
- Cards: title, emoji if set, time, repeat label ("Daily", "Sun–Thu"), tick circle. Done cards fill with the person's colour. Members can be marked "picture tiles" on the Family screen, which shows their chores as big emoji tiles.
- Ticking: tap to tick or untick. On an "anyone" chore, a parent picks who did it; a child is recorded as themselves.
- Past days: children see them read-only; parents can correct them.
- Add (+) and edit (long-press) open the chore sheet.

**Chore sheet:** title; emoji (optional); who (member chips plus Anyone; children see only themselves); time (optional); repeat (Once, Daily, Weekly, Monthly), with "every N", weekday chips for Weekly, day-of-month for Monthly; start date; end (Never or a date); reminder on or off; Delete with confirm (parents, or a child for their own chore).

**Lists:** as Release 1, restyled; a History button in the app bar opens the purchase history.

**Family:** as Release 1, restyled, plus a colour dot per member (parents tap to change), a "picture tiles" switch per child, the theme choice (System, Light, Dark) and, for parents, "Remind me about everyone's chores".

## 7. Reminders

- Scheduled on the phone with local notifications for chores that have a time and the reminder switched on.
- Each phone schedules its own person's chores; a parent with "Remind me about everyone's chores" also gets everyone's.
- Schedules are rebuilt whenever the chores or done records change while the app runs, and when the app starts; ticking a chore cancels that day's reminder.
- Only the next 7 days are scheduled, which stays inside Android's limits.
- Known limitation (accepted): a chore added on another phone gets its reminder only after this phone's app has opened and synced.
- The notification permission is requested the first time a reminder is switched on, not at app start.

## 8. Security rules

- `chores`: members read. Create: a parent (any assignee), or a child with `assignee == createdBy == self`. Update and delete: a parent, or a child for a chore with `createdBy == assignee == self` that stays assigned to themselves. Title length and field types validated.
- `choreDone`: members read. The document ID must equal `choreId + "_" + date`. Create: a parent for any member; a child only with `doneBy == self`, for a chore assigned to them or to anyone, and only when `dayNumber` is today or yesterday relative to `request.time` (one day of grace for offline ticks). Delete: a parent; a child only their own record within the same window. No updates.
- `members`: a parent may change `color`; a member may change only their own `photoUrl`. Existing role rules unchanged.
- Every rule gets emulator tests, including the negative cases (a child can't tick someone else's chore, can't edit a parent's chore, can't tick three days ago).

## 9. Error handling and edge cases

- Ticking and editing are offline writes through `fireAndForget`, never awaited, as in Release 1.
- A chore deleted on another phone while visible disappears; a done record whose chore is gone still shows in past days using its copied title.
- An assignee who leaves the family: their chores stay but show under "Former member" to parents, who can reassign or delete them.
- End date before start date, "weekly" with no weekdays, and blank titles are blocked in the sheet with an inline message.
- Clock or timezone surprises: the date shown is always the phone's local date.

## 10. Testing

- Unit tests for `occursOn` (each repeat type, every N, end dates, month-end days, weekday edges), `choresForDay`, `lateChores` and progress.
- Widget tests for Today, the Chores screen (portrait sections; landscape columns at 1280×800 with independent scrolling), the chore sheet validation, ticking and unticking, and parent vs child permissions in the UI.
- Layout tests at 360×740 and 320×640 with text scale 1.3, English and Arabic, with no overflow.
- Rules tests in the emulator for all of section 8.
- Reminder scheduling tested through a fake scheduler (which reminders for which person over the next 7 days).
- Manual device checklist: reminders firing, notification permission prompt, tablet landscape view, theme switching.

## 11. Build order inside 2a

1. Design tokens, fonts, light and dark themes, theme switch.
2. Restyle existing screens; new navigation; Today screen (shopping part only at first); history moves into Lists.
3. Member colours and Google photos.
4. Chore model, repeat logic and rules (with tests).
5. Chores screen (phone and tablet) and chore sheet.
6. Ticking, late chores and celebration; Today gets its chores parts.
7. Reminders.
8. Release build and device checklist.

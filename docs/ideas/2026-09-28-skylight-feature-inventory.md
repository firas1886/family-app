# Skylight Calendar: feature inventory

Source: "Get to Know Skylight Calendar: The All-In-One Family Organization Hub" (YouTube, 5:35), https://youtu.be/yJ6LgSU1cuE. Recorded 2026-09-28 from the video's full narration; timestamps are in the video.

Status column: **Have** = already in Family App Release 1; **Partial** = related piece exists; **New** = not built.

## 1. Calendar (0:38–1:13)

| # | Feature | Detail from the video | Family App |
|---|---|---|---|
| 1.1 | Shared family calendar | "See all your family events together all in one place." Week view with colour blocks per event (visible at 0:17). | New |
| 1.2 | Sync external calendars | Google, Apple, Outlook, Cozi "and more"; work, school, extracurriculars. | New |
| 1.3 | Native calendar without any external account | "Your Skylight calendar can be your one-stop shop"; add events from the phone app or the screen. | New |
| 1.4 | Colour-code each calendar / person | "Color code each of your individual calendars." | New |
| 1.5 | Weather on events | An event with an address shows the weather at that place on that day (2:54). | New |

## 2. Chore chart (1:27–1:56)

| # | Feature | Detail | Family App |
|---|---|---|---|
| 2.1 | Assign chores per family member | Daily and weekly tasks. | New (Chores already parked for Release 2) |
| 2.2 | Kids check off their own chores | Builds routines and autonomy ("brush their teeth without me reminding them"). | New; child role already exists |
| 2.3 | Celebration on completion | "The screen explodes with emojis when they finish." | New |

## 3. Lists (1:56–2:22)

| # | Feature | Detail | Family App |
|---|---|---|---|
| 3.1 | Multiple lists: to-dos and groceries | "From to-dos to groceries … all your most important lists." | Partial: shopping lists only, no to-do lists |
| 3.2 | Synced to every family member's phone | "My husband and I can access and edit the same list." | Have (live sync, offline) |

## 4. Home screen / display (2:22–2:58)

| # | Feature | Detail | Family App |
|---|---|---|---|
| 4.1 | Wall touchscreen, usable by all ages | Dedicated device, 10", 15", 27". | New. Personal version: a tablet "wall mode" of the app |
| 4.2 | Screen customisation | Display name, how many days are shown. | New |
| 4.3 | Daily weather | From a zip code. | New |

## 5. Paid tier ("Calendar Plus", 2:58–5:15)

| # | Feature | Detail | Family App |
|---|---|---|---|
| 5.1 | AI assistant "Sidekick": import from photo / PDF / email | Photograph a school flyer, or forward school emails to a personal Skylight address; events, recipes and lists "appear in the right place". | New (needs an AI service) |
| 5.2 | AI meal generation | Inputs: dietary restrictions, preferences (kid-friendly, cold lunchbox), number of people. Output: recipe + grocery list + meal assigned to a day. | New (needs an AI service); grocery list would feed the existing shopping list |
| 5.3 | AI project ideas | e.g. Play-Doh, slime recipes for kids. | New (low priority) |
| 5.4 | Weekly meal planner | "Map out your whole week." | New |
| 5.5 | Recipe bank | Upload, generate and catalogue favourite recipes to reuse each week. | New |
| 5.6 | Rewards with stars | Parents set rewards with a star goal; each chore has a star value; kids earn stars and redeem (e.g. "a trip to the zoo"). | New (depends on 2) |
| 5.7 | Photo screensaver | Upload thousands of photos; they rotate when the screen is idle; e.g. photos of kids' art as a home gallery. | New |

## Notes for a personal version

- **Already strong:** shared lists with live sync and offline, parent and child roles, Arabic/English. These are the base the rest builds on.
- **Natural next modules, in dependency order:** chores (2) → rewards (5.6) → family calendar (1.1, 1.3, 1.4) → meal planner and recipe bank (5.4, 5.5), feeding the shopping list.
- **External services needed:** calendar sync (1.2) needs Google/Microsoft sign-in scopes; weather (1.5, 4.3) needs a weather API; the AI features (5.1–5.3) need an AI API and cost money per use.
- **Hardware:** Skylight sells a screen. A personal version can use any Android tablet with a kiosk/"wall mode" screen (4.1) and the photo screensaver (5.7).
- This is new scope beyond the approved Release 1 spec. It needs its own spec and plan before any building.

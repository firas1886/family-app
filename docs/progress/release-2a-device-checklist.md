# Family 1.1.0: device checklist

For Firas. Release 2a (chores and the new look), 2026-09-30.

Do the steps in order and compare what happens with **You should see**. If something doesn't match, write down the step number and what you saw (a screenshot helps), and tell Claude. Allow about an hour, plus some waiting for reminders.

In these steps, "your phone" is a parent's phone and "Sara" is the child. Use your own child's name and phone.

## Before you begin

You need two phones: yours (a parent) and a child's phone (Sara). The tablet is optional: if you don't use it, skip the tablet steps.

- **A. Check that Google sign-in will accept the test app (probably already done).** The test app is signed with this PC's own test key. Google sign-in only accepts it if that key's two fingerprints (a SHA-1 and a SHA-256) are registered in Firebase. You added them during Release 1, so this is just a check: Firebase console → project **familia-a1b9f** → gear icon → **Project settings** → **Your apps** → **com.firas.familia** → **SHA certificate fingerprints**. The SHA-1 and SHA-256 you added from this PC should be listed. If they're missing, follow `docs/SETUP.md`, "SHA fingerprints", items 2 and 3, then tell Claude before you install, because the test app then has to be built again.
- **B. Publish the new rules.** Firebase console → **Firestore Database** → **Rules** → replace everything with the contents of `firestore.rules` from the repository folder → **Publish**. Chores can't be saved until you do this.
- **C. Uninstall the old test app** on each phone (and the tablet): long-press the Family icon → **App info** → **Uninstall**. Nothing is lost, because your family's data is kept in Firebase.
- **D. Install the new test app.** On this PC the file is `D:\ClaudeProjects\Family App\Family-test.apk`. Send it to each phone (for example over WhatsApp to yourself, or through Google Drive), tap it on the phone, then tap **Install**. If Android asks you to allow **Install unknown apps** for WhatsApp or Drive, allow it. If Google Play Protect warns about an unknown app, tap **More details → Install anyway** (it's your own test app). To check you have the right one: phone **Settings → Apps → Family** shows version **1.1.0**.
- **E. Sign in.** Open Family on each device and sign in with Google. Each person uses their own account, and the tablet uses yours. You should go straight into your family. If sign-in fails, go back to A.

## Look and feel

1. **Nothing lost.** Open Family on your phone.
   You should see: you're still in your family, your shopping lists are under **Lists**, and the bar at the bottom reads **Today · Chores · Lists · Family**. The **History** button at the top of Lists opens your past purchases.
2. **Light and dark.** Family tab → **Theme** → **Dark**, then look at every tab. Then **Light**. Then **System**, and switch your phone's dark mode on and off from the quick-settings panel (swipe down from the top of the screen).
   You should see: every tab turns dark or light, all text is easy to read, and on **System** the app follows the phone.
3. **Colours and photos.** On the Family tab, tap the coloured dot next to Sara and pick another colour.
   You should see: people with a Google photo show it, and others show a coloured letter. Sara's picture and dot change to the new colour on both phones within a few seconds. Her chores use this colour too, from step 4 on.

## Today

4. **Give Today something to show.** On your phone, open **Chores** and tap the round **+** button. Type the title **Make bed**. Under **Who**, tap **Sara**. Leave **Repeat** on **Daily**. Tap **Starts** and pick the date 3 days ago, then tap **Save**. Add two more chores the same way: **Tidy room** for Sara, and **Feed the cat** for you.
   You should see: the three chores appear under Sara and under you, and Sara's are in her colour.
5. **Today at a glance.** Open **Today** on your phone.
   You should see, from top to bottom:
   - today's date;
   - a row of round pictures, one per family member (you first), each with **✓ done/total** under it (for example **✓ 0/2** under Sara). A coloured ring around each picture fills up as that person's chores get done;
   - **Your chores**: only your own chores for today (Feed the cat), each with a tick circle;
   - **Shopping**: one card per shopping list, saying how many items there are to buy (or **Nothing to buy**). Tap a card and that list opens. Then go back.
6. **Ticking on Today.** Still on Today, tap the tick circle on **Feed the cat**.
   You should see: an emoji burst, your ring fills, and your count shows **✓ 1/1**. **All done for today! 🎉** appears above your chores. On Sara's phone, your count also shows **✓ 1/1** within a few seconds.
7. **Sara's Today.** Open **Today** on Sara's phone.
   You should see: **Your chores** shows Sara's two chores (Make bed, Tidy room), not yours. The row of pictures shows everyone.
8. **Late chores.** On your phone, open **Chores** and tap **+**. Type the title **Return library book**, set **Who** to **Sara** and **Repeat** to **Once**, tap **Starts** and pick **yesterday**, then tap **Save**. Don't tick it.
   You should see:
   - **on Sara's phone**, **Today** shows a red **Late** strip above **Your chores** with that chore, and under it "Sara · Late since" and yesterday's date;
   - **on your phone**, Today doesn't show it, because Today lists only your own late chores. Look under **Chores → Everyone** instead: the same red strip is at the top.
   Then tick it on Sara's phone. The strip disappears on both phones.

## Chores (phone)

9. **What each person sees first.** Open **Chores** on your phone, then on Sara's phone.
   You should see: on your phone, **Everyone** is selected at the top. There's one section per person (you first, each with picture, name and **✓ done/total**), then **Anyone**. On Sara's phone, **Me** is selected and she sees only her own chores. When she taps **Everyone**, she sees everyone's chores.
   Each chore card shows its title, its emoji and time if it has them, how often it repeats (for example "Daily") and a tick circle. The card is in the person's colour.
10. **Moving between days.** On your phone, in Chores, tap ▶ and ◀ on either side of the date at the top. Then tap the date itself.
    You should see: the arrows move one day at a time, and the middle shows the date (it says **Today** on today). Tapping the date opens a calendar. Pick a day next week and tap **OK**, and that day's chores show. To come back to today, use the arrows, or open the calendar and pick today (it has a circle around it).
11. **A school-days chore that ends.** On your phone, tap **+**. Type the title **Pack school bag**, set the emoji to 🎒, **Who** to **Sara** and **Repeat** to **Weekly**. Under **On these days**, make sure exactly **Sun, Mon, Tue, Wed, Thu** are selected. Switch **Never ends** off, tap **Ends on** and pick a date two weeks from today, then tap **Save**.
    You should see: on a Sunday to Thursday, the card says **Sun–Thu · until** and the end date. Use the arrows or the calendar: the chore is on Sundays, but not on Fridays or Saturdays, and not on a Sunday after the end date.
12. **A monthly chore.** On your phone, tap **+**. Type the title **Pocket money**, set the emoji to 💰, **Who** to your own name, **Repeat** to **Monthly** and **Day of the month** to **15**, then tap **Save**. Open the calendar and pick the 15th of next month.
    You should see: the chore is there, labelled **Monthly · day 15**. The 14th and the 16th don't have it.
13. **Editing.** On your phone, **long-press a chore to edit it** (for example **Tidy room**). Change the title to **Tidy bedroom**, then tap **Save**.
    You should see: the **Edit chore** sheet opens with the chore's details. After you save, the card shows the new title on both phones.
14. **Deleting (with a question first).** On your phone, add a chore called **Test chore** for yourself. Long-press it, then tap the red **Delete**. Tap **Cancel** the first time. Then tap **Delete** again and confirm.
    You should see: the app asks "Delete the chore Test chore? Days already done stay in the history." **Cancel** changes nothing. After you confirm, the chore is gone on both phones.
15. **Tick and Undo.** On your phone, tick **Make bed** (Sara's).
    You should see: a message at the bottom, **Make bed done**, with **Undo**. Tap **Undo** within 5 seconds and the chore is unticked. Tick it again and wait: the message goes away after about 5 seconds, and the chore stays ticked.
16. **Celebration.** On your phone, tick Sara's other chores for today one by one. Then turn on **Remove animations** (phone Settings → Accessibility; on Samsung it's under Visibility enhancements). In Family, untick one of Sara's chores and tick it again. Afterwards, turn the setting off again.
    You should see: a small emoji burst and a light buzz on each tick, and a bigger burst when Sara's last chore of the day is ticked. With Remove animations on, there's no burst, but you still feel the buzz.
17. **Picture tiles.** Family tab → switch on **Picture tiles** for Sara. Open **Chores**.
    You should see: Sara's chores as big emoji tiles (also on her phone, and on her Today). Long titles end with "…".
18. **What Sara can and can't do.** On Sara's phone:
    - tap **+**: under **Who** she sees only herself;
    - she can tick her own chores and **Anyone** chores. She can't tick or untick your chores (tap **Everyone** to see them). Long-pressing your chore, or a chore you made for her, does nothing;
    - go back one day with ◀: she can still tick yesterday's chores. Two days back, nothing can be ticked.
    On your phone, you can tick and untick anyone's chore, on any day.
19. **Sara's own chore.** On Sara's phone, tap **+**, type the title **Feed the fish**, set the emoji to 🐟, then tap **Save**. Long-press it, change the title to **Feed the goldfish**, and tap **Save**. Then long-press it again, tap **Delete** and confirm.
    You should see: the chore appears under Sara on both phones, and the new title shows on both. After Delete, it's gone from both.
20. **"Anyone" chores.** On your phone, make a chore **Water plants** with **Who** set to **Anyone**, and tick it.
    You should see: the app asks **Who did it?** Pick Sara, and both phones show it done in Sara's colour. Now untick it on your phone and let Sara tick it on hers. Her phone doesn't ask; it records Sara.
21. **Offline.** Turn on airplane mode on Sara's phone, tick a chore, then turn airplane mode off.
    You should see: the tick shows on her phone straight away, and on your phone within a few seconds of her reconnecting.

## Chores (tablet, landscape)

Skip these if you don't use the tablet.

22. **The board.** Hold the tablet sideways (landscape) and open **Chores** on **Everyone**. If no column is long enough to scroll, first add a few quick daily chores for one person. Scroll down inside that person's column. Then turn the tablet upright.
    You should see: one column per person side by side, plus **Anyone**. Only the column you scrolled moves. When the tablet is upright, the chores stack in sections, as on a phone.
23. **The + button doesn't get in the way.** Hold the tablet sideways again. Scroll the column under the round **+** button (bottom right) to its end, and tick its last chore.
    You should see: the chore ticks, and the **Add chore** sheet doesn't open.

## Reminders

24. **The question about notifications.** On your phone, open **Chores** and tap **+**. Type the title **Brush teeth**, set the emoji to 🪥 and **Who** to **Sara**. Tap **Time**, pick a time 5 minutes from now and tap **OK**. Leave **Repeat** on **Daily**. Switch **Remind me** on (it can only be switched on once the chore has a time), then tap **Save**.
    You should see: when you switch **Remind me** on, Android asks **"Allow Family to send you notifications?"**. Tap **Allow**. Android asks each phone only once. Phones older than Android 13 don't ask at all, which is normal.
25. **The reminder arrives on Sara's phone.** On Sara's phone, open Family once so it picks up the new chore. If Android asks to allow notifications, tap **Allow**. Lock the phone and wait.
    You should see: within about 15 minutes of the chore's time, a notification **Brush teeth**, **Chore for Sara**. Your own phone shows nothing. (If someone taps **Don't allow** here, the app shows a message explaining how to turn notifications on in the phone's settings, and Android doesn't ask again.)
26. **Ticking cancels today's reminder.** Make another chore for Sara, 10 minutes from now, with **Remind me** on. On Sara's phone, open the app and tick it before its time.
    You should see: no notification for that chore.
27. **Reminders survive a restart.** Make a chore for Sara, 10 minutes from now, with **Remind me** on. Open the app on Sara's phone once, then restart her phone and don't open the app again.
    You should see: the reminder still arrives.
28. **"Remind me about everyone's chores".** On your phone, go to the Family tab and switch on **Remind me about everyone's chores**. Make a chore for Sara, 5 minutes from now, with **Remind me** on.
    You should see: this time your phone also shows the reminder (the chore's title and **Chore for Sara**), as well as Sara's phone. Leave this switch on for step 31.
29. **If notifications are off.** On your phone, go to phone **Settings → Apps → Family → Notifications** and switch them **off**. In Family, **long-press a chore to edit it** (one with a time, for example **Brush teeth**). Switch **Remind me** off and on again, then tap **Save**.
    You should see: Android doesn't ask again (it asks each phone only once). Instead, the app straight away shows a message explaining how to turn notifications back on. Follow it to turn them on again.

## Arabic

30. **Right to left.** On your phone, go to the Family tab → **Language** → **العربية**. Look at Today, Chores and Family. If the tablet is signed in with your account, it switches too, because the language is saved with your account.
    You should see: everything is right to left, including the day arrows, the tablet columns and the **+** button (now bottom left).
31. **A long Arabic title, with a reminder.** Still on your phone, in Arabic: open Chores and tap **+**. Type a long Arabic title (a whole sentence, close to the 80 shown by the counter under it, but not over). Set **Who** to **Sara** and the time to 5 minutes from now, and switch **ذكّرني** (Remind me) on. Then tap Save. **ذكّرني بمهام الجميع** (Remind me about everyone's chores) should still be on from step 28.
    You should see: on the card, the title takes at most two lines and ends with "…" instead of spilling over. When the reminder arrives **on your phone**, its text is in Arabic and shows Sara's name as it's saved in the app, for example **مهمة Sara** (names aren't translated). Sara's phone shows the same reminder in the language her app is set to.
32. **Back to English.** Family tab (**العائلة**) → **اللغة** → **English**.
    You should see: everything is back in English, left to right.

## Things to tell us

33. **Your tablet** (skip if you don't use it). Go to Settings → About tablet, and tell Claude the make and model. Then hold it sideways with **Chores** open on **Everyone**.
    Tell us: do all the columns fit, or does the board slide sideways a little? If it slides and that bothers you, say so. The column width can be changed in a later version.
34. **Smallest phone, biggest text.** On the smallest phone, set phone Settings → Display → **Font size** to the largest step. Open **Lists** (the item tiles), **Chores** (with Sara's picture tiles) and the **Family** tab. Afterwards, put the font size back.
    Tell us: is anything hard to read or cut off? On small phones the tiles shrink a little, and the "Remind me about everyone's chores" row may be tall, but its text should fit.
35. **Still open from Release 1.**
    - a. Close and reopen the app a few times. Tell us if it ever gets stuck on a spinning circle.
    - b. On one phone, uninstall Family and install `Family-test.apk` again (as in D). Open it with airplane mode on, then turn airplane mode off. If it sends you to the Join/Create screen, rejoin with the family code, and tell us.
    - c. Family tab → **Sign out**, then sign in again with Google. Also start signing in and cancel it. Sign-in should work, and cancelling should bring you back to the sign-in screen without an error.
    - d. The shopping checklist from Release 1 is also still open (`docs/superpowers/plans/2026-09-27-family-app-shopping.md`, Task 14, Step 6). You can run it in the same session.
36. **Anything else.** Tell us about anything that felt slow, confusing or hard to read, with the step number if there is one.

## Known limitations you don't need to report

- Reminders can arrive a few minutes after the chore's time, because Android groups them to save battery.
- A chore added on another phone only gets its reminder after this phone has opened Family once. That's why step 25 opens the app on Sara's phone.
- After someone signs out, up to 7 days of their reminders can still appear on that phone.
- In Android's notification settings, the name of the reminder category stays in the language the app had when the first reminder was set. The reminder text itself follows the language.
- Very rarely, if the app's notification part fails to start at the moment a phone is first asked, Android's "Allow notifications?" question doesn't appear. The app still shows its message about turning notifications on in the phone's settings, and following it works.
- Once you've moved to another day in Chores, there's no "Today" button. Come back with the arrows, or pick today in the calendar.
- While loading, Today may show "No lists yet" or "Nothing to buy" for a moment.
- In Arabic, dates use Arabic digits and counts use Western digits.
- History's list filter resets each time you open it.
- The chore title counter doesn't turn red above 80 characters. Save explains the limit instead.
- At the very largest font size, the word "System" under Theme may break across two lines.

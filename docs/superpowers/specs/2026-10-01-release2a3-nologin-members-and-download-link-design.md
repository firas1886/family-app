# Family App — Release 2a.3: members without a login, and a download link

Date: 2026-10-01. Status: approved by Firas on 2026-10-01.

Builds on: Release 2a (`2026-09-28-release2a-chores-and-look-design.md`) and the 2a.1/2a.2 changes (week view, first names, name repair). Everything there still applies unless this spec changes it.

## 1. Why

- **Members without a login:** some family members (young children, a helper) have no phone or Google account, but parents want to give them chores and log them.
- **A download link:** Firas wants to send family a link to download and install the app, with permanent signing so updates install over the top.

### Success looks like

- A parent adds "Yusuf" with just a name. Yusuf gets a colour, a column on the tablet board, and chores assigned to him. Parents tick them.
- Firas sends one "Join our family app" message containing a link and the join code. The relative taps the link, installs, signs in with Google, and types the code.
- Every later version reaches the same link, and phones install it over the existing app.

## 2. Decisions (confirmed by Firas on 2026-10-01)

| Topic | Decision |
|---|---|
| Who ticks a no-login member's chores | Parents only |
| Upgrading a no-login member to a real login later | Not built now; the design keeps it possible |
| Storage | Same `members` list, generated id, `noLogin` flag (approach A) |
| Download hosting | GitHub Releases in a **public** repository, signed with a permanent release key (option C) |
| Invite | A single share message with the download link and the join code |

## 3. Members without a login

### Data

`families/{f}/members/{id}`. The id is `nl_` followed by 20 random letters and digits, so it can never equal a Google sign-in id. Fields:

```
noLogin: true
role: 'child'
name: 1–80 characters
displayName: optional
color: 0–7
pictureTiles: bool
joinedAt
createdBy: the parent's uid
```

Nothing else is new: chores (`assignee`) and done records (`doneBy`) already store a member id.

### Rules (`firestore.rules`, `members/{m}`)

- **Create:** allowed when `isParent(f)`, `m` matches `^nl_[A-Za-z0-9]{20}$`, `noLogin == true`, `role == 'child'`, `name` is a string of 1–80 characters, `createdBy == uid()`, and the optional fields have valid types (`color` int 0–7, `pictureTiles` bool, `displayName` string 1–40). The existing create branches (joining, creating a family) are unchanged.
- **Update:** for a doc with `noLogin == true`, `isParent(f)` may change only `name`, `displayName`, `color` and `pictureTiles`, with the same type checks. `role`, `noLogin` and `createdBy` can never change.
- **The existing self-update branch** (`uid() == m`) can never apply, because no login has an `nl_` id.
- **Delete:** `isParent(f)`, unchanged.
- **Ticking:** no change. Parents may already create done records for any `doneBy`. A child may only tick their own or "anyone" chores, so they can't tick a no-login member's chores.

### App

- **`Member`** gains `noLogin` (bool, read tolerantly; default false).
- **Family screen (parents):** an **"Add member without login"** button below the member list (key `addNoLoginMember`).
  - It opens a name prompt (1–80 characters).
  - On save, it creates the member with the next free colour via `fireAndForget`.
  - Their row shows a **"No login"** tag.
  - Their ⋮ menu offers **Edit name** and **Remove** (with a confirm step), but not "Make parent".
  - The colour dot and the picture-tiles switch behave as for children.
- **Children** see no-login members but get no controls.
- **Chores everywhere:** no-login members are treated like any child member:
  - Who chips, board column, week chips, Chores-tab section, Today progress ring, and the who-did-it list.
  - Only parents can tick their chores (the existing `canToggle` gives this). On a child's phone their chores show but aren't tappable.
- **Reminders:** only parents with "Remind me about everyone's chores" get them.
- **Untouched:** ProfileSync's photo and name repair skip `noLogin` members. Shopping, joining and the last-parent check are unchanged; no-login members are always children.

### Edge cases

- Removing one moves their remaining chores to "Former member", and their history stays (existing behaviour).
- Duplicate names are allowed.
- Offline add and edit sync later.
- More than 8 members: colours repeat (existing behaviour).

### Later (not in this release)

"Link a login": a parent turns a no-login member into a real member when that person signs in. The `nl_` id and the `noLogin` flag are what that step will look for. It would move the member's record and rewrite `assignee`/`doneBy` on their chores and done records.

## 4. Download link and invite

### Hosting

A public GitHub repository holds the code. The existing `.github/workflows/release.yml` builds a signed APK when a release is published. It changes to attach two files:

- `family-app-<tag>.apk` (as now);
- `family-app.apk` (fixed name).

The permanent link is `https://github.com/<owner>/family-app/releases/latest/download/family-app.apk`, which always serves the newest release. The repository must never contain `key.properties`, keystores or `google-services.json`; `.gitignore` already ensures this. Before the first push, all tracked files are scanned for secrets.

### Invite button

The Family screen's share button for the join code becomes **"Invite to family"**. It shares one message in the user's language:

> "Join our family on the Family app: 1) install it from <link> 2) sign in with Google 3) enter the code <CODE>."

The link is a single constant in the app (`appDownloadUrl`), set once the repository exists.

### Firas's one-time steps (his accounts and secrets; Claude can't do these)

1. Create a free GitHub account and an empty public repository `family-app`.
2. Sign in when the GitHub window appears while Claude uploads the code.
3. Run the "Generate signing key" action. Keep the key file safe. Add the 4 signing secrets and the `GOOGLE_SERVICES_JSON` secret.
4. In Firebase, add the release key's SHA-1 and SHA-256 fingerprints, then re-download `google-services.json` and update its secret.
5. Publish release `v1.3.0`.
6. On each phone, once: uninstall the test-signed app, then install from the link. Later releases install over the top.

## 5. Testing

- **Rules (emulator):** a parent creates, edits and removes a no-login member. Refused:
  - a child doing any of those;
  - a bad id (no `nl_`, wrong length, a real-looking uid);
  - `role: 'parent'`;
  - removing `noLogin` or changing `createdBy`;
  - a name that's blank or over 80 characters;
  - a child ticking a no-login member's chore.

  A parent ticking it is allowed. Existing tests still pass.
- **App:**
  - the add flow writes the right doc;
  - the "No login" tag;
  - their menu has no "Make parent";
  - they appear in Who chips, the board, week chips, the Today ring and who-did-it;
  - a child can't tick their chores;
  - ProfileSync never writes to them;
  - Arabic at 320×640 with text 1.3, with no overflow and readable names;
  - the invite message contains the link and the code in both languages.
- **Release:** the workflow attaches `family-app.apk`, and the permanent link downloads it. Firas checks this on his phone after his steps.

## 6. Order of work

1. Finish 1.2.2 (the name-dialog and small-phone fix already briefed).
2. No-login members.
3. Invite button and the release workflow change.
4. With Firas: create the repository, push, set the secrets, publish v1.3.0, then check the link on a phone.

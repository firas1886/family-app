# Family App — one-time setup and releasing

Everything happens in a web browser: GitHub and the Firebase console. Nothing needs to be installed on your computer, except for the optional "Debug key" step in section 2, which uses Android Studio.

## 1. Create the signing key (once, ever)

1. In the GitHub repository, open **Actions → Generate signing key (run once) → Run workflow**.
2. When the run finishes, open it and download the **signing-key** artifact (a zip). It is deleted from GitHub after one day.
3. **Keep `release.jks` and `secrets.txt` safe forever**, for example in your password manager or a private Drive folder. If you lose them, future updates cannot install over the app, and everyone would have to uninstall and reinstall it.
4. In **Settings → Secrets and variables → Actions → New repository secret**, add:
   - `ANDROID_KEYSTORE_BASE64`: the whole contents of `ANDROID_KEYSTORE_BASE64.txt`
   - `ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`: the values in `secrets.txt`
5. Keep `fingerprints.txt` open; you need it in step 2.

## 2. Set up the Firebase project

You already created the Firebase project `familia-a1b9f` with the Android app `com.firas.familia`. Use that project; don't add a new one.

1. Go to https://console.firebase.google.com and open the existing project **familia-a1b9f**.
2. **Build → Authentication → Get started → Sign-in method → Google → Enable**. Pick your email as the support email, then Save.
3. **Build → Firestore Database → Create database → Start in production mode**. Choose the location closest to you (for example `me-central2`, Dammam, if listed).
4. In Firestore, open the **Rules** tab, replace everything with the contents of `firestore.rules` from this repository, and click **Publish**.
5. **Project settings (gear icon) → Your apps** and open the existing Android app `com.firas.familia` (don't click Add app). Add the fingerprints as described in "SHA fingerprints" below.
6. On the same page, **download `google-services.json`**.
7. In GitHub, add one more secret, `GOOGLE_SERVICES_JSON`, and paste the entire contents of `google-services.json`.

### SHA fingerprints

Google sign-in only works if the fingerprints of the key that signed the APK are registered in Firebase. Add them in **Project settings → Your apps → com.firas.familia → Add fingerprint** (one fingerprint per click).

1. **Release key:** add both the SHA1 and the SHA256 values from `fingerprints.txt` (section 1).
2. **Debug key (test APK):** only needed if you install test APKs built on your PC (the APK from a GitHub release doesn't need it). The test APK is signed with that PC's debug key, so its SHA-1 and SHA-256 must be added too. To see them, open **PowerShell** and either:
   - run these four lines (the first goes to the project folder; the quotes are needed because of the space in "Family App"; the second tells Gradle where Android Studio's Java is):
     `cd "D:\ClaudeProjects\Family App\family-app-starter"`
     `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`
     `cd android`
     `.\gradlew signingReport`
     and copy the `SHA1:` and `SHA-256:` lines shown under `Variant: debug`; or
   - run `keytool` from Android Studio's Java folder (it is not on the normal PATH):
     `& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`
3. After adding fingerprints, **download `google-services.json` again**. Replace the local file `android/app/google-services.json` and update the `GOOGLE_SERVICES_JSON` secret in GitHub with the new contents.
4. A test APK signed with the debug key can't be updated in place by the properly signed release APK. **Uninstall the test APK first**, then install the release APK. Family data is in Firebase, so nothing is lost.

## 3. Release a version

1. In GitHub, open **Releases → Draft a new release**.
2. Create a new tag, e.g. `v1.0.0` (use `v1.0.1`, `v1.1.0`… for later updates), and click **Publish release**.
3. The **Release APK** workflow runs for about 10 minutes, then attaches `family-app-v1.0.0.apk` to the release.

## 4. Install on each phone

1. On the phone, open the release page (or send the APK over WhatsApp or Drive) and download the APK.
2. Tap it. The first time, Android asks you to allow **Install unknown apps** for that app (Chrome, WhatsApp…). Allow it, then install.
3. Open **Family** and sign in with Google. The first person creates the family. Everyone else taps **Join a family** and enters the code shown on the Family tab.
4. Promote your wife (or anyone else) to parent from the Family tab.
5. **Chore reminders need notifications.** The first time someone switches on a chore reminder, or the first time a phone has a chore with a reminder, Android asks **"Allow Family to send you notifications?"**. Tap **Allow**. Each phone asks only once. If someone tapped **Don't allow**, fix it on that phone: **Settings → Apps → Family → Notifications → on**. Reminders can arrive a few minutes after the chore's time (Android groups them to save battery). On some phones (Samsung, Xiaomi, Huawei) also set **Settings → Apps → Family → Battery → Unrestricted**, or the phone may hold reminders back.

## Updating

Publish a new release with a higher tag, then install the new APK over the old one. Data lives in Firebase, so nothing is lost.

If `firestore.rules` changes in a later version, paste it into the Firestore **Rules** tab again and click Publish.

**Version 1.1.0 (chores) changes `firestore.rules`.** Publish the new rules first, then install 1.1.0 on every phone. Until the new rules are published, chores can't be saved.

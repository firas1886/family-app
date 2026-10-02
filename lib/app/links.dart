/// Where to download the app. The release workflow sets it with
/// `--dart-define=APP_DOWNLOAD_URL=…`; local builds leave it empty.
const String appDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');

import '../../l10n/app_localizations.dart';

/// The "Join our family" message: the download link (when this build has one)
/// and the join code.
String inviteText(AppLocalizations l, {required String code, required String link}) =>
    link.isEmpty ? l.inviteMessageNoLink(code) : l.inviteMessage(link, code);

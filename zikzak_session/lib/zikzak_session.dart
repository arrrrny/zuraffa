/// zikzak_session — portable browser sessions on the Zuraffa session plugin.
///
/// A [PortableBrowserSession] carries the three things a browser context
/// needs — cookies, headers, and a token — in a form that serializes
/// through the zuraffa session plugin's portable envelope, so a session
/// captured on a server or CLI restores identically on a Flutter app or
/// another device (spec 015, FR-009).
///
/// The package does not reimplement session logic: it registers a `browser`
/// preset on the shared [SessionPresetRegistry] and maps its domain types
/// onto the core [Session] payload.
library;

export 'src/portable_browser_session.dart';

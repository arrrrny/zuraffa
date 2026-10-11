# Evidence: gate-red-evidence (raw command output, captured 2026-09-06T09:47Z)

```text
[flutter-smoke-gate] flutter Flutter 3.47.2 • channel stable • https://github.com/flutter/flutter.git
[flutter-smoke-gate] stage 1/3: example/ (committed Flutter consumer) pub get
Resolving dependencies...
Note: matcher is pinned to version 0.12.20 by flutter_test from the flutter SDK.
See https://dart.dev/go/sdk-version-pinning for details.

Note: test_api is pinned to version 0.7.12 by flutter_test from the flutter SDK.
See https://dart.dev/go/sdk-version-pinning for details.

The current Dart SDK version is 3.13.2.

Because test >=1.16.6 <1.25.5 depends on web_socket_channel ^2.0.0 and graphql >=5.2.0-beta.10 depends on web_socket_channel ^3.0.1, test >=1.16.6 <1.25.5 is incompatible with graphql >=5.2.0-beta.10.
And because test >=1.32.0 depends on test_api 0.7.14, if graphql >=5.2.0-beta.10 and test >=1.16.6 <1.25.5-∞ or >=1.32.0 then test_api 0.7.14.
And because test >=1.31.2 <1.32.0 depends on test_api 0.7.13 and test >=1.31.1 <1.31.2 depends on analyzer >=8.0.0 <14.0.0, if graphql >=5.2.0-beta.10 and test >=1.16.6 <1.25.5-∞ or >=1.31.1 then test_api 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0.
And because test >=1.16.0-nullsafety.19 <1.16.6 depends on test_api 0.2.19 and test >=1.16.0-nullsafety.8 <1.16.3 depends on web_socket_channel ^1.0.0, if graphql >=5.2.0-beta.10 and test >=1.16.0-nullsafety.8 <1.25.5-∞ or >=1.31.1 then test_api 0.2.19 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0 or web_socket_channel ^1.0.0.
And because test <1.16.0-nullsafety.8 doesn't support null safety and test >=1.25.13 <1.28.0 depends on matcher >=0.12.16 <0.12.18, if graphql >=5.2.0-beta.10 and test <1.25.5-∞ or >=1.25.13 <1.28.0-∞ or >=1.31.1 then test_api 0.2.19 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0 or web_socket_channel ^1.0.0 or matcher >=0.12.16 <0.12.18.
And because test >=1.27.0 <1.29.0 depends on test_api 0.7.8 and test >=1.24.3 <1.25.13 depends on matcher >=0.12.16 <0.12.17, if graphql >=5.2.0-beta.10 and test <1.29.0-∞ or >=1.31.1 then test_api 0.2.19 or 0.7.8 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0 or web_socket_channel ^1.0.0 or matcher >=0.12.16 <0.12.18.
Because test >=1.31.0 <1.31.1 depends on test_api 0.7.11 and test >=1.29.0 <1.31.0 depends on analyzer >=8.0.0 <11.0.0, test >=1.29.0 <1.31.1 requires test_api 0.7.11 or analyzer >=8.0.0 <11.0.0.
Thus, if graphql >=5.2.0-beta.10 and test any then test_api 0.2.19 or 0.7.8 or 0.7.11 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0 or web_socket_channel ^1.0.0 or matcher >=0.12.16 <0.12.18.
And because every version of zuraffa from path depends on graphql ^5.2.3, if test any and zuraffa from path then test_api 0.2.19 or 0.7.8 or 0.7.11 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0 or web_socket_channel ^1.0.0 or matcher >=0.12.16 <0.12.18.
And because every version of flutter_test from sdk depends on matcher 0.12.20 and graphql >=5.2.0-beta.10 depends on web_socket_channel ^3.0.1, if test any and zuraffa from path and flutter_test from sdk and graphql >=5.2.0-beta.10 then test_api 0.2.19 or 0.7.8 or 0.7.11 or 0.7.13 or 0.7.14 or analyzer >=8.0.0 <14.0.0.
And because every version of zuraffa from path depends on both analyzer ^14.3.0 and graphql ^5.2.3, if zuraffa from path and test any and flutter_test from sdk then test_api 0.2.19 or 0.7.8 or 0.7.11 or 0.7.13 or 0.7.14.
And because every version of flutter_test from sdk depends on test_api 0.7.12 and every version of zuraffa from path depends on test any, zuraffa from path is incompatible with flutter_test from sdk.
So, because example depends on both zuraffa from path and flutter_test from sdk, version solving failed.

The lower bound of "sdk: '>=1.8.0 <3.0.0'" must be 2.12.0 or higher to enable null safety.
For details, see https://dart.dev/null-safety
Failed to update packages.
[flutter-smoke-gate] FAIL: example/ failed to resolve — Flutter consumers are broken (#1189 regression).
```

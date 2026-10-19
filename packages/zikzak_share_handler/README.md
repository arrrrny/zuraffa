# zikzak_share_handler

Optional [Zuraffa](https://github.com/arrrrny/zuraffa) capability package
(issue #686): zuraffa-native share handler — share text, URLs, and files via
the platform share sheet.

## Enable

```bash
zfa plugin enable share_handler
```

Then add the repository-local package to your pubspec:

```yaml
dependencies:
  zikzak_share_handler:
    path: packages/zikzak_share_handler
```

Then run `dart pub get`.
EOF
echo done
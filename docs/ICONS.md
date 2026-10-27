# App icon

The original Icon Composer document is `Resources/AppIcon.icon`. The final Xcode asset catalog is `Resources/Assets.xcassets/AppIcon.appiconset`; the app bundle receives the compiled `Assets.car`. The normal build uses the committed asset catalog and does not need Icon Composer.

To regenerate the asset catalog after intentionally editing the source document, run:

```sh
scripts/generate-icon.sh
```

The optional script requires `ictool` from Icon Composer, usually installed with Additional Tools for Xcode. It writes temporary files under `.build/icon-gen/` and replaces the committed PNGs and `Contents.json` in the asset catalog. If generation fails, restore those generated files with `git restore Resources/Assets.xcassets/AppIcon.appiconset`. The script preserves the original source document; `make check` verifies the compiled icon is present in the app bundle. Do not replace the original artwork without a product design change.

The Git icon SVG and Icon Composer assets retain their licenses in [third-party notices](THIRD-PARTY-NOTICES.md).

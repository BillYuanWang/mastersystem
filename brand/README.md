# Master Dance Brand Assets

`MasterDanceLogoSource.png` is the approved full-color Master Dance logo used on Xiaohongshu. It is the single source of truth for app icons, in-app branding, schedules, and billing documents.

Do not recolor, redraw, vectorize, or manually overwrite generated derivatives. Run `./script/generate_brand_assets.sh` from the repository root after replacing the approved source image.

Generated assets:

- `apps/Shared/Resources/MasterDanceLogo.png`: full brand lockup for formal documents.
- `apps/Shared/Resources/MasterDanceLogoMark.png`: close crop for compact UI placements.
- `apps/Shared/Resources/AppIcon.icns`: rounded macOS app icon using the approved gold mark.
- `apps/MasterDanceMobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`: full-color iOS icon using the same gold mark.

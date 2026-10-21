fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios store_content

```sh
[bundle exec] fastlane ios store_content
```

Upload localized metadata, screenshots, and App Preview videos without submitting for review

### ios store_metadata

```sh
[bundle exec] fastlane ios store_metadata
```

Upload only the localized text metadata (name, subtitle, keywords, promo text, description, release notes). No screenshots, no binary, no review submission

### ios store_screenshots

```sh
[bundle exec] fastlane ios store_screenshots
```

Replace the App Store screenshots with AppStoreAssets/final. No text metadata, no binary, no review submission

### ios remove_app_previews

```sh
[bundle exec] fastlane ios remove_app_previews
```

Delete every App Preview video from the editable App Store version, in all localizations

### ios store_content_preview

```sh
[bundle exec] fastlane ios store_content_preview
```

Generate App Store Connect's local HTML metadata preview without uploading

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

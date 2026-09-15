# MarkLook

MarkLook is a native macOS Quick Look extension for Markdown. Install and launch the host app once, enable its extension, then select a Markdown file in Finder and press Space.

## Use the included local build

The separately packaged `MarkLook.app` is an ad-hoc-signed Apple Silicon build for local testing on macOS 13 or newer. Copy it to `/Applications`, launch it once, and follow the setup steps shown in the window. It is not Developer ID signed or notarized for public distribution; use the Xcode project and your Apple development team for that.

## Build and run

1. Open `MarkLook.xcodeproj` in Xcode.
2. Select the **MarkLook** scheme and **My Mac** destination.
3. If Xcode requests signing, choose your development team for both the MarkLook app and MarkLookPreview extension targets.
4. Press **Run**.
5. Move the built app to `/Applications` for regular use.
6. Open **System Settings → General → Login Items & Extensions → Quick Look**, then enable **MarkLook**.

The app includes a **Show Sample in Finder** button for an end-to-end check.

If Finder has cached an earlier extension state, run:

```sh
qlmanage -r
killall Finder
```

## What is supported

- Headings, emphasis, strikethrough, links, and inline code
- Ordered, unordered, and nested lists
- Block quotes, thematic breaks, fenced code blocks, and tables
- Local images stored beside or below the Markdown document
- Automatic light and dark appearance
- `.md`, `.markdown`, `.mdown`, `.mkdn`, `.mkd`, `.mdwn`, `.mdtxt`, and `.mdtext`

MarkLook intentionally does not load remote images or execute embedded HTML. It only makes `http`, `https`, and `mailto` links clickable. Markdown files are limited to 10 MB, and each local image attachment is limited to 15 MB.

## Test the renderer

The Markdown renderer is also a Swift package, so it can be tested independently:

```sh
swift test
```

The production extension itself has no third-party dependencies and makes no network requests.

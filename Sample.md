# MarkLook is working

MarkLook turns Markdown into a native-looking **Quick Look** preview right inside Finder.

## What it renders

- Headings, paragraphs, and nested lists
- **Bold**, *italic*, ~~strikethrough~~, and `inline code`
- [Safe web links](https://developer.apple.com/documentation/quicklook)
- Tables and fenced code blocks

| Feature | Status |
|:--|:--:|
| Light and dark mode | ✓ |
| Local images | ✓ |
| Network required | No |

> Select any `.md` file in Finder and press **Space**.

```swift
struct Preview: Delightful {
    let happensRightInFinder = true
}
```

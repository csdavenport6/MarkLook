import Foundation
import Testing
@testable import MarkLookCore

@Test func rendersCommonMarkdownAndEscapesRawHTML() throws {
    let rendered = try MarkdownRenderer.render("""
    # Title

    This is **bold**, *italic*, ~~old~~, and `code`.

    <script>alert('nope')</script>
    """)

    #expect(rendered.html.contains("<h1>Title</h1>"))
    #expect(rendered.html.contains("<strong>bold</strong>"))
    #expect(rendered.html.contains("<em>italic</em>"))
    #expect(rendered.html.contains("<del>old</del>"))
    #expect(rendered.html.contains("<code>code</code>"))
    #expect(!rendered.html.contains("<script>"))
    #expect(rendered.html.contains("&lt;script&gt;"))
}

@Test func rendersListsQuotesCodeAndTables() throws {
    let rendered = try MarkdownRenderer.render("""
    - one
      - nested
    - two

    > quoted

    ```swift
    let answer = 42
    ```

    | Name | Value |
    |:--|--:|
    | answer | 42 |
    """)

    #expect(rendered.html.contains("<ul>"))
    #expect(rendered.html.contains("<blockquote>"))
    #expect(rendered.html.contains("class=\"language-swift\""))
    #expect(rendered.html.contains("<table>"))
    #expect(rendered.html.contains("text-align:right"))
}

@Test func allowsOnlySafeLinkSchemes() throws {
    let rendered = try MarkdownRenderer.render("""
    [web](https://example.com)

    [unsafe](javascript:alert(1))
    """)

    #expect(rendered.html.contains("href=\"https://example.com\""))
    #expect(!rendered.html.contains("href=\"javascript:"))
}

@Test func attachesImagesOnlyFromTheDocumentDirectory() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let documentDirectory = root.appendingPathComponent("document", isDirectory: true)
    try fileManager.createDirectory(at: documentDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: documentDirectory.appendingPathComponent("inside.png"))
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: root.appendingPathComponent("outside.png"))

    let rendered = try MarkdownRenderer.render(
        "![inside](inside.png) ![outside](../outside.png)",
        baseURL: documentDirectory
    )

    #expect(rendered.attachments.count == 1)
    #expect(rendered.html.contains("src=\"cid:image-1\""))
    #expect(rendered.html.contains("outside"))
}

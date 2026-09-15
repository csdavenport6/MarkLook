import Foundation
import UniformTypeIdentifiers

public struct MarkdownAttachment: Equatable {
    public let identifier: String
    public let data: Data
    public let contentTypeIdentifier: String
}

public struct RenderedMarkdown: Equatable {
    public let html: String
    public let attachments: [MarkdownAttachment]
}

public enum MarkdownRenderer {
    private static let maximumAttachmentSize = 15 * 1_024 * 1_024

    public static func render(_ source: String, baseURL: URL? = nil) throws -> RenderedMarkdown {
        let normalizedBaseURL = baseURL?.appendingPathComponent("", isDirectory: true)
        let attributed = try AttributedString(
            markdown: source,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            ),
            baseURL: normalizedBaseURL
        )

        let root = BlockNode(identity: Int.min, kind: nil)
        var nodesByIdentity: [Int: BlockNode] = [:]
        let fallbackIdentity = Int.min + 1

        for run in attributed.runs {
            let span = InlineSpan(
                text: String(attributed.characters[run.range]),
                intents: run.inlinePresentationIntent ?? [],
                link: run.link,
                imageURL: run.imageURL
            )

            guard let presentation = run.presentationIntent else {
                let fallback: BlockNode
                if let existing = root.children.last, existing.identity == fallbackIdentity {
                    fallback = existing
                } else {
                    fallback = BlockNode(identity: fallbackIdentity, kind: .paragraph)
                    root.children.append(fallback)
                }
                fallback.spans.append(span)
                continue
            }

            var parent = root
            for component in presentation.components.reversed() {
                let node: BlockNode
                if let existing = nodesByIdentity[component.identity] {
                    node = existing
                } else {
                    node = BlockNode(identity: component.identity, kind: component.kind)
                    nodesByIdentity[component.identity] = node
                }

                if !parent.children.contains(where: { $0 === node }) {
                    parent.children.append(node)
                }
                parent = node
            }
            parent.spans.append(span)
        }

        var collector = AttachmentCollector(baseURL: normalizedBaseURL)
        let body: String
        if root.children.isEmpty {
            body = "<div class=\"empty\">Empty Markdown document</div>"
        } else {
            body = root.children.map { render($0, collector: &collector) }.joined(separator: "\n")
        }

        return RenderedMarkdown(
            html: htmlDocument(body: body),
            attachments: collector.attachments
        )
    }

    private static func render(_ node: BlockNode, collector: inout AttachmentCollector) -> String {
        let inline = renderSpans(node.spans, collector: &collector)
        let children = node.children.map { render($0, collector: &collector) }.joined(separator: "\n")

        guard let kind = node.kind else { return inline + children }

        switch kind {
        case .paragraph:
            return "<p>\(inline)\(children)</p>"
        case .header(let level):
            let safeLevel = min(max(level, 1), 6)
            return "<h\(safeLevel)>\(inline)\(children)</h\(safeLevel)>"
        case .orderedList:
            return "<ol>\(children)</ol>"
        case .unorderedList:
            return "<ul>\(children)</ul>"
        case .listItem:
            return "<li>\(inline)\(children)</li>"
        case .codeBlock(let languageHint):
            let language = languageHint.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
            return "<pre><code\(language)>\(escapeText(node.spans.map(\.text).joined()))</code></pre>"
        case .blockQuote:
            return "<blockquote>\(inline)\(children)</blockquote>"
        case .thematicBreak:
            return "<hr>"
        case .table(let columns):
            return renderTable(node, columns: columns, collector: &collector)
        case .tableHeaderRow:
            return "<thead><tr>\(children)</tr></thead>"
        case .tableRow:
            return "<tr>\(inline)\(children)</tr>"
        case .tableCell:
            return "<td>\(inline)\(children)</td>"
        @unknown default:
            return inline + children
        }
    }

    private static func renderTable(
        _ node: BlockNode,
        columns: [PresentationIntent.TableColumn],
        collector: inout AttachmentCollector
    ) -> String {
        var header = ""
        var rows: [String] = []

        for child in node.children {
            switch child.kind {
            case .tableHeaderRow:
                header = "<thead>\(renderTableRow(child, header: true, columns: columns, collector: &collector))</thead>"
            case .tableRow:
                rows.append(renderTableRow(child, header: false, columns: columns, collector: &collector))
            default:
                rows.append(render(child, collector: &collector))
            }
        }

        let body = rows.isEmpty ? "" : "<tbody>\(rows.joined())</tbody>"
        return "<div class=\"table-scroll\"><table>\(header)\(body)</table></div>"
    }

    private static func renderTableRow(
        _ node: BlockNode,
        header: Bool,
        columns: [PresentationIntent.TableColumn],
        collector: inout AttachmentCollector
    ) -> String {
        let tag = header ? "th" : "td"
        let cells = node.children.map { cell -> String in
            let index: Int
            if case .tableCell(let columnIndex) = cell.kind {
                index = columnIndex
            } else {
                index = 0
            }

            let alignment: String
            if columns.indices.contains(index) {
                switch columns[index].alignment {
                case .left: alignment = "left"
                case .center: alignment = "center"
                case .right: alignment = "right"
                @unknown default: alignment = "left"
                }
            } else {
                alignment = "left"
            }

            let inline = renderSpans(cell.spans, collector: &collector)
            let nested = cell.children.map { render($0, collector: &collector) }.joined()
            return "<\(tag) style=\"text-align:\(alignment)\">\(inline)\(nested)</\(tag)>"
        }.joined()
        return "<tr>\(cells)</tr>"
    }

    private static func renderSpans(
        _ spans: [InlineSpan],
        collector: inout AttachmentCollector
    ) -> String {
        spans.map { span in
            if span.intents.contains(.lineBreak) {
                return "<br>\n"
            }

            var value: String
            if let imageURL = span.imageURL {
                value = collector.imageTag(for: imageURL, alt: span.text)
                    ?? "<span class=\"image-alt\">\(escapeText(span.text))</span>"
            } else {
                value = escapeText(span.text)
            }

            if span.intents.contains(.code) {
                value = "<code>\(value)</code>"
            }
            if span.intents.contains(.strikethrough) {
                value = "<del>\(value)</del>"
            }
            if span.intents.contains(.emphasized) {
                value = "<em>\(value)</em>"
            }
            if span.intents.contains(.stronglyEmphasized) {
                value = "<strong>\(value)</strong>"
            }
            if let link = safeLink(span.link) {
                value = "<a href=\"\(escapeAttribute(link))\">\(value)</a>"
            }
            return value
        }.joined()
    }

    private static func safeLink(_ url: URL?) -> String? {
        guard let url, let scheme = url.scheme?.lowercased() else { return nil }
        guard ["http", "https", "mailto"].contains(scheme) else { return nil }
        return url.absoluteString
    }

    private static func supportedImageType(for pathExtension: String) -> UTType? {
        switch pathExtension.lowercased() {
        case "png": .png
        case "jpg", "jpeg", "jpe": .jpeg
        case "gif": .gif
        case "tif", "tiff": .tiff
        case "bmp": .bmp
        case "ico": .ico
        case "heif": .heif
        case "heic": .heic
        case "webp": .webP
        default: nil
        }
    }

    private static func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ text: String) -> String {
        escapeText(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func htmlDocument(body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: light dark;
              --background: #ffffff;
              --foreground: #1d1d1f;
              --secondary: #6e6e73;
              --border: #d2d2d7;
              --code: #f5f5f7;
              --accent: #0066cc;
              --quote: #8e8e93;
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --background: #1e1e1e;
                --foreground: #f5f5f7;
                --secondary: #a1a1a6;
                --border: #48484a;
                --code: #2c2c2e;
                --accent: #64a8ff;
                --quote: #98989d;
              }
            }
            * { box-sizing: border-box; }
            html { background: var(--background); }
            body {
              max-width: 900px;
              margin: 0 auto;
              padding: 42px 52px 72px;
              background: var(--background);
              color: var(--foreground);
              font: 16px/1.62 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
              overflow-wrap: anywhere;
            }
            h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.45em 0 .55em; }
            h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
            h2 { font-size: 1.5em; padding-bottom: .25em; border-bottom: 1px solid var(--border); }
            h3 { font-size: 1.25em; }
            h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
            p { margin: 0 0 1em; }
            a { color: var(--accent); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace; }
            code { padding: .15em .35em; border-radius: 5px; background: var(--code); font-size: .9em; }
            pre { padding: 16px 18px; border: 1px solid var(--border); border-radius: 10px; background: var(--code); overflow: auto; line-height: 1.48; }
            pre code { padding: 0; background: transparent; font-size: 13px; overflow-wrap: normal; }
            blockquote { margin: 1em 0; padding: .15em 1em; color: var(--secondary); border-left: 4px solid var(--quote); }
            blockquote > p:last-child { margin-bottom: 0; }
            ul, ol { margin: 0 0 1em; padding-left: 2em; }
            li > p { margin: .25em 0; }
            li > ul, li > ol { margin-bottom: .25em; }
            hr { height: 1px; margin: 2em 0; border: 0; background: var(--border); }
            .table-scroll { margin: 1em 0; overflow-x: auto; }
            table { width: 100%; border-spacing: 0; border-collapse: collapse; }
            th, td { padding: 8px 12px; border: 1px solid var(--border); }
            th { background: var(--code); font-weight: 600; }
            img { display: block; max-width: 100%; height: auto; margin: 1em auto; border-radius: 8px; }
            .image-alt { color: var(--secondary); font-style: italic; }
            .empty { color: var(--secondary); text-align: center; padding: 35vh 0; }
            @media (max-width: 600px) { body { padding: 28px 24px 48px; } }
          </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private final class BlockNode {
        let identity: Int
        let kind: PresentationIntent.Kind?
        var children: [BlockNode] = []
        var spans: [InlineSpan] = []

        init(identity: Int, kind: PresentationIntent.Kind?) {
            self.identity = identity
            self.kind = kind
        }
    }

    private struct InlineSpan {
        let text: String
        let intents: InlinePresentationIntent
        let link: URL?
        let imageURL: URL?
    }

    private struct AttachmentCollector {
        let baseURL: URL?
        var attachments: [MarkdownAttachment] = []
        private var identifiersByPath: [String: String] = [:]

        init(baseURL: URL?) {
            self.baseURL = baseURL
        }

        mutating func imageTag(for imageURL: URL, alt: String) -> String? {
            guard let baseURL else { return nil }

            let root = baseURL.standardizedFileURL.resolvingSymlinksInPath()
            let candidate = imageURL.isFileURL
                ? imageURL
                : URL(string: imageURL.relativeString, relativeTo: baseURL)?.absoluteURL
            guard let candidate, candidate.isFileURL else { return nil }

            let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
            let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
            guard resolved.path.hasPrefix(rootPath) else { return nil }

            if let identifier = identifiersByPath[resolved.path] {
                return imageHTML(identifier: identifier, alt: alt)
            }

            guard
                let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                values.isRegularFile == true,
                let size = values.fileSize,
                size <= MarkdownRenderer.maximumAttachmentSize,
                let type = MarkdownRenderer.supportedImageType(for: resolved.pathExtension),
                let data = try? Data(contentsOf: resolved, options: .mappedIfSafe)
            else {
                return nil
            }

            let identifier = "image-\(attachments.count + 1)"
            identifiersByPath[resolved.path] = identifier
            attachments.append(
                MarkdownAttachment(
                    identifier: identifier,
                    data: data,
                    contentTypeIdentifier: type.identifier
                )
            )
            return imageHTML(identifier: identifier, alt: alt)
        }

        private func imageHTML(identifier: String, alt: String) -> String {
            "<img src=\"cid:\(identifier)\" alt=\"\(MarkdownRenderer.escapeAttribute(alt))\">"
        }
    }
}

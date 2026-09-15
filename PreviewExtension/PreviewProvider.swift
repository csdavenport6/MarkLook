import Foundation
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    private let maximumMarkdownSize = 10 * 1_024 * 1_024

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])

        if let size = values.fileSize, size > maximumMarkdownSize {
            throw PreviewError.fileTooLarge(size: size, limit: maximumMarkdownSize)
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let markdown = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let rendered = try MarkdownRenderer.render(
            markdown,
            baseURL: fileURL.deletingLastPathComponent()
        )
        let html = Data(rendered.html.utf8)

        let attachments: [String: QLPreviewReplyAttachment] = Dictionary(
            uniqueKeysWithValues: rendered.attachments.compactMap { attachment in
            guard let type = UTType(attachment.contentTypeIdentifier) else { return nil }
            return (
                attachment.identifier,
                QLPreviewReplyAttachment(data: attachment.data, contentType: type)
            )
        })

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 920, height: 1_100)
        ) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            replyToUpdate.attachments = attachments
            return html
        }
        reply.title = fileURL.lastPathComponent
        return reply
    }
}

private enum PreviewError: LocalizedError {
    case fileTooLarge(size: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let size, let limit):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "This Markdown file is \(formatter.string(fromByteCount: Int64(size))). MarkLook previews files up to \(formatter.string(fromByteCount: Int64(limit)))."
        }
    }
}

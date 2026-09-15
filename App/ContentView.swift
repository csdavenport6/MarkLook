import AppKit
import SwiftUI

struct ContentView: View {
    @State private var message: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("MarkLook")
                    .font(.largeTitle.bold())
                Text("Rich Markdown previews in Finder")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                SetupRow(number: 1, text: "Keep MarkLook in your Applications folder and launch it once.")
                SetupRow(number: 2, text: "In System Settings, open General → Login Items & Extensions → Quick Look.")
                SetupRow(number: 3, text: "Turn on MarkLook, then select a Markdown file in Finder and press Space.")
            }
            .padding(20)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Button("Open System Settings", action: openSystemSettings)
                    .buttonStyle(.borderedProminent)
                Button("Show Sample in Finder", action: revealSample)
                    .buttonStyle(.bordered)
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(36)
    }

    private func openSystemSettings() {
        let settings = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if !NSWorkspace.shared.open(settings) {
            message = "Open System Settings → General → Login Items & Extensions → Quick Look."
        }
    }

    private func revealSample() {
        do {
            guard let bundledSample = Bundle.main.url(forResource: "Sample", withExtension: "md") else {
                throw SampleError.missingResource
            }
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MarkLook", isDirectory: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

            let sample = support.appendingPathComponent("MarkLook Sample.md")
            if FileManager.default.fileExists(atPath: sample.path) {
                try FileManager.default.removeItem(at: sample)
            }
            try FileManager.default.copyItem(at: bundledSample, to: sample)
            NSWorkspace.shared.activateFileViewerSelecting([sample])
            message = "Select the sample in Finder and press Space."
        } catch {
            message = "Couldn’t create the sample: \(error.localizedDescription)"
        }
    }
}

private struct SetupRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .foregroundStyle(.white)
                .background(.tint, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum SampleError: LocalizedError {
    case missingResource

    var errorDescription: String? { "The bundled sample is missing." }
}

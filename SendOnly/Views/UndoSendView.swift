import SwiftUI

struct UndoSendView: View {
    let secondsRemaining: Int
    let onUndo: () -> Void

    @State private var progress: Double = 1.0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Undo card
            VStack(spacing: 20) {
                // Circular countdown
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    // Countdown number
                    Text("\(secondsRemaining)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Sending...")
                    .font(.headline)
                    .foregroundColor(.white)

                // Undo button
                Button {
                    onUndo()
                } label: {
                    Text("Undo")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)

                Text("Press Esc or click Undo to cancel")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                    .shadow(radius: 20)
            )
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: secondsRemaining) { _, _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        let totalSeconds = Double(UserDefaults.standard.integer(forKey: "undoDelay").nonZero ?? 10)
        withAnimation(.linear(duration: 0.1)) {
            progress = Double(secondsRemaining) / totalSeconds
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray
        UndoSendView(secondsRemaining: 7) {
            print("Undo pressed")
        }
    }
}

/// Reads `stream` in the background until the task is cancelled, and returns what arrived. A value that
/// doesn't decode ends the stream, and the task throws that error.
///
/// For streams that push only on events the live tests can't always cause: whatever arrives must decode.
func collectUntilCancelled<Element: Sendable>(
    _ stream: AsyncThrowingStream<Element, any Error>
) -> Task<[Element], any Error> {
    Task {
        var values: [Element] = []
        for try await value in stream {
            values.append(value)
        }
        return values
    }
}

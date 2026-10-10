import Quickshell.Io

// Bounded stream collector for Process stdout/stderr.
//
// StdioCollector buffers the complete stream with no size ceiling, so a faulty
// or compromised endpoint could exhaust plugin memory before parsing. This
// parser instead accumulates text up to maxBytes and terminates the producing
// process as soon as the ceiling is exceeded (fail closed). The collected text
// is capped at maxBytes, so memory stays bounded regardless of what the remote
// end sends.
SplitParser {
    id: collector

    // Empty marker delivers each input chunk as it arrives.
    splitMarker: ""

    /// The Process whose stdout/stderr this parser collects.
    property Process process: null
    /// Hard receive ceiling in characters. For ASCII responses (JSON) this is
    /// equivalent to a byte ceiling. Defaults to 1 MiB.
    property int maxBytes: 1048576
    /// True once the stream would have exceeded maxBytes; the producer has
    /// been terminated and the collected text must not be used.
    property bool overflowed: false
    /// Collected text, never longer than maxBytes.
    property string text: ""

    function reset() {
        overflowed = false
        text = ""
    }

    function stopProducer() {
        if (process)
            process.running = false // SIGTERM
    }

    onRead: (chunk) => {
        if (overflowed) {
            stopProducer()
            return
        }
        var remaining = maxBytes - text.length
        if (remaining <= 0) {
            overflowed = true
            stopProducer()
        } else if (chunk.length > remaining) {
            text = text + chunk.slice(0, remaining)
            overflowed = true
            stopProducer()
        } else {
            text += chunk
        }
    }
}
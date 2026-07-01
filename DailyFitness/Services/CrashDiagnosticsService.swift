import Foundation
import MetricKit
import OSLog

/// Dependency-free crash, hang, and CPU-exception diagnostics via Apple's MetricKit.
///
/// MetricKit delivers `MXDiagnosticPayload`s (including crash diagnostics) on the launch *after*
/// the event occurred. We log a structured summary so a TestFlight build's crash-free rate (US-120,
/// target ≥99%) can be investigated from Console.app / `log collect` without bundling a third-party
/// crash SDK. Register once at launch via `start()`.
///
/// `@unchecked Sendable` is accurate here: the type holds no mutable state — it only logs the payloads
/// the system hands it on its own queue — so the shared instance is safe to reference across actors.
final class CrashDiagnosticsService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = CrashDiagnosticsService()

    /// Begin receiving MetricKit metric & diagnostic payloads.
    func start() {
        MXMetricManager.shared.add(self)
    }

    // Metric payloads (battery, launch time, etc.) — not needed for crash tracking, but the
    // protocol requires the method. Logged at debug level only.
    func didReceive(_ payloads: [MXMetricPayload]) {
        AppLog.app.debug("MetricKit: received \(payloads.count) metric payload(s)")
    }

    // Diagnostic payloads carry crash / hang / CPU-exception / disk-write reports.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashes = payload.crashDiagnostics ?? []
            let hangs = payload.hangDiagnostics ?? []
            let cpuExceptions = payload.cpuExceptionDiagnostics ?? []

            if !crashes.isEmpty {
                AppLog.app.error("MetricKit: \(crashes.count) crash diagnostic(s) in last session")
                for crash in crashes {
                    let reason = crash.terminationReason ?? "unknown"
                    let signal = crash.signal?.stringValue ?? "—"
                    let exception = crash.exceptionType?.stringValue ?? "—"
                    AppLog.app.error(
                        "MetricKit crash: reason=\(reason, privacy: .public) signal=\(signal, privacy: .public) exceptionType=\(exception, privacy: .public)"
                    )
                }
            }
            if !hangs.isEmpty {
                AppLog.app.error("MetricKit: \(hangs.count) hang diagnostic(s) in last session")
            }
            if !cpuExceptions.isEmpty {
                AppLog.app.error("MetricKit: \(cpuExceptions.count) CPU-exception diagnostic(s) in last session")
            }
        }
    }
}

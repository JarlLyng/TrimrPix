//
//  MetricsService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 10/04/2026.
//

import Foundation
import MetricKit

/// Subscribes to MetricKit diagnostics and payloads.
/// Crash reports, hang diagnostics, and performance metrics are delivered
/// through Apple's anonymised pipeline — no user-identifiable data leaves
/// the device, and no third-party services are involved.
///
/// `@unchecked Sendable`: holds no mutable state (only an immutable `let logger`),
/// so the `shared` singleton is safe to reference from any context.
final class MetricsService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = MetricsService()
    private let logger: any LoggerProtocol

    private override init() {
        self.logger = Logger.shared
        super.init()
    }

    /// Call once at app launch to start receiving diagnostics.
    func start() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscriber registered")
    }

    /// Stop receiving diagnostics (e.g. on app termination).
    func stop() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called roughly once per day with aggregated metrics.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.info("MetricKit metric payload received: \(payload.dictionaryRepresentation())")
        }
    }

    /// Called when a diagnostic report (crash, hang, disk write) is available.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logger.error("MetricKit diagnostic received: \(payload.dictionaryRepresentation())")
        }
    }
}

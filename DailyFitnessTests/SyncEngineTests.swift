import XCTest
@testable import DailyFitness

/// Unit coverage for the parts of the sync engine that are pure and therefore testable without a
/// live Supabase backend: the conflict/last-writer-wins decision table and delete-table routing.
///
/// The end-to-end round trip (push → second device → restore) requires real Supabase credentials
/// and is the manual QA gate (second-simulator restore) called out in the Phase E plan.
final class SyncResolverTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_000_100) // newer than t0

    // MARK: - No local row

    func testNoLocalLiveRemoteInserts() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: false, localPending: false, localUpdatedAt: nil, remoteUpdatedAt: t0, remoteDeleted: false),
            .insert
        )
    }

    func testNoLocalDeletedRemoteIsNoop() {
        // We never had it and it's tombstoned remotely — don't resurrect it.
        XCTAssertEqual(
            SyncResolver.decide(localExists: false, localPending: false, localUpdatedAt: nil, remoteUpdatedAt: t0, remoteDeleted: true),
            .keepLocal
        )
    }

    // MARK: - Local synced (no pending edits)

    func testSyncedLocalRemoteNewerAppliesRemote() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: false, localUpdatedAt: t0, remoteUpdatedAt: t1, remoteDeleted: false),
            .applyRemote
        )
    }

    func testSyncedLocalRemoteOlderKeepsLocal() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: false, localUpdatedAt: t1, remoteUpdatedAt: t0, remoteDeleted: false),
            .keepLocal
        )
    }

    func testSyncedLocalRemoteEqualKeepsLocal() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: false, localUpdatedAt: t0, remoteUpdatedAt: t0, remoteDeleted: false),
            .keepLocal
        )
    }

    func testLocalWithUnknownTimestampAppliesRemote() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: false, localUpdatedAt: nil, remoteUpdatedAt: t0, remoteDeleted: false),
            .applyRemote
        )
    }

    // MARK: - Local pending (unsynced edits) → conflicts

    func testPendingLocalRemoteNewerIsConflict() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: true, localUpdatedAt: t0, remoteUpdatedAt: t1, remoteDeleted: false),
            .conflict
        )
    }

    func testPendingLocalRemoteOlderKeepsLocal() {
        // Local has the newer unsynced edit; it will win on the next push.
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: true, localUpdatedAt: t1, remoteUpdatedAt: t0, remoteDeleted: false),
            .keepLocal
        )
    }

    // MARK: - Remote tombstones

    func testRemoteDeletedSyncedLocalDeletesLocal() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: false, localUpdatedAt: t0, remoteUpdatedAt: t1, remoteDeleted: true),
            .deleteLocal
        )
    }

    func testRemoteDeletedButLocalHasNewerPendingEditKeepsLocal() {
        // The user re-created/edited locally after the remote delete; don't lose that edit.
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: true, localUpdatedAt: t1, remoteUpdatedAt: t0, remoteDeleted: true),
            .keepLocal
        )
    }

    func testRemoteDeletedAndLocalPendingButOlderDeletesLocal() {
        XCTAssertEqual(
            SyncResolver.decide(localExists: true, localPending: true, localUpdatedAt: t0, remoteUpdatedAt: t1, remoteDeleted: true),
            .deleteLocal
        )
    }
}

final class SyncEntityTypeTests: XCTestCase {
    /// Regression guard for the original data-loss bug: deletes were hard-coded to
    /// `workout_sessions` regardless of entity type. Each type must map to its own table.
    func testEachTypeRoutesToItsOwnTable() {
        XCTAssertEqual(SyncEntityType.session.table, "workout_sessions")
        XCTAssertEqual(SyncEntityType.routine.table, "routines")
        XCTAssertEqual(SyncEntityType.program.table, "programs")
        XCTAssertEqual(SyncEntityType.exercise.table, "exercises")
    }

    func testTablesAreAllDistinct() {
        let tables = SyncEntityType.allCases.map(\.table)
        XCTAssertEqual(Set(tables).count, tables.count, "Every entity type must target a distinct table")
    }
}

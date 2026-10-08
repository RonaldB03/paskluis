package nl.paskluis.app

import org.junit.Assert.*
import org.junit.Test

class GiftReminderPolicyTest {
    @Test fun firstEntryMayNotify() { assertTrue(GiftReminderPolicy.mayNotify(1000,2000,0)) }
    @Test fun expiredSnapshotCannotNotify() { assertFalse(GiftReminderPolicy.mayNotify(2000,2000,0)) }
    @Test fun repeatedEntryIsSuppressed() { assertFalse(GiftReminderPolicy.mayNotify(86400999,999999999,1000)) }
    @Test fun fullDayAllowsAnotherReminder() { assertTrue(GiftReminderPolicy.mayNotify(86401000,999999999,1000)) }
    @Test fun ClockRollbackCannotBypassCooldown() { assertFalse(GiftReminderPolicy.mayNotify(500,999999999,1000)) }
}

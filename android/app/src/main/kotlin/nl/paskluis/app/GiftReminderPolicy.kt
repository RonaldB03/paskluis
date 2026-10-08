package nl.paskluis.app

object GiftReminderPolicy {
    fun mayNotify(now: Long, validUntil: Long, last: Long): Boolean =
        now < validUntil && (last == 0L || (now >= last && now - last >= 86_400_000L))
}

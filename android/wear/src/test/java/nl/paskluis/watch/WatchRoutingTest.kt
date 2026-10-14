package nl.paskluis.watch
import org.junit.Assert.*
import org.junit.Test
class WatchRoutingTest {
    @Test fun onlyChosenWatchReceives() {
        val route = WatchRouting.path("watch-one")
        assertTrue(WatchRouting.accepts(route,"watch-one"))
        assertFalse(WatchRouting.accepts(route,"watch-two"))
        assertFalse(WatchRouting.accepts(WatchProtocol.PATH,"watch-one"))
        assertFalse(WatchRouting.accepts(route+"/other","watch-one"))
    }
    @Test fun anotherWatchCannotConfirm() {
        assertTrue(WatchRouting.acceptsAck("watch-one","watch-one"))
        assertFalse(WatchRouting.acceptsAck("watch-two","watch-one"))
        assertFalse(WatchRouting.acceptsAck("watch-one",null))
    }
}

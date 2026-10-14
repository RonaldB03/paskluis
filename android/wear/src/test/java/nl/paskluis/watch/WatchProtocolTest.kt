package nl.paskluis.watch

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class WatchProtocolTest {
    private fun snapshot(revision: Int = 1, owner: String = "phone-a") = WatchProtocol.parse(
        """{"schema":1,"owner":"$owner","revision":$revision,"language":"nl","cards":[]}""")
    @Test fun categoriesPreserveLegacyAndRejectUnknownValues() {
        val card = JSONObject("""{"id":"a","name":"Test","code":"001","favorite":false,"width":4,"height":1,"bits":"a"}""")
        for(category in listOf("loyalty","qr","gift")) {
            card.put("category",category)
            val incoming = snapshot().put("cards", org.json.JSONArray().put(card))
            assertEquals(category, WatchProtocol.parse(incoming.toString()).getJSONArray("cards").getJSONObject(0).getString("category"))
        }
        card.put("category","unknown")
        assertThrows(IllegalArgumentException::class.java) { WatchProtocol.parse(snapshot().put("cards",org.json.JSONArray().put(card)).toString()) }
    }
    @Test fun oldRevisionCannotRestoreDeletedCards() {
        assertEquals(WatchProtocol.Decision.REJECT,WatchProtocol.decide(snapshot(3),snapshot(2),true))
    }
    @Test fun lostAcknowledgementCanBeRetriedWithoutRewriting() {
        assertEquals(WatchProtocol.Decision.ACKNOWLEDGE,WatchProtocol.decide(snapshot(),snapshot(),true))
    }
    @Test fun localEraseCannotBeUndoneByCachedData() {
        val erased = snapshot().put("locallyErased",true)
        assertEquals(WatchProtocol.Decision.REJECT,WatchProtocol.decide(erased,snapshot(),true))
        assertEquals(WatchProtocol.Decision.REPLACE,WatchProtocol.decide(erased,snapshot(2),true))
    }
    @Test fun anotherPhoneRequiresExplicitReset() {
        assertEquals(WatchProtocol.Decision.REJECT,WatchProtocol.decide(snapshot(),snapshot(2,"phone-b"),true))
        assertEquals(WatchProtocol.Decision.REJECT,WatchProtocol.decide(snapshot(),snapshot(2),false))
        val reset = snapshot().put("allowNewOwner",true).put("locallyErased",true)
        assertEquals(WatchProtocol.Decision.REPLACE,WatchProtocol.decide(reset,snapshot(1,"phone-b"),false))
        assertEquals(WatchProtocol.Decision.REJECT,WatchProtocol.decide(reset,snapshot(),true))
    }
    @Test fun malformedGridIsRejectedBeforePersistence() {
        val invalid = snapshot().put("cards",org.json.JSONArray().put(JSONObject(
            """{"id":"a","name":"Test","code":"001","favorite":false,"width":10,"height":10,"bits":"000"}""")))
        assertThrows(IllegalArgumentException::class.java) { WatchProtocol.parse(invalid.toString()) }
    }
    @Test fun leadingZeroesAndBitmapArePreserved() {
        val raw = """{"schema":1,"owner":"a","revision":1,"cards":[{"id":"a","name":"Test","code":"001","favorite":true,"width":4,"height":1,"bits":"a"}]}"""
        val card = WatchProtocol.parse(raw).getJSONArray("cards").getJSONObject(0)
        assertEquals("001",card.getString("code"))
        assertEquals("a",card.getString("bits"))
    }
}

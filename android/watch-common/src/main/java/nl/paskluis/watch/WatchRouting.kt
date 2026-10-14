package nl.paskluis.watch

/** Addressed paths keep legacy clients and other watches out of a transfer. */
object WatchRouting {
    fun path(device: String): String {
        require(device.isNotBlank() && !device.contains('/'))
        return WatchProtocol.PATH+"/device/"+device
    }
    fun accepts(path: String?, localDevice: String): Boolean = path == WatchRouting.path(localDevice)
    fun acceptsAck(source: String?, selected: String?): Boolean =
        !selected.isNullOrBlank() && source == selected
}

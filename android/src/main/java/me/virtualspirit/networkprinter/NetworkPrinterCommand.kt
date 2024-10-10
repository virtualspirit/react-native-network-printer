package me.virtualspirit.networkprinter

enum class NetworkPrinterCommand(val value: Int) {
    BOLD(1),
    UNBOLD(2),
    ALIGN_LEFT(3),
    ALIGN_CENTER(4),
    ALIGN_RIGHT(5);

    companion object {
        fun fromValue(value: Int): NetworkPrinterCommand? {
            return values().find { it.value == value }
        }
    }
}
package me.virtualspirit.networkprinter


import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import net.posprinter.IConnectListener
import net.posprinter.POSConnect
import net.posprinter.POSConst
import net.posprinter.POSPrinter
import net.posprinter.model.PTable

class NetworkPrinterModule(reactContext: ReactApplicationContext?) :
    ReactContextBaseJavaModule(reactContext) {

    private var printDatas = mutableListOf<Any>()
    private var printDensity = POSConst.SINGLE_DENSITY_8
    private var hasPrinterListener = false
    private var hasScanListener = false
    private var PRINTER_EVENT = "NetworkPrinteEvent"
    private var SCAN_EVENT = "PrinterFound"

    override fun getName(): String {
        return "NetworkPrinter"
    }

    init {
        POSConnect.init(reactApplicationContext)
    }

    @ReactMethod
    fun addListener(eventName: String) {
        if (eventName.equals(PRINTER_EVENT)) {
            hasPrinterListener = true
        }
        if (eventName.equals(SCAN_EVENT)) {
            hasScanListener = true
        }
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        hasPrinterListener = false
        hasScanListener = false
    }

    @ReactMethod
    fun setTextData(data: ReadableMap) {
        printDatas.add(data)
    }

    @ReactMethod
    fun setBase64Image(data: ReadableMap) {
        printDatas.add(data)
    }

    @ReactMethod
    fun addNewLine(line: Int) {
        printDatas.add("line-$line")
    }

    @ReactMethod
    fun setColumn(data: ReadableMap) {
        val columns = data.getArray("column") as? Array<String>
        val columnWidth = data.getArray("columnWidth") as? Array<Int>
        val align = columns?.mapIndexed { index, _ ->
            if (index == 0) {
                0
            } else {
                1
            }
        } as Array<Int>
        val table = PTable(columns, columnWidth, align)
        printDatas.add(table)
    }

    @ReactMethod
    fun printWithHost(host: String, promise: Promise) {
        val curConnection = POSConnect.createDevice(POSConnect.DEVICE_TYPE_ETHERNET)
        curConnection.setSendCallback {
            runBlocking {
                delay(300)
                curConnection.close()
                delay(300)
                printDatas = mutableListOf<Any>()
                val params = Arguments.createMap().apply {
                    putString("status", "success")
                    putString("message", "print success")
                }
                promise.resolve(params)
            }
        }

        curConnection.connect(host, IConnectListener { code, connInfo, msg ->
            Log.d("CEK INI", code.toString())
            Log.d("CEK INI", connInfo)
            Log.d("CEK INI", msg)
            when (code) {
                POSConnect.CONNECT_SUCCESS -> {
                    val printer = POSPrinter(curConnection);
                    var printInstance = printer.initializePrinter()
                    printDatas.forEach { printData ->
                        if (printData is PTable) {
                            val data: PTable = printData as PTable
                            printInstance = printInstance.printTable(data)
                        }

                        if (printData is String) {
                            val data: String = printData as String
                            if (data.startsWith("line-")) {
                                val regex = Regex("line-(\\d+)")
                                val match = regex.find(data)
                                val number = match?.groups?.get(1)?.value?.toInt()
                                printInstance = number?.let { printInstance.feedLine(it) }
                            }
                        }

                        if (printData is ReadableMap) {
                            val data: ReadableMap = printData as ReadableMap
                            if (data.hasKey("text")) {
                                var width = POSConst.TXT_1WIDTH
                                var height = POSConst.TXT_1HEIGHT
                                var align = POSConst.ALIGNMENT_LEFT
                                var bold = POSConst.FNT_DEFAULT
                                val text = data.getString("text")

                                if (data.hasKey("width")) {
                                    width = getWidth(data.getInt("width"))
                                }

                                if (data.hasKey("height")) {
                                    height = getHeight(data.getInt("height"))
                                }

                                if (data.hasKey("align")) {
                                    align = getAlign(data.getInt("align"))
                                }

                                if (data.hasKey("bold")) {
                                    bold = getBold(data.getInt("bold"))
                                }

                                printInstance = printInstance.printText("${text}\n", align, bold or printDensity, width or height )
                            }

                            if (data.hasKey("image")) {
                                val base64 = data.getString("image")
                                val decodedString: ByteArray = Base64.decode(base64, Base64.DEFAULT)
                                val bmp = BitmapFactory.decodeByteArray(decodedString, 0, decodedString.size)

                                var width = 300
                                var align = POSConst.ALIGNMENT_LEFT

                                if (data.hasKey("align")) {
                                    align = getAlign(data.getInt("align"))
                                }

                                if (data.hasKey("width")) {
                                    width = data.getInt("width")
                                }

                                printInstance = printInstance.printBitmap(bmp, align, width)
                            }
                        }
                    }
                    printInstance = printInstance.feedLine(7)
                    printInstance = printInstance.cutPaper()
                }
                POSConnect.CONNECT_FAIL -> {
                    printDatas = mutableListOf<Any>()
                    promise.reject("timeout", msg)
                }
                POSConnect.CONNECT_INTERRUPT -> {
                    printDatas = mutableListOf<Any>()
                    promise.reject("connection_refused", msg)
                }
                POSConnect.SEND_FAIL -> {
                    printDatas = mutableListOf<Any>()
                    promise.reject("print-failure", msg)
                }
            }
        })
    }

    @ReactMethod
    fun openCashWithHost(host: String, promise: Promise) {
        val curConnection = POSConnect.createDevice(POSConnect.DEVICE_TYPE_ETHERNET)
        curConnection.connect(host, IConnectListener { code, connInfo, msg ->
            when (code) {
                POSConnect.CONNECT_SUCCESS -> {
                    val params = Arguments.createMap().apply {
                        putString("status", "success")
                        putString("message", "print success")
                    }
                    val printer = POSPrinter(curConnection);
                    val printInstance = printer.initializePrinter()
                    printInstance.openCashBox(POSConst.PIN_TWO)
                    curConnection.close()
                    promise.resolve(params)
                }
                POSConnect.CONNECT_FAIL -> {
                    promise.reject("connection_refused", msg)
                }
                POSConnect.CONNECT_INTERRUPT -> {
                    promise.reject("timeout", msg)
                }
            }
        })
    }

    @ReactMethod
    fun setDensity(density: Int) {
        printDensity = when (density) {
            1 -> POSConst.SINGLE_DENSITY_8
            2 -> POSConst.SINGLE_DENSITY_24
            3 -> POSConst.DOUBLE_DENSITY_8
            4 -> POSConst.DOUBLE_DENSITY_24
            else -> POSConst.SINGLE_DENSITY_8 // Default value for unknown densities
        }
    }

    fun getWidth(width: Int): Int {
        return when (width) {
            1 -> POSConst.TXT_1WIDTH
            2 -> POSConst.TXT_2WIDTH
            3 -> POSConst.TXT_3WIDTH
            4 -> POSConst.TXT_4WIDTH
            5 -> POSConst.TXT_5WIDTH
            6 -> POSConst.TXT_6WIDTH
            7 -> POSConst.TXT_7WIDTH
            8 -> POSConst.TXT_8WIDTH
            else -> POSConst.TXT_1WIDTH
        }
    }

    fun getHeight(height: Int): Int {
        return when (height) {
            1 -> POSConst.TXT_1HEIGHT
            2 -> POSConst.TXT_2HEIGHT
            3 -> POSConst.TXT_3HEIGHT
            4 -> POSConst.TXT_4HEIGHT
            5 -> POSConst.TXT_5HEIGHT
            6 -> POSConst.TXT_6HEIGHT
            7 -> POSConst.TXT_7HEIGHT
            8 -> POSConst.TXT_8HEIGHT
            else -> POSConst.TXT_1HEIGHT
        }
    }

    fun getAlign(align: Int): Int {
        return when (NetworkPrinterCommand.fromValue(align)) {
            NetworkPrinterCommand.ALIGN_LEFT -> POSConst.ALIGNMENT_LEFT
            NetworkPrinterCommand.ALIGN_CENTER -> POSConst.ALIGNMENT_CENTER
            NetworkPrinterCommand.ALIGN_RIGHT -> POSConst.ALIGNMENT_RIGHT
            else -> POSConst.ALIGNMENT_LEFT
        }
    }

    fun getBold(align: Int): Int {
        return when (NetworkPrinterCommand.fromValue(align)) {
            NetworkPrinterCommand.BOLD -> POSConst.FNT_BOLD
            NetworkPrinterCommand.UNBOLD -> POSConst.FNT_DEFAULT
            else -> POSConst.ALIGNMENT_LEFT
        }
    }

    private fun sendEvent(reactContext: ReactContext, eventName: String, params: WritableMap?) {
        if ((eventName.equals(PRINTER_EVENT) && hasPrinterListener) || (eventName.equals(SCAN_EVENT) && hasScanListener)) {
            reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit(eventName, params)
        }
    }
}
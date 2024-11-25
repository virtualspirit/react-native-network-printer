package me.virtualspirit.networkprinter

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import net.posprinter.POSConnect
import net.posprinter.model.PTable

class NetworkPrinterModule(reactContext: ReactApplicationContext?) :
    ReactContextBaseJavaModule(reactContext) {

    private var connectedPrinterList = mutableListOf<NPrinter>()

    private var hasPrinterListener = false
    private var hasScanListener = false
    val PRINTER_EVENT = "NetworkPrinterEvent"
    val SCAN_EVENT = "PrinterFound"

    override fun getName(): String {
        return "NetworkPrinter"
    }

    init {
        POSConnect.init(reactApplicationContext)
    }

    @ReactMethod
    fun initWithHost(host: String) {
      var isExistPrinter = false
      for (nPrinter: NPrinter in connectedPrinterList) {
        if (nPrinter.host.equals(host)) {
          isExistPrinter = true
        }
      }

      if (!isExistPrinter) {
        val sendEvent: (WritableMap?) -> Unit = { params ->
          if (hasPrinterListener) {
            reactApplicationContext
              .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
              .emit(PRINTER_EVENT, params)
          }
        }

        val nPrinter: NPrinter = NPrinter(host, sendEvent)
        connectedPrinterList.add(nPrinter)
      }
    }

    @ReactMethod
    fun connect(host: String) {
      getPrinterWithHost(host)?.connect()
    }

    @ReactMethod
    fun disconnect(host: String) {
      getPrinterWithHost(host)?.disconnect()
    }

    @ReactMethod
    fun setTextData(data: ReadableMap, host: String) {
      getPrinterWithHost(host)?.appendData(data)
    }

    @ReactMethod
    fun setBase64Image(data: ReadableMap, host: String) {
      getPrinterWithHost(host)?.appendData(data)
    }

    @ReactMethod
    fun addNewLine(line: Int, host: String) {
      getPrinterWithHost(host)?.appendData("line-$line")
    }

    @ReactMethod
    fun setColumn(data: ReadableMap, host: String) {
      val columns = data.getArray("column")
      val columnWidth = data.getArray("columnWidth")

      val columnArr: Array<String>? = columns?.let {
        Array(it.size()) { index -> it.getString(index) }  // default to "" for null values
      }

      val columnWidthArr: Array<Int>? = columnWidth?.let {
        Array(it.size()) { index -> it.getInt(index) }  // default to "" for null values
      }

      var bold = NetworkPrinterCommand.UNBOLD.value
      var width = 0
      var height = 0
      var align = NetworkPrinterCommand.TABLE_ALIGN_FIRST_LEFT.value

      if (data.hasKey("width")) {
        width = data.getInt("width")
      }

      if (data.hasKey("height")) {
        height = data.getInt("height")
      }

      if (data.hasKey("align")) {
        align = data.getInt("align")
      }

      if (data.hasKey("bold")) {
        bold = data.getInt("bold")
      }

      val columnAlign: Array<Int>? = columnWidth?.let {
        Array(it.size()) { index ->
          if (align == NetworkPrinterCommand.TABLE_ALIGN_ALL_LEFT.value) {
            0
          } else if (align == NetworkPrinterCommand.TABLE_ALIGN_ALL_RIGHT.value) {
            1
          } else {
            if (index == 0) {
              0
            } else {
              1
            }
          }
        }
      }

      val tableStyle = PTableStyle(bold, width, height);
      getPrinterWithHost(host)?.appendData(tableStyle)
      val table = PTable(columnArr, columnWidthArr, columnAlign)
      getPrinterWithHost(host)?.appendData(table)
    }

    @ReactMethod
    fun printWithHost(host: String, promise: Promise) {
      getPrinterWithHost(host)?.print(promise)
    }

    @ReactMethod
    fun openCashWithHost(host: String, promise: Promise) {
      getPrinterWithHost(host)?.openCashBox(promise)
    }

  @ReactMethod
  fun setDensity(density: Int, host: String) {
    getPrinterWithHost(host)?.setDensity(density)
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

  public fun sendEvent(eventName: String, params: WritableMap?) {
    if ((eventName.equals(PRINTER_EVENT) && hasPrinterListener) || (eventName.equals(SCAN_EVENT) && hasScanListener)) {
      reactApplicationContext
        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
        .emit(eventName, params)
    }
  }

  private fun getPrinterWithHost(host: String): NPrinter? {
    for (nPrinter: NPrinter in connectedPrinterList) {
      if (nPrinter.host.equals(host)) {
        return nPrinter;
      }
    }

    return null
  }
}

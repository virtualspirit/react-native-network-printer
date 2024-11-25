package me.virtualspirit.networkprinter


import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import net.posprinter.IConnectListener
import net.posprinter.IDeviceConnection
import net.posprinter.POSConnect
import net.posprinter.POSConst
import net.posprinter.POSPrinter
import net.posprinter.model.PTable
import kotlinx.coroutines.*

public class PTableStyle(val isBold: Int, val width: Int, val height: Int) {}

class NPrinter(val host: String, val sendEvent: (params: WritableMap?) -> Unit
) {
  private var printData = mutableListOf<Any>()
  lateinit var  printerConnecter: IDeviceConnection
  var promise: Promise? = null
  private var printDensity = POSConst.SINGLE_DENSITY_8
  private var isPrintSuccess: Boolean = false
  private var isConnectAndPrint: Boolean = false
  private var isConnected: Boolean = false

  fun appendData(data: ReadableMap) {
    printData.add(data)
  }

  fun appendData(data: String) {
    printData.add(data)
  }

  fun appendData(data: PTable) {
    printData.add(data)
  }

  fun appendData(data: PTableStyle) {
    printData.add(data)
  }

  private fun sendSuccessPromise() {
    val params = Arguments.createMap().apply {
      putString("status", "success")
      putString("message", "print success")
    }

    if (promise != null) {
      promise?.resolve(params)
      promise = null
    }
  }

  private fun sendErrorPromise(type: String, message: String) {
    printData.clear()

    if (promise != null) {
      promise?.reject(type, message)
      promise = null
    }
  }


  fun connect(callback: (() -> Unit)? = null) {
    isPrintSuccess = false
    printerConnecter = POSConnect.createDevice(POSConnect.DEVICE_TYPE_ETHERNET)
    printerConnecter.connect(host, IConnectListener { code, connInfo, msg ->
      when (code) {
        POSConnect.CONNECT_SUCCESS -> {
          isConnected = true

          val params = Arguments.createMap().apply {
            putString("type", "connected")
            putString("host", host)
            putString("message", "success")
          }
          sendEvent(params)

          printerConnecter.setSendCallback {
            GlobalScope.launch {
              val params = Arguments.createMap().apply {
                putString("type", "print-success")
                putString("host", host)
                putString("message", "print success")
              }
              sendEvent(params)
              isPrintSuccess = true;
              printData.clear()
              delay(100)
              if (isConnectAndPrint) {
                disconnect()
                delay(200)
              }
              sendSuccessPromise()
            }
          }

          callback?.invoke()
        }
        POSConnect.CONNECT_FAIL -> {
          isConnected = false

          if (!isPrintSuccess) {
            sendErrorPromise("timeout", msg)

            val params = Arguments.createMap().apply {
              putString("type", "disconnected")
              putString("host", host)
              putString("message", msg)
            }
            sendEvent(params)
          }
        }
        POSConnect.CONNECT_INTERRUPT -> {
          isConnected = false

          if (!isPrintSuccess) {
            sendErrorPromise("connection-refused", msg)

            val params = Arguments.createMap().apply {
              putString("type", "disconnected")
              putString("host", host)
              putString("message", msg)
            }
            sendEvent(params)
          }
        }
        POSConnect.SEND_FAIL -> {
          isPrintSuccess = false
          sendErrorPromise("print-failure", msg)

          val params = Arguments.createMap().apply {
            putString("type", "print-failure")
            putString("host", host)
            putString("message", msg)
          }
          sendEvent(params)
        }
      }
    })
  }

  fun disconnect() {
    if (isConnected) {
      printerConnecter.closeSync()
      val params = Arguments.createMap().apply {
        putString("type", "disconnected")
        putString("host", host)
        putString("message", "connection disconnected")
      }
      sendEvent(params)
    }
  }


  fun print(promise: Promise) {
    this.promise = promise
    if (isConnected) {
      isConnectAndPrint = false
      this.doPrint()
    } else {
      isConnectAndPrint = true
      this.connect {
        this.doPrint()
      }
    }
  }

  fun doPrint() {
    var printer = POSPrinter(printerConnecter).initializePrinter()
    for (data in printData) {
      if (data is PTableStyle) {
        val width = getWidth(data.width)
        val height = getHeight(data.height)
        val bold = getBold(data.isBold)
        printer = printer.setTextStyle(bold, width or height)
      }

      if (data is PTable) {
        printer = printer.setAlignment(POSConst.ALIGNMENT_CENTER)
        printer = printer.printTable(data)
      }

      if (data is String) {
        if (data.startsWith("line-")) {
          val regex = Regex("line-(\\d+)")
          val match = regex.find(data)
          val number = match?.groups?.get(1)?.value?.toInt()
          printer = number?.let { printer.feedLine(it) }
        }
      }

      if (data is ReadableMap) {
        if (data.hasKey("text")) {
          var width = 0
          var height = 0
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

          printer = printer.printText("${text}\n", align, bold or printDensity, width or height )
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

          printer = printer.feedLine()
          printer = printer.printBitmap(bmp, align, width)
          printer = printer.feedLine()
        }
      }
    }

    printer = printer.feedLine(6)
    printer = printer.cutPaper()
  }

  fun openCashBox(promise: Promise) {
    this.promise = promise
    this.connect {
      POSPrinter(printerConnecter).initializePrinter().openCashBox(POSConst.PIN_TWO)
    }
  }

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
      1 -> 16
      2 -> 32
      3 -> 48
      4 -> 64
      5 -> 80
      6 -> 96
      7 -> 112
      8 -> 128
      else -> 0
    }
  }

  fun getHeight(height: Int): Int {
    return when (height) {
      1 -> 1
      2 -> 2
      3 -> 3
      4 -> 4
      5 -> 5
      6 -> 6
      7 -> 7
      8 -> 8
      else -> 0
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
}

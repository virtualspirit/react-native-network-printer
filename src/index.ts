import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

const NetworkPrinter = NativeModules.NetworkPrinter;
const NetworkPrinterEventEmitter = new NativeEventEmitter(NetworkPrinter);

interface IQueue {
  host: string;
  done: (value?: unknown) => void;
}
let PRINT_QUEUE: IQueue[] = [];

let PRINTING_HOSTS: Set<string> = new Set();

const handlePrintQueue = (host: string) => {
  PRINTING_HOSTS.delete(host);
  const index = PRINT_QUEUE.findIndex((val) => val.host === host);
  if (index !== -1) {
    PRINT_QUEUE[index]?.done();
    PRINT_QUEUE.splice(index, 1)[0];
  }
};

export enum NETWORK_PRINTER_COMMAND {
  BOLD = 1,
  UNBOLD = 2,
  ALIGN_LEFT = 3,
  ALIGN_CENTER = 4,
  ALIGN_RIGHT = 5,
  TABLE_ALIGN_ALL_LEFT = 6,
  TABLE_ALIGN_ALL_RIGHT = 7,
  TABLE_ALIGN_FIRST_LEFT = 8,
}

enum PRINT_DATA_TYPE {
  density,
  text,
  raw,
  base64,
  column,
  newline,
}

const NETWORK_PRINTER_EVENT = {
  PRINTER_EVENT: 'NetworkPrinterEvent',
  SCAN_EVENT: 'PrinterFound',
};

interface IPrintData {
  type: PRINT_DATA_TYPE;
  value: any;
}

interface ISetText {
  text: string;
  bold?: NETWORK_PRINTER_COMMAND.BOLD | NETWORK_PRINTER_COMMAND.UNBOLD;
  align?:
    | NETWORK_PRINTER_COMMAND.ALIGN_CENTER
    | NETWORK_PRINTER_COMMAND.ALIGN_LEFT
    | NETWORK_PRINTER_COMMAND.ALIGN_RIGHT;
  width?: number;
  height?: number;
}

interface ISetBase64 {
  align?:
    | NETWORK_PRINTER_COMMAND.ALIGN_CENTER
    | NETWORK_PRINTER_COMMAND.ALIGN_LEFT
    | NETWORK_PRINTER_COMMAND.ALIGN_RIGHT;
  image: string;
}

type ColumAlignType =
  | NETWORK_PRINTER_COMMAND.TABLE_ALIGN_ALL_LEFT
  | NETWORK_PRINTER_COMMAND.TABLE_ALIGN_ALL_RIGHT
  | NETWORK_PRINTER_COMMAND.TABLE_ALIGN_FIRST_LEFT;

interface ISetColumn {
  column: string[];
  columnWidth: number[];
  width?: number;
  height?: number;
  tableAlign?: ColumAlignType;
  bold?: NETWORK_PRINTER_COMMAND.BOLD | NETWORK_PRINTER_COMMAND.UNBOLD;
}

interface IFoundPrinter {
  ip: string;
  gateway: string;
}

export type PrintingStatusType =
  | 'printing'
  | 'printed'
  | 'retry'
  | 'queue'
  | 'failure';

export type IPrinterEventType =
  | 'connected'
  | 'disconnected'
  | 'print-success'
  | 'print-failure';

export interface IPrinterEvent {
  type: IPrinterEventType;
  host: string;
  message: string;
}

interface IPrintError {
  code: string;
  message: string;
}

const MAX_RETRIES = 10;

export const scanNetwork = () => {
  if (Platform.OS === 'android') {
    console.warn('Android not implemented yet');
    return;
  }
  NetworkPrinter.scanNetwork();
};

export const stopScanNetwork = () => {
  if (Platform.OS === 'android') {
    console.warn('Android not implemented yet');
    return;
  }
  NetworkPrinter.stopScan();
};

export const printerEventListener = (
  listener: (res: IPrinterEvent) => void
) => {
  return NetworkPrinterEventEmitter.addListener(
    NETWORK_PRINTER_EVENT.PRINTER_EVENT,
    listener
  );
};

export const scanNetworkListener = (listener: (res: IFoundPrinter) => void) => {
  if (Platform.OS === 'android') {
    console.warn('Android not implemented yet');
    return {};
  }
  return NetworkPrinterEventEmitter.addListener(
    NETWORK_PRINTER_EVENT.SCAN_EVENT,
    listener
  );
};

interface IRNNetworkPrinterCallback {
  onStart?: () => void;
  onDone?: () => void;
  onError?: (error: IPrintError) => void;
  onStatusChanged?: (status: PrintingStatusType) => void;
}

class RNNetworkPrinter {
  host: string;
  printData: IPrintData[] = [];
  callback?: IRNNetworkPrinterCallback = undefined;

  constructor(host: string, callback?: IRNNetworkPrinterCallback) {
    this.host = host;
    this.callback = callback;
  }

  connect = () => {
    NetworkPrinter.initWithHost(this.host);
    NetworkPrinter.connect(this.host);
  };

  disconnect = () => {
    NetworkPrinter.disconnect(this.host);
  };

  setDensity = (density: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8) => {
    if (density >= 1 && density <= 8) {
      this.printData.push({ type: PRINT_DATA_TYPE.density, value: density });
    } else {
      console.warn('INVALID_DENSITY_VALUE');
    }
  };

  setTextData = (printData: ISetText) => {
    this.printData.push({ type: PRINT_DATA_TYPE.text, value: printData });
  };

  setBase64Image = (printData: ISetBase64) => {
    this.printData.push({ type: PRINT_DATA_TYPE.base64, value: printData });
  };

  setColumn = (printData: ISetColumn) => {
    this.printData.push({ type: PRINT_DATA_TYPE.column, value: printData });
  };

  addNewLine = (count: number = 1) => {
    this.printData.push({ type: PRINT_DATA_TYPE.newline, value: count });
  };

  print = async () => {
    if (PRINTING_HOSTS.has(this.host)) {
      if (typeof this.callback?.onStatusChanged === 'function') {
        this.callback?.onStatusChanged('queue');
      }
      await new Promise((resolve) => {
        PRINT_QUEUE.push({ host: this.host, done: resolve });
      });
    }

    PRINTING_HOSTS.add(this.host);
    if (typeof this.callback?.onStart === 'function') {
      this.callback.onStart();
    }

    return this.printWithHost();
  };

  openCashDrawer = async () => {
    if (PRINTING_HOSTS.has(this.host)) {
      await new Promise((resolve) => {
        PRINT_QUEUE.push({ host: this.host, done: resolve });
      });
    }

    PRINTING_HOSTS.add(this.host);
    if (typeof this.callback?.onStart === 'function') {
      this.callback.onStart();
    }

    return this.openCashWithHost();
  };

  private printWithHost = (retryCount = 0) => {
    NetworkPrinter.initWithHost(this.host);

    for (let i = 0; i < this.printData.length; i++) {
      const data = this.printData[i];
      switch (data?.type) {
        case PRINT_DATA_TYPE.density: {
          NetworkPrinter.setDensity(data.value, this.host);
          break;
        }
        case PRINT_DATA_TYPE.base64: {
          NetworkPrinter.setBase64Image(data.value, this.host);
          break;
        }
        case PRINT_DATA_TYPE.column: {
          NetworkPrinter.setColumn(data.value, this.host);
          break;
        }
        case PRINT_DATA_TYPE.newline: {
          NetworkPrinter.addNewLine(data.value, this.host);
          break;
        }
        case PRINT_DATA_TYPE.raw: {
          NetworkPrinter.setRawData(data.value, this.host);
          break;
        }
        case PRINT_DATA_TYPE.text: {
          NetworkPrinter.setTextData(data.value, this.host);
          break;
        }
        default: {
          break;
        }
      }
    }

    return new Promise((resolve, reject) => {
      if (typeof this.callback?.onStatusChanged === 'function') {
        this.callback?.onStatusChanged('printing');
      }
      NetworkPrinter.printWithHost(this.host)
        .then((res: any) => {
          if (typeof this.callback?.onDone === 'function') {
            this.callback.onDone();
          }
          if (typeof this.callback?.onStatusChanged === 'function') {
            this.callback?.onStatusChanged('printed');
          }
          this.printData = [];
          resolve(res);
          handlePrintQueue(this.host);
        })
        .catch((err: IPrintError) => {
          if (retryCount < MAX_RETRIES) {
            if (typeof this.callback?.onStatusChanged === 'function') {
              this.callback?.onStatusChanged('retry');
            }
            setTimeout(() => {
              this.printWithHost(retryCount + 1)
                .then(resolve)
                .catch(reject);
            }, 1000);
          } else {
            if (typeof this.callback?.onError === 'function') {
              this.callback.onError(err);
            }
            if (typeof this.callback?.onStatusChanged === 'function') {
              this.callback?.onStatusChanged('failure');
            }
            this.printData = [];
            reject(err);
            handlePrintQueue(this.host);
          }
        });
    });
  };

  private openCashWithHost = (retryCount = 0) => {
    NetworkPrinter.initWithHost(this.host);

    return new Promise((resolve, reject) => {
      NetworkPrinter.openCashWithHost(this.host)
        .then((res: any) => {
          handlePrintQueue(this.host);
          resolve(res);
        })
        .catch((err: IPrintError) => {
          if (retryCount < MAX_RETRIES) {
            setTimeout(() => {
              this.openCashWithHost(retryCount + 1)
                .then(resolve)
                .catch(reject);
            }, 1000);
          } else {
            if (typeof this.callback?.onError === 'function') {
              this.callback.onError(err);
            }
            this.printData = [];
            reject(err);
            handlePrintQueue(this.host);
          }
        });
    });
  };
}

export default RNNetworkPrinter;

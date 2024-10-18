import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

const NetworkPrinter = NativeModules.NetworkPrinter;
const NetworkPrinterEventEmitter = new NativeEventEmitter(NetworkPrinter);

interface IQueue {
  done: (value?: unknown) => void;
}
let PRINT_QUEUE: IQueue[] = [];

let IS_PRINTING = false;

const handlePrintQueue = () => {
  IS_PRINTING = false;

  if (PRINT_QUEUE.length > 0) {
    const queue = PRINT_QUEUE.shift();
    queue?.done();
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
  PRINTER_EVENT: 'NetworkPrinteEvent',
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

interface IPrinterEvent {
  type: string;
  connected: boolean;
  host: string;
  port: string;
  error?: string;
  errorData?: any;
}

interface IPrintError {
  code: string;
  message: string;
}

const MAX_RETRIES = 20;

export const scanNetwork = () => {
  if (Platform.OS === 'android') {
    console.warn('Android nit implemented yet');
    return;
  }
  NetworkPrinter.scanNetwork();
};

export const stopScanNetwork = () => {
  if (Platform.OS === 'android') {
    console.warn('Android nit implemented yet');
    return;
  }
  NetworkPrinter.stopScan();
};

export const printerEventListener = (
  listener: (res: IPrinterEvent) => void
) => {
  if (Platform.OS === 'android') {
    console.warn('Android nit implemented yet');
    return {};
  }
  return NetworkPrinterEventEmitter.addListener(
    NETWORK_PRINTER_EVENT.PRINTER_EVENT,
    listener
  );
};

export const scanNetworkListener = (listener: (res: IFoundPrinter) => void) => {
  if (Platform.OS === 'android') {
    console.warn('Android nit implemented yet');
    return {};
  }
  return NetworkPrinterEventEmitter.addListener(
    NETWORK_PRINTER_EVENT.SCAN_EVENT,
    listener
  );
};

class RNNetworkPrinter {
  host?: string;
  printData: IPrintData[] = [];

  constructor(host: string) {
    this.host = host;
  }

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
    if (IS_PRINTING) {
      await new Promise((resolve) => {
        PRINT_QUEUE.push({ done: resolve });
      });
    }

    IS_PRINTING = true;

    return this.doPrint();
  };

  openCashDrawer = async () => {
    if (IS_PRINTING) {
      await new Promise((resolve) => {
        PRINT_QUEUE.push({ done: resolve });
      });
    }

    IS_PRINTING = true;

    return this.openCashWithHost();
  };

  private doPrint = async () => {
    for (let i = 0; i < this.printData.length; i++) {
      const data = this.printData[i];
      switch (data?.type) {
        case PRINT_DATA_TYPE.density: {
          NetworkPrinter.setDensity(data.value);
          break;
        }
        case PRINT_DATA_TYPE.base64: {
          NetworkPrinter.setBase64Image(data.value);
          break;
        }
        case PRINT_DATA_TYPE.column: {
          NetworkPrinter.setColumn(data.value);
          break;
        }
        case PRINT_DATA_TYPE.newline: {
          NetworkPrinter.addNewLine(data.value);
          break;
        }
        case PRINT_DATA_TYPE.raw: {
          NetworkPrinter.setRawData(data.value);
          break;
        }
        case PRINT_DATA_TYPE.text: {
          NetworkPrinter.setTextData(data.value);
          break;
        }
        default: {
          break;
        }
      }
    }

    return this.printWithHost();
  };

  private printWithHost = (retryCount = 0) => {
    return new Promise((resolve, reject) => {
      NetworkPrinter.printWithHost(this.host)
        .then((res: any) => {
          this.printData = [];
          handlePrintQueue();
          resolve(res);
        })
        .catch((err: IPrintError) => {
          if (err.code === 'timeout' && retryCount < MAX_RETRIES) {
            setTimeout(() => {
              this.printWithHost(retryCount + 1)
                .then(resolve)
                .catch(reject);
            }, 1000);
          } else {
            this.printData = [];
            handlePrintQueue();
            reject(err);
          }
        });
    });
  };

  private openCashWithHost = (retryCount = 0) => {
    return new Promise((resolve, reject) => {
      NetworkPrinter.openCashWithHost(this.host)
        .then((res: any) => {
          handlePrintQueue();
          resolve(res);
        })
        .catch((err: IPrintError) => {
          if (err.code === 'timeout' && retryCount < MAX_RETRIES) {
            setTimeout(() => {
              this.openCashWithHost(retryCount + 1)
                .then(resolve)
                .catch(reject);
            }, 1000);
          } else {
            handlePrintQueue();
            reject(err);
          }
        });
    });
  };
}

export default RNNetworkPrinter;

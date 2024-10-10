# react-native-network-printer

React Native Network Printer Liblary

## Installation

```sh
npm install @virtualspirit/react-native-network-printer
```

## Usage


```js
import RNNetworkPrinter, { NETWORK_PRINTER_COMMAND } from 'react-native-network-printer';

// ...
const printer = new RNNetworkPrinter('192.168.1.13');
printer.setTextData({
  text: '------------------------------------------------',
  bold: NETWORK_PRINTER_COMMAND.BOLD,
  align: NETWORK_PRINTER_COMMAND.ALIGN_CENTER,
});
for(let i = 0; i < 10; i++) {
  printer.setTextData({
    text: 'Test Printer',
    bold: NETWORK_PRINTER_COMMAND.BOLD,
    align: NETWORK_PRINTER_COMMAND.ALIGN_CENTER,
  });

}
printer.setTextData({
  text: '------------------------------------------------',
  bold: NETWORK_PRINTER_COMMAND.BOLD,
  align: NETWORK_PRINTER_COMMAND.ALIGN_CENTER,
});
printer.print().then(res => {
  console.log('FUNC_RES', res);
}).catch(err => {
  console.log('FUNC_ERR', err);
});
```


## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

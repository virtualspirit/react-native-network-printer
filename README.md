# react-native-network-printer

React Native Network Printer Liblary

## Before you install
If you haven't installed any GitHub package before, please follow this steps.
1. Adding your GitHub personal access token. [Github Doc](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry#authenticating-with-a-personal-access-token)
2. Update your `.npmrc` file look like this

```
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN
@virtualspirit:registry=https://npm.pkg.github.com
```



## Installation

```sh
npm install @virtualspirit/react-native-network-printer
```

## Android Extra Steps
add this steps to android project `/android/app/build.gradle`
```
repositories {
    flatDir {
        dirs '../../node_modules/@virtualspirit/react-native-network-printer/android/libs'
    }
}

dependencies {
    implementation(name: 'printer-lib-3.2.0', ext: 'aar')  
}
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

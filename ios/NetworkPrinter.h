//
//  NetworkPrinter.h
//
//  Created by Rahmat Zulfikri on 08/10/24.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "POSPrinterSDK.h"
#import "PTable.h"

@interface NetworkPrinter : RCTEventEmitter <POSWIFIManagerDelegate> {
  POSWIFIManager *_networkManager;
  NSMutableData *dataM;
  
  BOOL isPrintWithHost;
  BOOL isPrintFinish;
  BOOL isPrintSuccess;
  NSError *printErrorData;
  RCTPromiseResolveBlock printResolver;
  RCTPromiseRejectBlock printRejector;
}

@end

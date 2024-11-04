//
//  NetworkPrinter.h
//
//  Created by Rahmat Zulfikri on 08/10/24.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "POSPrinterSDK.h"
#import "WIFIConnecter.h"
#import "PTable.h"
#import "NPrinter.h"

@interface NetworkPrinter : RCTEventEmitter {
  NSMutableArray<NPrinter *> *connectedPrinterList;
}

@end

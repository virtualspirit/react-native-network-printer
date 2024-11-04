//
//  Printer.h
//  Pods
//
//  Created by Rahmat Zulfikri on 04/11/24.
//

#import <Foundation/Foundation.h>
#import "WIFIConnecter.h"
#import "POSPrinterSDK.h"
#import <React/RCTBridgeModule.h>

@interface NPrinter : NSObject <WIFIConnecterDelegate>

// Properties
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSMutableData *printData;
@property (nonatomic, strong) WIFIConnecter *printerConnecter;
@property (nonatomic, strong) RCTPromiseResolveBlock printResolver;
@property (nonatomic, strong) RCTPromiseRejectBlock printRejector;

// Methods
- (instancetype)initWithHost:(NSString *)host;
- (void)appendData:(NSData *)data;
- (void)connect;
- (void)disconnect;
- (void)print;
- (void)addPromise:(RCTPromiseResolveBlock)resolve rejector:(RCTPromiseRejectBlock)reject;
@end

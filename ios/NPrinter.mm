//
//  Printer.mm
//  Pods
//
//  Created by Rahmat Zulfikri on 04/11/24.
//

#import "NPrinter.h"

@implementation NPrinter

BOOL isPrintSuccess = NO;
NSError *printError;
BOOL isConnectAndPrint = NO;
BOOL isConnected = NO;

SendEventBlock sendEventBlock;

// Initializer method
- (instancetype)initWithHost:(NSString *)host sendEventBlock:(SendEventBlock)block {
    self = [super init];
    if (self) {
      _host = host;
      _printData = [NSMutableData dataWithData:[POSCommand initializePrinter]];
      _printerConnecter = [[WIFIConnecter alloc] init];
      _printerConnecter.delegate = self;
      
      sendEventBlock = block;
    }
    return self;
}

- (void)sendEvent:(NSDictionary *)params {
    if (sendEventBlock) {
        sendEventBlock(params);
    }
}

- (void)dealloc {
    // Release any retained resources here
  [_printerConnecter removeAllDelegates];
}

- (void)appendData:(NSData *)data {
  [_printData appendData:data];
}

- (void)connect {
  [_printerConnecter connectWithHost:_host port:9100];
}

- (void)disconnect {
  dispatch_async(dispatch_get_main_queue(), ^{
    BOOL status = [self->_printerConnecter printerCheckWithMac];
    
    if (status) {
      [self->_printerConnecter disconnect];
    }
  });
}

- (void)print {
  if (isConnected) {
    isConnectAndPrint = NO;
    [self doPrint];
  } else {
    isConnectAndPrint = YES;
    [self connect];
  }
}

-(void)doPrint {
  [_printerConnecter writeCommandWithData:_printData writeCallBack:^(BOOL success, NSError *error) {
    isPrintSuccess = YES;
    printError = error;
    dispatch_time_t delaydisconect = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_after(delaydisconect, dispatch_get_main_queue(), ^{
      if (success) {
        [self sendEvent:@{@"type": @"print-success", @"host": self.host, @"message": @"print success"}];
      } else {
        [self sendEvent:@{@"type": @"print-failure", @"host": self.host, @"message": error.description}];
      }
      if (isConnectAndPrint) {
        [self disconnect];
      }
    });
  }];
}

- (void)addPromise:(RCTPromiseResolveBlock)resolve rejector:(RCTPromiseRejectBlock)reject {
  _printResolver = resolve;
  _printRejector = reject;
}

- (void)sendPrintResolver:(NSDictionary *)params {
  _printData = [NSMutableData dataWithData:[POSCommand initializePrinter]];

  if (_printResolver) {
    _printRejector = NULL;
    _printResolver(params);
    _printResolver = NULL;
  }
}

- (void)sendPrintRejector:(NSString *)type message:(NSString *)message error:(NSError *)error {
  _printData = [NSMutableData dataWithData:[POSCommand initializePrinter]];

  if (_printRejector != NULL) {
    _printResolver = NULL;
    _printRejector(type, message, error);
    _printRejector = NULL;
  }
}


# pragma WIFIConnecterDelegate
- (void)wifiPOSConnectedToHost:(NSString *)ip port:(UInt16)port mac:(NSString *)mac {

  isConnected = YES;
  isPrintSuccess = NO;
  printError = NULL;
  if (isConnectAndPrint) {
    [self doPrint];
  }
  
  [self sendEvent:@{@"type": @"connected", @"host": ip, @"message": @"success"}];
}

- (void)wifiPOSDisconnectWithError:(NSError *)error mac:(NSString *)mac ip:(NSString *)ip {
  isConnected = NO;
  NSString *errorType = @"disconnected";
  NSString *errorMessage = @"connection disconnected";

  if (error) {
    switch(error.code) {
      case 8:
      case 7:
      case 3: {
        errorType = @"timeout";
        errorMessage = @"connection timeout, host might be busy";
        break;
      }
      case 64: {
        errorType = @"invalid_host";
        errorMessage = @"could not connect to host, check your host IP";
        break;
      }
      case 61: {
        errorType = @"connection_refused";
        errorMessage = @"could not connect to host, check your host IP";
        break;
      }
      default: {
        errorType = @"error";
        errorMessage = [NSString stringWithFormat:@"%@ with code %ld", error.description, static_cast<long>(error.code)];
        break;
      }
    }
    [self sendPrintRejector:errorType message:errorMessage error:error];
  } else {
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_main_queue(), ^{
      if (isPrintSuccess == YES) {
        [self sendPrintResolver:@{@"status": @"success", @"message": @"print success"}];
      } else {
        [self sendPrintRejector:@"print-failure" message:[NSString stringWithFormat:@"%@ with code %ld", printError.description, static_cast<long>(printError.code)] error:printError];
      }
    });
  }
  
  [self sendEvent:@{@"type": @"disconnected", @"host": ip, @"message": error.description}];
}

- (void)wifiPOSWriteValueWithTag:(long)tag mac:(NSString *)mac ip:(NSString *)ip {
//
}

- (void)wifiPOSReceiveValueForData:(NSData *)data mac:(NSString *)mac ip:(NSString *)ip {
//  
}

@end

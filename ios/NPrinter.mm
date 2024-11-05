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

// Initializer method
- (instancetype)initWithHost:(NSString *)host {
    self = [super init];
    if (self) {
      _host = host;
      _printData = [NSMutableData dataWithData:[POSCommand initializePrinter]];
      _printerConnecter = [[WIFIConnecter alloc] init];
      _printerConnecter.delegate = self;
    }
    return self;
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
  [self connect];
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
  isPrintSuccess = NO;
  printError = NULL;
  [_printerConnecter writeCommandWithData:_printData writeCallBack:^(BOOL success, NSError *error) {
    isPrintSuccess = YES;
    printError = error;
    dispatch_time_t delaydisconect = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_after(delaydisconect, dispatch_get_main_queue(), ^{
      [self disconnect];
    });
  }];
}

- (void)wifiPOSDisconnectWithError:(NSError *)error mac:(NSString *)mac ip:(NSString *)ip {
  NSString *errorType = @"disconected";
  NSString *errorMessage = @"connection disconected";

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
}

- (void)wifiPOSWriteValueWithTag:(long)tag mac:(NSString *)mac ip:(NSString *)ip {
//
}

- (void)wifiPOSReceiveValueForData:(NSData *)data mac:(NSString *)mac ip:(NSString *)ip {
//  
}

@end

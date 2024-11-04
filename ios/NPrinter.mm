//
//  Printer.mm
//  Pods
//
//  Created by Rahmat Zulfikri on 04/11/24.
//

#import "NPrinter.h"

@implementation NPrinter

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
  BOOL status = [_printerConnecter printerCheckWithMac];
  
  if (status) {
    [_printerConnecter disconnect];
  }
  self->_printData = [NSMutableData dataWithData:[POSCommand initializePrinter]];
}

- (void)print {
  [self connect];
}

- (void)addPromise:(RCTPromiseResolveBlock)resolve rejector:(RCTPromiseRejectBlock)reject {
  _printResolver = resolve;
  _printRejector = reject;
}

- (void)sendPrintResolver:(NSDictionary *)params {
  if (_printResolver) {
    _printRejector = NULL;
    _printResolver(params);
    _printResolver = NULL;
  }
}

- (void)sendPrintRejector:(NSString *)type message:(NSString *)message error:(NSError *)error {
  if (_printRejector != NULL) {
    _printResolver = NULL;
    _printRejector(type, message, error);
    _printRejector = NULL;
  }
}


# pragma WIFIConnecterDelegate
- (void)wifiPOSConnectedToHost:(NSString *)ip port:(UInt16)port mac:(NSString *)mac {
  [_printerConnecter writeCommandWithData:_printData writeCallBack:^(BOOL success, NSError *error) {
    [self disconnect];
    
     if (success) {
         [self sendPrintResolver:@{@"status": @"success", @"message": @"print success"}];
     } else {
         [self sendPrintRejector:@"print-failure" message:@"failed to print, please check your printer" error:error];
     }
  }];
}

- (void)wifiPOSDisconnectWithError:(NSError *)error mac:(NSString *)mac ip:(NSString *)ip {
  NSString *errorType = @"disconected";
  NSString *errorMessage = @"connection disconected";

  if (error) {
    switch(error.code) {
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
    }
    
    [self sendPrintRejector:errorType message:errorMessage error:error];
  }
}

- (void)wifiPOSWriteValueWithTag:(long)tag mac:(NSString *)mac ip:(NSString *)ip {
//
}

- (void)wifiPOSReceiveValueForData:(NSData *)data mac:(NSString *)mac ip:(NSString *)ip {
//  
}

@end

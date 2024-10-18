//
//  NetworkPrinter.m
//
//  Created by Rahmat Zulfikri on 08/10/24.
//

#import "NetworkPrinter.h"

typedef NS_ENUM(NSInteger, NetworkPrinterCommand) {
  BOLD = 1,
  UNBOLD = 2,
  ALIGN_LEFT = 3,
  ALIGN_CENTER = 4,
  ALIGN_RIGHT = 5,
  TABLE_ALIGN_ALL_LEFT = 6,
  TABLE_ALIGN_ALL_RIGHT = 7,
  TABLE_ALIGN_FIRST_LEFT = 8,
};

NSString * EVENT_NAME = @"NetworkPrinteEvent";
NSString * SCAN_EVENT_NAME = @"PrinterFound";


@implementation NetworkPrinter
{
  bool hasListeners;
}

// Will be called when this module's first listener is added.
-(void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}

// Implement requiresMainQueueSetup
+ (BOOL)requiresMainQueueSetup {
    return YES; // Return YES if your module needs to be initialized on the main queue
}

- (NSArray<NSString *> *)supportedEvents {
  return @[EVENT_NAME, SCAN_EVENT_NAME];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _networkManager = [POSWIFIManager sharedInstance];
    _networkManager.delegate = self;
  }
  return self;
}

- (void)dealloc
{
  [_networkManager removeDelegate:self];
}

RCT_EXPORT_METHOD(setTextData:(NSDictionary *)data) {
  NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
  [self preparePrintData];

  if ([data isKindOfClass:[NSDictionary class]]) {
    if ([data objectForKey:@"text"]) {
      NSInteger height = TXT_DEFAULTHEIGHT;
      NSInteger width = TXT_DEFAULTWIDTH;
      
      if ([data objectForKey:@"width"]) {
        width = [self getTextWidth:data[@"width"]];
      }
      
      if ([data objectForKey:@"height"]) {
        height = [self getTextHeight:data[@"height"]];
      }
      
      NSInteger align = POS_ALIGNMENT_LEFT;
      if ([data objectForKey:@"align"]) {
        align = [self getAlignType:data[@"align"]];
      }
      
      NSInteger isBold = 0;
      if ([data objectForKey:@"bold"]) {
        isBold = [self getBoldValue:data[@"bold"]];
      }
      
      [dataM appendData:[POSCommand selectOrCancleBoldModel:isBold]];
      [dataM appendData:[POSCommand selectAlignment:align]];
      [dataM appendData:[POSCommand setTextSize:width height:height]];
      [dataM appendData:[data[@"text"] dataUsingEncoding:enc]];
      [dataM appendData:[POSCommand printAndFeedLine]];
    }
  }
}

RCT_EXPORT_METHOD(setBase64Image:(NSDictionary *)data) {
  [self preparePrintData];

  if ([data isKindOfClass:[NSDictionary class]]) {
    if ([data objectForKey:@"image"]) {
      
      NSInteger align = POS_ALIGNMENT_LEFT;
      if ([data objectForKey:@"align"]) {
        align = [self getAlignType:data[@"align"]];
      }
      
      NSString *result = [@"data:image/png;base64," stringByAppendingString:data[@"image"]];
      NSURL *url = [NSURL URLWithString:result];
      NSData *imageData = [NSData dataWithContentsOfURL:url];
      UIImage *image = [UIImage imageWithData:imageData];
      [dataM appendData:[POSCommand selectAlignment:align]];
      [dataM appendData:[POSCommand printRasteBmpWithM:RasterNolmorWH andImage:image andType:Dithering ]];
      [dataM appendData:[POSCommand printAndFeedLine]];
    }
  }
}

RCT_EXPORT_METHOD(addNewLine:(nonnull NSNumber *)count) {
  [self preparePrintData];
  [dataM appendData:[POSCommand printAndFeedForwardWhitN: [count integerValue]]];
}

RCT_EXPORT_METHOD(setColumn:(NSDictionary *)data) {
  [self preparePrintData];
  
  NSInteger width = TXT_DEFAULTWIDTH;
  if ([data objectForKey:@"width"]) {
    width = [self getTextWidth:data[@"width"]];
  }
  
  NSInteger height = TXT_DEFAULTHEIGHT;
  if ([data objectForKey:@"height"]) {
    height = [self getTextHeight:data[@"height"]];
  }
  
  TableAlignType tableAlign = FIRST_LEFT_ALIGN;
  if ([data objectForKey:@"tableAlign"]) {
    tableAlign = [self getTableALign:data[@"tableAlign"]];
  }
  
  NSInteger isBold = 0;
  if ([data objectForKey:@"bold"]) {
    isBold = [self getBoldValue:data[@"bold"]];
  }
  
  [dataM appendData:[POSCommand setTextSize:width height:height]];
  [dataM appendData:[POSCommand selectOrCancleBoldModel:isBold]];
  [dataM appendData:[PTable addAutoTableH:data[@"column"] titleLength:data[@"columnWidth"] align:tableAlign]];
}

RCT_EXPORT_METHOD(printWithHost:(NSString *)host
                  resolver:(RCTPromiseResolveBlock)resolve 
                  rejector:(RCTPromiseRejectBlock)reject) {
  [self preparePrintData];
  [dataM appendData:[POSCommand printAndFeedForwardWhitN:6]];
  [dataM appendData:[POSCommand selectCutPageModelAndCutpage:1]];
  [self printWithHost:host resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(openCashWithHost:(NSString *)host
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject) {
  [self preparePrintData];
  [dataM appendData:[POSCommand creatCashBoxContorPulseWithM:0 andT1:30 andT2:255]];
  [self printWithHost:host resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(setDensity:(nonnull NSNumber *)density) {
  [self preparePrintData];
  [dataM appendData:[POSCommand setDensity:[density integerValue]]];
}

RCT_EXPORT_METHOD(scanNetwork) {
  if ([[POSWIFIManager sharedInstance] createUdpSocket]) {
    [[POSWIFIManager sharedInstance] sendFindCmd:^(PrinterProfile *printer) {
      if (self->hasListeners) {
        [self sendEventWithName:SCAN_EVENT_NAME body:@{@"ip": [printer getIPString], @"gateway": [printer getGatewayString]}];
      }
    }];
  };
}


RCT_EXPORT_METHOD(stopScan) {
  [[POSWIFIManager sharedInstance] closeUdpSocket];
}

#pragma mark - Method

-(void)preparePrintData {
  if (dataM == nil) {
    dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
  }
}

- (void)printWithHost:(NSString *)host
             resolver:(RCTPromiseResolveBlock)resolve
             rejecter:(RCTPromiseRejectBlock)reject {
  isPrintWithHost = YES;
  printRejector = reject;
  printResolver = resolve;
  [_networkManager connectWithHost:host port:9100];
}

- (void)clearPrintData {
  isPrintWithHost = NO;
  dataM = nil;
  printRejector = NULL;
  printResolver = NULL;
  if ([_networkManager isConnect]) {
    [_networkManager disconnect];
  }
}

- (void)sendPrintResolver:(NSDictionary *)params {
  if (printResolver != NULL) {
    printResolver(params);
    [self clearPrintData];
  }
}

- (void)sendPrintRejector:(NSString *)type message:(NSString *)message error:(NSError *)error {
  if (printRejector != NULL) {
    printRejector(type, message, error);
    [self clearPrintData];
  }
}

- (void)printWithPromise {
  [_networkManager writeCommandWithData:dataM writeCallBack:^(BOOL success, NSError *error) {
    if (success) {
      [self sendPrintResolver:@{@"status": @"success", @"message": @"print success"}];
    } else {
      [self sendPrintRejector:@"print-failure" message:@"failed to print, please check your printer" error:error];
    }
  }];
}

- (NSInteger)getTextWidth:(NSNumber *)width{
  switch([width integerValue]) {
    case 1:
      return TXT_1WIDTH;
    case 2:
      return TXT_2WIDTH;
    case 3:
      return TXT_3WIDTH;
    case 4:
      return TXT_4WIDTH;
    case 5:
      return TXT_5WIDTH;
    case 6:
      return TXT_6WIDTH;
    case 7:
      return TXT_7WIDTH;
    case 8:
      return TXT_8WIDTH;
    default:
      return TXT_DEFAULTWIDTH;
  }
}

- (NSInteger)getTextHeight:(NSNumber *)height{
  switch([height integerValue]) {
    case 1:
      return TXT_1HEIGHT;
    case 2:
      return TXT_2HEIGHT;
    case 3:
      return TXT_3HEIGHT;
    case 4:
      return TXT_4HEIGHT;
    case 5:
      return TXT_5HEIGHT;
    case 6:
      return TXT_6HEIGHT;
    case 7:
      return TXT_7HEIGHT;
    case 8:
      return TXT_8HEIGHT;
    default:
      return TXT_DEFAULTWIDTH;
  }
}

- (NSInteger)getAlignType:(NSNumber *)align{
  switch([align integerValue]) {
    case ALIGN_LEFT:
      return POS_ALIGNMENT_LEFT;
    case ALIGN_CENTER:
      return POS_ALIGNMENT_CENTER;
    case ALIGN_RIGHT:
      return POS_ALIGNMENT_RIGHT;
    default:
      return POS_ALIGNMENT_LEFT;
  }
}

- (TableAlignType)getTableALign:(NSNumber *)tableAlign{
  switch([tableAlign integerValue]) {
    case TABLE_ALIGN_ALL_LEFT:
      return ALL_LEFT_ALIGN;
    case TABLE_ALIGN_ALL_RIGHT:
      return ALL_RIGHT_ALIGN;
    case TABLE_ALIGN_FIRST_LEFT:
      return FIRST_LEFT_ALIGN;
    default:
      return FIRST_LEFT_ALIGN;
  }
}

- (NSInteger)getBoldValue:(NSNumber *)bold{
  switch([bold integerValue]) {
    case BOLD:
      return 1;
    case UNBOLD:
      return 0;
    default:
      return 0;
  }
}

- (void) sendEvent:(NSDictionary *)body {
  if (hasListeners) {
    [self sendEventWithName:EVENT_NAME body:body];
  }
}


#pragma mark - POSWIFIManagerDelegate

//connected success
- (void)POSwifiConnectedToHost:(NSString *)host port:(UInt16)port {
  NSNumber *withPort = [NSNumber numberWithUnsignedShort:port];
  NSDictionary *body = @{@"type": @"connection", @"connected": @(YES), @"host": host, @"port": withPort};
  [self sendEvent:body];
  if (isPrintWithHost == YES) {
    [self printWithPromise];
  }
}

//disconnected
- (void)POSwifiDisconnectWithError:(NSError *)error {
  NSString *host = [_networkManager hostStr];
  NSNumber *withPort =  [NSNumber numberWithUnsignedShort:[_networkManager port]];
  
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
  }
  
  [self sendEvent:@{@"type": errorType, @"connected": @(NO), @"host": host, @"port": withPort, @"error": errorMessage, @"errorData": error ? error : [NSNull null]}];
  if (isPrintWithHost == YES) {
    [self sendPrintRejector:errorType message:errorMessage error:error];
  }
}

- (void)POSwifiWriteValueWithTag:(long)tag {
//  NSLog(@"WRITE VALUE %li", tag);
}

- (void)POSwifiReceiveValueForData:(NSData *)data {
//  NSLog(@"RECEIVE VALUE %@", data);
}


RCT_EXPORT_MODULE();

@end

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

- (instancetype)init {
    self = [super init];
    if (self) {
        connectedPrinterList = [NSMutableArray array]; // Initialize the array
    }
    return self;
}


RCT_EXPORT_METHOD(initWithHost:(NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
    BOOL isExistPrinter = NO;
    for (NPrinter *nPrinter in self->connectedPrinterList) {
      if ([nPrinter.host isEqualToString:host]) {
        isExistPrinter = YES;
      }
    }
    
    if (!isExistPrinter) {
      NPrinter *nPrinter = [[NPrinter alloc] initWithHost:host];
      [self->connectedPrinterList addObject:nPrinter];
    }
  });
}

RCT_EXPORT_METHOD(removeHost:(NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
      NSInteger index = [self->connectedPrinterList indexOfObjectPassingTest:^BOOL(NPrinter *nPrinter, NSUInteger idx, BOOL *stop) {
          return [nPrinter.host isEqualToString:host];
      }];

      if (index != NSNotFound) {
          [self->connectedPrinterList removeObjectAtIndex:index];
      }
  });
}

RCT_EXPORT_METHOD(setTextData:(NSDictionary *)data host:(nonnull NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
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
        
        NPrinter *foundPrinter = [self getPrinterWithHost:host];
        if (foundPrinter) {
          [foundPrinter appendData:[POSCommand selectOrCancleBoldModel:isBold]];
          [foundPrinter appendData:[POSCommand selectAlignment:align]];
          [foundPrinter appendData:[POSCommand setTextSize:width height:height]];
          [foundPrinter appendData:[data[@"text"] dataUsingEncoding:enc]];
          [foundPrinter appendData:[POSCommand printAndFeedLine]];
        }
      }
    }
  });
}

RCT_EXPORT_METHOD(setBase64Image:(NSDictionary *)data host:(nonnull NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
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
        
        NPrinter *foundPrinter = [self getPrinterWithHost:host];
        if (foundPrinter) {
          [foundPrinter appendData:[POSCommand selectAlignment:align]];
          [foundPrinter appendData:[POSCommand printRasteBmpWithM:RasterNolmorWH andImage:image andType:Dithering ]];
          [foundPrinter appendData:[POSCommand printAndFeedLine]];
        }
      }
    }
  });
}

RCT_EXPORT_METHOD(addNewLine:(nonnull NSNumber *)count host:(nonnull NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NPrinter *foundPrinter = [self getPrinterWithHost:host];
    if (foundPrinter) {
      [foundPrinter appendData:[POSCommand printAndFeedForwardWhitN: [count integerValue]]];
    }
  });
}

RCT_EXPORT_METHOD(setColumn:(NSDictionary *)data host:(nonnull NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
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
    
    NPrinter *foundPrinter = [self getPrinterWithHost:host];
    if (foundPrinter) {
      [foundPrinter appendData:[POSCommand setTextSize:width height:height]];
      [foundPrinter appendData:[POSCommand selectOrCancleBoldModel:isBold]];
      [foundPrinter appendData:[PTable addAutoTableH:data[@"column"] titleLength:data[@"columnWidth"] align:tableAlign]];
    }
  });
}

RCT_EXPORT_METHOD(printWithHost:(NSString *)host
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NPrinter *foundPrinter = [self getPrinterWithHost:host];
    if (foundPrinter) {
      [foundPrinter appendData:[POSCommand printAndFeedForwardWhitN:6]];
      [foundPrinter appendData:[POSCommand selectCutPageModelAndCutpage:1]];
      [foundPrinter addPromise:resolve rejector:reject];
      [foundPrinter print];
    }
  });
}

RCT_EXPORT_METHOD(openCashWithHost:(NSString *)host
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NPrinter *foundPrinter = [self getPrinterWithHost:host];
    if (foundPrinter) {
      [foundPrinter appendData:[POSCommand creatCashBoxContorPulseWithM:0 andT1:30 andT2:255]];
      [foundPrinter addPromise:resolve rejector:reject];
      [foundPrinter print];
    }
  });
}

RCT_EXPORT_METHOD(setDensity:(nonnull NSNumber *)density host:(nonnull NSString *)host) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NPrinter *foundPrinter = [self getPrinterWithHost:host];
    if (foundPrinter) {
      [foundPrinter appendData:[POSCommand setDensity:[density integerValue]]];
    }
  });
}

RCT_EXPORT_METHOD(scanNetwork) {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([[POSWIFIManager sharedInstance] createUdpSocket]) {
      [[POSWIFIManager sharedInstance] sendFindCmd:^(PrinterProfile *printer) {
        if (self->hasListeners) {
          [self sendEventWithName:SCAN_EVENT_NAME body:@{@"ip": [printer getIPString], @"gateway": [printer getGatewayString]}];
        }
      }];
    };
  });
}

RCT_EXPORT_METHOD(stopScan) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[POSWIFIManager sharedInstance] closeUdpSocket];
  });
}

#pragma mark - Method

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

- (NPrinter *)getPrinterWithHost:(NSString *)host {
    // Ensure that the host parameter is not nil
    if (host == nil) {
        return nil;
    }
  
    // Iterate over connectedPrinterList to find the printer with the matching host
    for (NPrinter *nPrinter in connectedPrinterList) {
      if ([nPrinter.host isEqualToString:host]) {
        return nPrinter; // Return the printer if the host matches
        break;
      }
    }

    // Return nil if no matching printer is found
    return nil;
}

RCT_EXPORT_MODULE();

@end

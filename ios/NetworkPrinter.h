
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNNetworkPrinterSpec.h"

@interface NetworkPrinter : NSObject <NativeNetworkPrinterSpec>
#else
#import <React/RCTBridgeModule.h>

@interface NetworkPrinter : NSObject <RCTBridgeModule>
#endif

@end

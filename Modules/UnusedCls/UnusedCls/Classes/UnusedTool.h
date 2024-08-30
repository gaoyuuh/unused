//
//  UnusedTool.h
//  Pods
//
//  Created by gaoyu on 2024/8/21.
//

#import <Foundation/Foundation.h>
#import "WBBladesDefines.h"

#ifdef __cplusplus
extern "C" {
#endif
void ErrorLog(NSString * _Nonnull format, ...);
void DebugLog(NSString * _Nonnull format, ...);
#ifdef __cplusplus
}
#endif

@interface UnusedTool : NSObject

+ (NSData *)readBytes:(NSRange *)range length:(NSUInteger)length fromFile:(NSData *)fileData;

+ (unsigned long long)getOffsetFromVmAddress:(unsigned long long )address fileData:(NSData *)fileData;

+ (NSString *)getDemangleName:(NSString *)mangleName;

+ (SwiftKind)getSwiftType:(struct SwiftType)type;

@end

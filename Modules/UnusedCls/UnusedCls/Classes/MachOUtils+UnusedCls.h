//
//  MachOUtils+UnusedCls.h
//  Pods
//
//  Created by gaoyu on 2024/8/20.
//

#import "MachOUtils.h"

@interface MachOUtils (UnusedCls)

+ (NSArray *)scanAllClassWithFileData:(NSData*)fileData classes:(NSSet *)aimClasses progressBlock:(void (^)(NSString *progressInfo))scanProgressBlock;

@end

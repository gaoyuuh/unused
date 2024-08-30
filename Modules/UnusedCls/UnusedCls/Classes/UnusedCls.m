//
//  UnusedCls.m
//  Pods
//
//  Created by gaoyu on 2024/8/19.
//

#import "UnusedCls.h"
#import "WBBladesCMD.h"
#import "WBBladesFileManager.h"
#import "MachOUtils+UnusedCls.h"

@implementation UnusedCls

+ (void)clsWithPath:(NSString *)path {
    [self scanUnusedClassWithAppPath:path fromLibs:@[]];
}

+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)scanUnusedClassWithAppPath:(NSString *)appFilePath fromLibs:(NSArray<NSString *> *)fromLibsPath {

    NSString *appPath = getAppPathIfIpa(appFilePath);
    NSData *appData = [WBBladesFileManager readArm64FromFile:appPath];
    
    NSArray *result = [MachOUtils scanAllClassWithFileData:appData classes:nil progressBlock:^(NSString *progressInfo) {
        
    }];
    
    NSLog(@"%@ %d", result, (int)result.count);

    rmAppIfIpa(appFilePath);
    
    return @[];
}

@end

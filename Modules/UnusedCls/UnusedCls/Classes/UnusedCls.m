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
#import "UnusedTool.h"

@implementation UnusedCls

+ (void)clsWithPath:(NSString *)path {
    [self scanUnusedClassWithAppPath:path fromLibs:@[]];
}

+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)scanUnusedClassWithAppPath:(NSString *)appFilePath 
                                                                       fromLibs:(NSArray<NSString *> *)fromLibsPath {

    NSString *appPath = getAppPathIfIpa(appFilePath);
    NSData *appData = [WBBladesFileManager readArm64FromFile:appPath];
    
    NSArray *result = [MachOUtils scanAllClassWithFileData:appData classes:nil progressBlock:^(NSString *progressInfo) {
        
    }];
    
    NSMutableArray *tmp = [NSMutableArray array];
    for (NSDictionary *dic in result) {
        [tmp addObjectsFromArray:dic.allKeys];
        for (NSString *key in dic.allKeys) {
            printf("%s\n", [key UTF8String]);
        }
    }
    DebugLog(@"%@\n %d", tmp, (int)tmp.count);

    rmAppIfIpa(appFilePath);
    
    return result;
}

@end

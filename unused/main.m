//
//  main.m
//  unused
//
//  Created by gaoyu on 2024/8/19.
//

#import <Foundation/Foundation.h>
#import <UnusedCls/UnusedCls.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSString *path = nil;
        BOOL cls = NO;
        for (NSInteger i = 0; i < arguments.count; i++) {
            NSString *arg = arguments[i];
            if ([arg isEqualToString:@"-class"]) {
                cls = YES;
            } else if ([arg isEqualToString:@"-path"]) {
                if (i + 1 < [arguments count]) {
                    path = arguments[i + 1];
                } else {
                    break;
                }
            }
        }
        
        if (path == nil) {
            NSLog(@"-path option provided, but no path specified.");
            NSLog(@"unused -class -path xxx.app");
            return -1;
        }
        
        if (cls) {
            [UnusedCls clsWithPath:path];
        }
    }
    return 0;
}

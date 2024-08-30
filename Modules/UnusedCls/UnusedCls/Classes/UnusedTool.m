//
//  UnusedTool.m
//  Pods
//
//  Created by gaoyu on 2024/8/21.
//

#import "UnusedTool.h"
#import <mach-o/loader.h>
#import <dlfcn.h>
#import "ChainFixUpsHelper.h"

void ErrorLog(NSString * _Nonnull format, ...) {
    va_list arglist;
    va_start(arglist, format);
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:arglist];
    NSLog(@"%@", logStr);
    va_end(arglist);
}

void DebugLog(NSString * _Nonnull format, ...) {
    va_list arglist;
    va_start(arglist, format);
#ifdef DEBUG
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:arglist];
    NSLog(@"%@", logStr);
#endif
    va_end(arglist);
}

@implementation UnusedTool

+ (NSData *)readBytes:(NSRange *)range length:(NSUInteger)length fromFile:(NSData *)fileData {
    *range = NSMakeRange(NSMaxRange(*range), length);
    if(NSMaxRange(*range) > fileData.length) {
        return nil;
    }
    uint8_t *buffer = (uint8_t *)malloc(length);
    [fileData getBytes:buffer range:*range];
    NSData *ret = [NSData dataWithBytes:buffer length:length];
    free (buffer);
    return ret;
}

+ (unsigned long long)getOffsetFromVmAddress:(unsigned long long )address fileData:(NSData *)fileData{

    struct mach_header_64 mhHeader;
    [fileData getBytes:&mhHeader range:NSMakeRange(0, sizeof(struct mach_header_64))];
    BOOL chainFixUps = [ChainFixUpsHelper shareInstance].isChainFixups;
    unsigned long long currentLcLocation = sizeof(struct mach_header_64);
    for (int i = 0; i < mhHeader.ncmds; i++) {
        struct load_command* cmd = (struct load_command *)malloc(sizeof(struct load_command));
        [fileData getBytes:cmd range:NSMakeRange(currentLcLocation, sizeof(struct load_command))];

        if (cmd->cmd == LC_SEGMENT_64) {//LC_SEGMENT_64:(section header....)
            struct segment_command_64 segmentCommand;
            [fileData getBytes:&segmentCommand range:NSMakeRange(currentLcLocation, sizeof(struct segment_command_64))];
            if (address >= segmentCommand.vmaddr && address <= segmentCommand.vmaddr + segmentCommand.vmsize) {
                free(cmd);
                unsigned long long  returnValue = (address - (segmentCommand.vmaddr - segmentCommand.fileoff));
                return chainFixUps?(returnValue & ChainFixUpsRawvalueMask):returnValue;
            }
        }
        currentLcLocation += cmd->cmdsize;
        free(cmd);
    }
    unsigned long long  returnValue = address;
    return chainFixUps?(returnValue & ChainFixUpsRawvalueMask):returnValue;
}

+ (NSString *)getDemangleName:(NSString *)mangleName{
    int (*swift_demangle_getDemangledName)(const char *,char *,int ) = (int (*)(const char *,char *,int))dlsym(RTLD_DEFAULT, "swift_demangle_getDemangledName");

    if (swift_demangle_getDemangledName) {
        char *demangleName = (char *)malloc(201);
        memset(demangleName, 0, 201);
        int length = 201;
        swift_demangle_getDemangledName([mangleName UTF8String],demangleName,length);
        NSString *demangleNameStr = [NSString stringWithFormat:@"%s",demangleName];
        free(demangleName);
        return demangleNameStr.length>0?demangleNameStr:mangleName;
    }
    NSAssert(swift_demangle_getDemangledName, @"在 Build Phases -> Link Binary with Libraries 中 加入 libswiftDemangle.tbd");
    return mangleName;
}

+ (SwiftKind)getSwiftType:(struct SwiftType)type{
    //读低五位判断类型
    if ((type.Flag & 0x1f) == SwiftKindClass) {
        return SwiftKindClass;
    }else if ((type.Flag & 0x3) == SwiftKindProtocol){
        return SwiftKindProtocol;
    }else if((type.Flag & 0x1f) == SwiftKindStruct){
        return SwiftKindStruct;
    }else if((type.Flag & 0x1f) == SwiftKindEnum){
        return SwiftKindEnum;
    }else if((type.Flag & 0x1f) == SwiftKindModule){
        return SwiftKindModule;
    }else if((type.Flag & 0x1f) == SwiftKindAnonymous){
        return SwiftKindAnonymous;
    }else if((type.Flag & 0x1f) == SwiftKindOpaqueType){
        return SwiftKindOpaqueType;
    }

    return SwiftKindUnknown;
}

@end

//
//  MachOUtils+UnusedCls.m
//  Pods
//
//  Created by gaoyu on 2024/8/20.
//

#import "MachOUtils+UnusedCls.h"
#import <mach-o/nlist.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach/vm_map.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/ldsyms.h>
#import <mach-o/getsect.h>
#import <objc/runtime.h>
#import "ChainFixUpsHelper.h"
#import "WBBladesDefines.h"
#import "UnusedTool.h"

#define ScanUnusedClassLogInfo(log) \
DebugLog(@"%@", log); \
if (scanProgressBlock) {\
    scanProgressBlock(log);\
}

static struct section_64 classList = {0};
static struct section_64 textList = {0};
static struct section_64 swift5Types = {0};

@implementation MachOUtils (UnusedCls)

+ (NSArray *)scanAllClassWithFileData:(NSData*)fileData classes:(NSSet *)aimClasses progressBlock:(void (^)(NSString *progressInfo))scanProgressBlock {
    // clear
    classList = (struct section_64){0};
    textList = (struct section_64){0};
    swift5Types = (struct section_64){0};
    
    [[ChainFixUpsHelper shareInstance] fileLoaderWithFileData:fileData];
    
    struct mach_header_64 mhHeader;
    [fileData getBytes:&mhHeader range:NSMakeRange(0, sizeof(struct mach_header_64))];

    if (mhHeader.filetype != MH_EXECUTE && mhHeader.filetype != MH_DYLIB) {
        ScanUnusedClassLogInfo(@"参数异常，传入的不是可执行文件");
        return nil;
    }
        
    struct section_64 classrefList = (struct section_64){0};
    struct section_64 nlclsList = (struct section_64){0};
    struct section_64 nlcatList = (struct section_64){0};
    struct section_64 cfstringList = (struct section_64){0};
    struct section_64 cstringList = (struct section_64){0};
    struct segment_command_64 linkEdit = (struct segment_command_64){0};
    
    unsigned long long currentLcLocation = sizeof(struct mach_header_64);
    for (int i = 0; i < mhHeader.ncmds; i++) {
        struct load_command *cmd = (struct load_command *)malloc(sizeof(struct load_command));
        [fileData getBytes:cmd range:NSMakeRange(currentLcLocation, sizeof(struct load_command))];
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64 segmentCommand;
            [fileData getBytes:&segmentCommand range:NSMakeRange(currentLcLocation, sizeof(struct segment_command_64))];
            NSString *segName = [NSString stringWithFormat:@"%s",segmentCommand.segname];
            
            if ((segmentCommand.maxprot & ( VM_PROT_WRITE | VM_PROT_READ)) == (VM_PROT_WRITE | VM_PROT_READ)) {
                // __DATA
                unsigned long long currentSecLocation = currentLcLocation + sizeof(struct segment_command_64);
                for (int j = 0; j < segmentCommand.nsects; j++) {
                    struct section_64 sectionHeader;
                    [fileData getBytes:&sectionHeader range:NSMakeRange(currentSecLocation, sizeof(struct section_64))];
                    NSString *secName = [[NSString alloc] initWithUTF8String:sectionHeader.sectname];
                    DebugLog(@"__DATA section: %@", secName);
                    //note classlist
                    if ([secName isEqualToString:DATA_CLASSLIST_SECTION] ||
                        [secName isEqualToString:CONST_DATA_CLASSLIST_SECTION]) {
                        classList = sectionHeader;
                    }
                    //note classref
                    if ([secName isEqualToString:DATA_CLASSREF_SECTION] ||
                        [secName isEqualToString:CONST_DATA_CLASSREF_SECTION]) {
                        classrefList = sectionHeader;
                    }
                    //note nclasslist
                    if ([secName isEqualToString:DATA_NCLSLIST_SECTION] ||
                        [secName isEqualToString:CONST_DATA_NCLSLIST_SECTION]) {
                        nlclsList = sectionHeader;
                    }
                    //note ncatlist
                    if ([secName isEqualToString:DATA_NCATLIST_SECTION] ||
                        [secName isEqualToString:CONST_DATA_NCATLIST_SECTION]) {
                        nlcatList = sectionHeader;
                    }
                    //note Cstring
                    if ([secName isEqualToString:DATA_CSTRING]) {
                        cfstringList = sectionHeader;
                    }
                    if ([secName isEqualToString:TEXT_CSTRING]) {
                        cstringList = sectionHeader;
                    }
                    currentSecLocation += sizeof(struct section_64);
                }
                
            } else if ((segmentCommand.maxprot &( VM_PROT_READ | VM_PROT_EXECUTE)) == (VM_PROT_READ | VM_PROT_EXECUTE)) {
                // __TEXT
                unsigned long long currentSecLocation = currentLcLocation + sizeof(struct segment_command_64);
                for (int j = 0; j < segmentCommand.nsects; j++) {
                    struct section_64 sectionHeader;
                    [fileData getBytes:&sectionHeader range:NSMakeRange(currentSecLocation, sizeof(struct section_64))];
                    NSString *secName = [[NSString alloc] initWithUTF8String:sectionHeader.sectname];
                    DebugLog(@"__TEXT section: %@", secName);
                    if ([secName isEqualToString:TEXT_TEXT_SECTION]) {
                        textList = sectionHeader;

                        //Disassemble the assembly code of the binary
//                            s_cs_insn_address_array = [UnusedTool disassemWithMachOFile:fileData from:sectionHeader.offset length:sectionHeader.size];
                    }else if([secName isEqualToString:TEXT_SWIFT5_TYPES]){
                        swift5Types = sectionHeader;
                    }
                    else if ([secName isEqualToString:TEXT_CSTRING]) {
                        cstringList = sectionHeader;
                    }
                    currentSecLocation += sizeof(struct section_64);
                }
                
            } else if([segName isEqualToString:SEGMENT_LINKEDIT]) {
                // __LINKEDIT
                linkEdit = segmentCommand;
            }
        }
        currentLcLocation += cmd->cmdsize;
        free(cmd);
    }
    
    NSMutableSet *classrefSet = [NSMutableSet set];
    
    // read nlclslist
    [self readNLClsList:nlclsList set:classrefSet fileData:fileData];
    
    // read nlcatlist
    [self readNLCatList:nlcatList set:classrefSet fileData:fileData];
    
    // read classref
    [self readClsRefList:classrefList aimClasses:aimClasses set:classrefSet fileData:fileData];
    
    // read __cstring
    // 读取CString中的字符串
//    [self readCFStringList:cfstringList refSet:classrefSet fileData:fileData];
    [self readCStringList:cstringList refSet:classrefSet fileData:fileData];
    
    // read classlist - OBJC
    NSMutableDictionary *sizeDic = [NSMutableDictionary dictionary];
    NSMutableSet *classSet = [self readClassList:classList aimClasses:aimClasses set:classrefSet fileData:fileData classSize:(NSMutableDictionary *)sizeDic];
    
    // 泛型参数约束
    // 泛型不在classlist里
    
    NSArray *diffList = [self diffClasses:classSet used:classrefSet classSize:(NSMutableDictionary *)sizeDic fileData:(NSData *)fileData];
    return diffList;
}

/**
功能：读取主类中实现+load的类，在某些场景下，文件在主类中没有实现+load方法，但是在分类中实现了+load，这种场景下该类没有在nlclsList中。
classrefSet：被引用的类的集合
fileData：从磁盘中读取的二进制文件，通常是可执行文件。
*/
+ (void)readNLClsList:(struct section_64)nlclsList set:(NSMutableSet *)classrefSet fileData:(NSData *)fileData {
    //nlclslist
    NSRange range = NSMakeRange(nlclsList.offset, 0);
    unsigned long long max = [fileData length];
     for (int i = 0; i < nlclsList.size / 8; i++) {
         @autoreleasepool {
           
             unsigned long long classAddress;
             NSData *data = [UnusedTool readBytes:&range length:8 fromFile:fileData];
             [data getBytes:&classAddress range:NSMakeRange(0, 8)];
             classAddress = [UnusedTool getOffsetFromVmAddress:classAddress fileData:fileData];
             //method name 150 bytes maximum
             if (classAddress > 0 && classAddress < max) {
                 
                 struct class64 targetClass;
                 [fileData getBytes:&targetClass range:NSMakeRange(classAddress,sizeof(struct class64))];
                 
                 struct class64Info targetClassInfo = {0};
                 unsigned long long targetClassInfoOffset = [UnusedTool getOffsetFromVmAddress:targetClass.data fileData:fileData];
                 targetClassInfoOffset = (targetClassInfoOffset / 8) * 8;
                 NSRange targetClassInfoRange = NSMakeRange(targetClassInfoOffset, 0);
                 data = [UnusedTool readBytes:&targetClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
                 [data getBytes:&targetClassInfo length:sizeof(struct class64Info)];
                 unsigned long long classNameOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.name fileData:fileData];

                 //class name 50 bytes maximum
                 uint8_t *buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
                 [fileData getBytes:buffer range:NSMakeRange(classNameOffset, CLASSNAME_MAX_LEN)];
                 NSString *className = NSSTRING(buffer);
                 free(buffer);
                 if (className){
                     [classrefSet addObject:className];
                 }
             }
         }
     }
}

/**
功能：读取分类中实现+load的类，在某些场景下，文件在主类中没有实现+load方法，但是在分类中实现了+load，这种场景可以通过nlcatList获取到类信息。
classrefSet：被引用的类的集合
fileData：从磁盘中读取的二进制文件，通常是可执行文件。
*/
+ (void)readNLCatList:(struct section_64)nlcatList set:(NSMutableSet *)classrefSet fileData:(NSData *)fileData {
    NSRange range = NSMakeRange(nlcatList.offset, 0);
    unsigned long long max = [fileData length];
    for (int i = 0; i < nlcatList.size / 8; i++) {
        @autoreleasepool {
    
            unsigned long long catAddress;
            NSData *data = [UnusedTool readBytes:&range length:8 fromFile:fileData];
            [data getBytes:&catAddress range:NSMakeRange(0, 8)];
            catAddress = [UnusedTool getOffsetFromVmAddress:catAddress fileData:fileData];
            //method name 150 bytes maximum
            if (catAddress > 0 && catAddress < max) {
                
                struct category64 targetCategory;
                [fileData getBytes:&targetCategory range:NSMakeRange(catAddress,sizeof(struct category64))];
                
                //like UIViewController(MyCategory) +load
                if (targetCategory.cls == 0) {
                    continue;
                }
                struct class64 targetClass;
                unsigned long long classAddressOffset = [UnusedTool getOffsetFromVmAddress:targetCategory.cls fileData:fileData];
                if(![[ChainFixUpsHelper shareInstance] validateSectionWithFileoffset:classAddressOffset sectionName:@"__objc_data"]){
                    //如果该地址经过运算的取值在importSymbolPool范围内则为外部动态库的类
                    continue;
                }
                [fileData getBytes:&targetClass range:NSMakeRange([UnusedTool getOffsetFromVmAddress:targetCategory.cls fileData:fileData],sizeof(struct class64))];
                
                struct class64Info targetClassInfo = (struct class64Info){0};
                unsigned long long targetClassInfoOffset = [UnusedTool getOffsetFromVmAddress:targetClass.data fileData:fileData];
                targetClassInfoOffset = (targetClassInfoOffset / 8) * 8;
                NSRange targetClassInfoRange = NSMakeRange(targetClassInfoOffset, 0);
                data = [UnusedTool readBytes:&targetClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
                [data getBytes:&targetClassInfo length:sizeof(struct class64Info)];
                unsigned long long classNameOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.name fileData:fileData];
                
                //class name 50 bytes maximum
                uint8_t *buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
                [fileData getBytes:buffer range:NSMakeRange(classNameOffset, CLASSNAME_MAX_LEN)];
                NSString *className = NSSTRING(buffer);
                free(buffer);
                if (className){
                    [classrefSet addObject:className];
                }
            }
        }
    }
}

/**
功能：读取二进制文件中的classref数据，classref中存放的是被显式调用的类（不包括Swift类）。例如+[ClassA func]，ClassA会被存放到classref中。
aimClasses：只检测指定的类，此数据从静态库中提取
fileData：从磁盘中读取的二进制文件，通常是可执行文件。
*/
+ (void)readClsRefList:(struct section_64)classrefList aimClasses:(NSSet *)aimClasses set:(NSMutableSet *)classrefSet fileData:(NSData *)fileData {
    NSRange range = NSMakeRange(classrefList.offset, 0);
    unsigned long long max = [fileData length];
    for (int i = 0; i < classrefList.size / 8; i++) {
           @autoreleasepool {
               
               unsigned long long classAddress;
               NSData *data = [UnusedTool readBytes:&range length:8 fromFile:fileData];
               [data getBytes:&classAddress range:NSMakeRange(0, 8)];
               classAddress = [UnusedTool getOffsetFromVmAddress:classAddress fileData:fileData];
               if(![[ChainFixUpsHelper shareInstance]validateSectionWithFileoffset:classAddress sectionName:@"__objc_data"]){
                   //如果该地址经过运算的取值在importSymbolPool范围内则为外部动态库的类
                   continue;
               }
               //method name 150 bytes maximum
               if (classAddress > 0 && classAddress < max) {

                   //class64 struct
                   struct class64 targetClass;
                   ptrdiff_t off = classAddress;
                   char *p = (char *)fileData.bytes;
                   p = p+off;
                   memcpy(&targetClass, p, sizeof(struct class64));

                   //class64info struct
                   struct class64Info targetClassInfo = {0};
                   unsigned long long targetClassInfoOffset = [UnusedTool getOffsetFromVmAddress:targetClass.data fileData:fileData];
                   targetClassInfoOffset = (targetClassInfoOffset / 8) * 8;
                   NSRange targetClassInfoRange = NSMakeRange(targetClassInfoOffset, 0);
                   data = [UnusedTool readBytes:&targetClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
                   [data getBytes:&targetClassInfo length:sizeof(struct class64Info)];
                   unsigned long long classNameOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.name fileData:fileData];

                   //class name 50 bytes maximum
//                   uint8_t *buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
//                   [fileData getBytes:buffer range:NSMakeRange(classNameOffset, CLASSNAME_MAX_LEN)];
//                   NSString *className = NSSTRING(buffer);
//                   free(buffer);
                   NSString *className = @((char *)[fileData bytes]  + classNameOffset);

                   if (className) {
                       if ([className hasPrefix:@"_TtC"]) {
                           className = [UnusedTool getDemangleName:className];
                       }
                       [classrefSet addObject:className];
                   }
               }
           }
       }
}

/**
功能：该函数目的是为了获取项目中用到的所有字符串，例如 @”String“。获取到字符串后我们”勉强“把这些字符串都当做runtime动态调用的类。
     classrefSet：被引用的类的集合，string会被加入到这个集合中
fileData：从磁盘中读取的二进制文件，通常是可执行文件。
*/
+(void)readCFStringList:(struct section_64)cfstringList refSet:(NSMutableSet *)classrefSet fileData:(NSData *)fileData {
    NSRange range = NSMakeRange(cfstringList.offset, 0);
    unsigned long long max = [fileData length];
    for (int i = 0; i < cfstringList.size / sizeof(struct cfstring64); i++) {
         @autoreleasepool {
             
             struct cfstring64 cfstring;
             NSData *data = [UnusedTool readBytes:&range length:sizeof(struct cfstring64) fromFile:fileData];
             [data getBytes:&cfstring range:NSMakeRange(0, sizeof(struct cfstring64))];
             unsigned long long stringOff = [UnusedTool getOffsetFromVmAddress:cfstring.stringAddress fileData:fileData];
             if (stringOff > 0 && stringOff < max) {
                 uint8_t *buffer = (uint8_t *)malloc(cfstring.size + 1); buffer[cfstring.size] = '\0';
                 [fileData getBytes:buffer range:NSMakeRange(stringOff, cfstring.size)];
                 NSString *className = NSSTRING(buffer);
                 // DebugLog(@"cfString: %@", className);
                 free(buffer);
                 if (className){
                     [classrefSet addObject:className];
                 }
             }
         }
     }
}

//检测项目中所有的字符串
+ (void)readCStringList:(struct section_64)cstringList refSet:(NSMutableSet *)classrefSet fileData:(NSData *)fileData {
    unsigned long long start_loc = cstringList.offset;
    unsigned long long max = cstringList.offset + cstringList.size;
    unsigned long long step = start_loc;
    while (step < max) {
        @autoreleasepool {
            NSRange range = NSMakeRange(step, 1);
            char *buffer = (char *)malloc(1);
            [fileData getBytes:buffer range:range];
            if (*buffer == 0) {
                unsigned long long str_len = step - start_loc;
                if (str_len>0) {
                    char *str_buffer = (char *)malloc(str_len+1); str_buffer[str_len] = '\0';
                    [fileData getBytes:str_buffer range:NSMakeRange(start_loc, str_len)];
                    NSString *cString = [NSString stringWithCString:str_buffer encoding:NSUTF8StringEncoding];
                    // DebugLog(@"cfString: %@", className);
                    if (cString && ![cString hasPrefix:@"_TtC"]) {
                        [classrefSet addObject:cString];
                    }
                    free(str_buffer);
                }
                start_loc = step + 1;
            }
            free(buffer);
            step++;
        }
    }
}

/**
 功能：获取classlist section中的数据，并遍历每个类的父类及属性。将父类和属性纳入到有用类集合中
 classList：classlist section的section_64结构体，里面记录了classlist section的引导信息
 aimClasses：只检测指定的类，此数据从静态库中提取
 */
+ (NSMutableSet *)readClassList:(struct section_64)classList aimClasses:(NSSet *)aimClasses set:(NSMutableSet *)classrefSet fileData:(NSData *)fileData classSize:(NSMutableDictionary *)sizeDic{
    NSMutableSet *classSet = [NSMutableSet set];
    unsigned long long max = [fileData length];
    NSRange  range = NSMakeRange(classList.offset, 0);
    for (int i = 0; i < classList.size / 8 ; i++) {
        @autoreleasepool {
            
            unsigned long long classAddress;
            NSData *data = [UnusedTool readBytes:&range length:8 fromFile:fileData];
            [data getBytes:&classAddress range:NSMakeRange(0, 8)];
            unsigned long long classOffset = [UnusedTool getOffsetFromVmAddress:classAddress fileData:fileData];
            
            //class struct
            struct class64 targetClass = {0};
            NSRange targetClassRange = NSMakeRange(classOffset, 0);
            data = [UnusedTool readBytes:&targetClassRange length:sizeof(struct class64) fromFile:fileData];
            [data getBytes:&targetClass length:sizeof(struct class64)];
            
            //class info struct
            struct class64Info targetClassInfo = (struct class64Info){0};
            unsigned long long targetClassInfoOffset = [UnusedTool getOffsetFromVmAddress:targetClass.data fileData:fileData];
            targetClassInfoOffset = (targetClassInfoOffset / 8) * 8;
            NSRange targetClassInfoRange = NSMakeRange(targetClassInfoOffset, 0);
            data = [UnusedTool readBytes:&targetClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
            [data getBytes:&targetClassInfo length:sizeof(struct class64Info)];

            unsigned long long classNameOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.name fileData:fileData];

            //superclass info
            if (targetClass.superClass != 0) {
                struct class64 superClass = (struct class64){0};
                unsigned long long superClassOffset = [UnusedTool getOffsetFromVmAddress:targetClass.superClass fileData:fileData];
                // superClass 需要判断是否存在本Mach-O文件中，有可能是系统类，依赖bind ，校验区间地址的合法性
                if([[ChainFixUpsHelper shareInstance] validateSectionWithFileoffset:superClassOffset sectionName:@"__objc_data"]){
                    NSRange superClassRange = NSMakeRange(superClassOffset, 0);
                    data = [UnusedTool readBytes:&superClassRange length:sizeof(struct class64) fromFile:fileData];
                    [data getBytes:&superClass length:sizeof(struct class64)];
                    
                    struct class64Info superClassInfo = (struct class64Info){0};
                    unsigned long long superClassInfoOffset = [UnusedTool getOffsetFromVmAddress:superClass.data fileData:fileData];
                    superClassInfoOffset = (superClassInfoOffset / 8) * 8;
                    NSRange superClassInfoRange = NSMakeRange(superClassInfoOffset, 0);
                    data = [UnusedTool readBytes:&superClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
                    [data getBytes:&superClassInfo length:sizeof(struct class64Info)];
                    
                    unsigned long long superClassNameOffset = [UnusedTool getOffsetFromVmAddress: superClassInfo.name fileData:fileData];
                    
                    //class name 50 bytes maximum
                    uint8_t * buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
                    [fileData getBytes:buffer range:NSMakeRange(superClassNameOffset, CLASSNAME_MAX_LEN)];
                    NSString * superClassName = NSSTRING(buffer);
                    free(buffer);
                    if (superClassName) {
                        [classrefSet addObject:superClassName];
                    }
                }
            }
            //class name 50 bytes maximum
            uint8_t * buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
            [fileData getBytes:buffer range:NSMakeRange(classNameOffset, CLASSNAME_MAX_LEN)];
            NSString * className = NSSTRING(buffer);
            free(buffer);
            
            //judge Whether the current class is in the target class collection
            if (([aimClasses count]>0 && ![aimClasses containsObject:className])) {
                continue;
            }
            
            if (className)[classSet addObject:className];
            
            
            // 统计对象方法和类方法实现大小
            unsigned long long vm = classList.addr - classList.offset;
            struct class64 metaClass = {0};
            NSRange metaClassRange = NSMakeRange([UnusedTool getOffsetFromVmAddress:targetClass.isa fileData:fileData], 0);
            data = [UnusedTool readBytes:&metaClassRange length:sizeof(struct class64) fromFile:fileData];
            [data getBytes:&metaClass length:sizeof(struct class64)];
            
            struct class64Info metaClassInfo = {0};
            unsigned long long metaClassInfoOffset = [UnusedTool getOffsetFromVmAddress:metaClass.data fileData:fileData];
            metaClassInfoOffset = (metaClassInfoOffset / 8) * 8;
            NSRange metaClassInfoRange = NSMakeRange(metaClassInfoOffset, 0);
            data = [UnusedTool readBytes:&metaClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
            [data getBytes:&metaClassInfo length:sizeof(struct class64Info)];
            
            unsigned long long methodListOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.baseMethods fileData:fileData];
            unsigned long long classMethodListOffset = [UnusedTool getOffsetFromVmAddress:metaClassInfo.baseMethods fileData:fileData];
            int allSize = 0;
//            // 加上属性大小
//            allSize = allSize + targetClassInfo.instanceSize;
//            // 加上类结构大小
//            allSize = allSize + (sizeof(class64Info) + sizeof(class64)) * 2;
//
//            //遍历每个class的method (实例方法)
//            if (methodListOffset > 0 && methodListOffset < max) {
//                allSize = allSize + [self statisticsMethodImp:methodListOffset vm:vm fileData:fileData];
//            }
//            //类方法
//            if (classMethodListOffset > 0 && classMethodListOffset < max) {
//                allSize = allSize + [self statisticsMethodImp:classMethodListOffset vm:vm fileData:fileData];
//            }
            if (className) {
                sizeDic[className] = @(allSize/1000.0);
            }
            
            //enumerate member variables
            unsigned long long varListOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.instanceVariables fileData:fileData];
            if (varListOffset > 0 && varListOffset < max) {
                unsigned int varCount;
                NSRange varRange = NSMakeRange(varListOffset + 4, 0);
                data = [UnusedTool readBytes:&varRange length:4 fromFile:fileData];
                [data getBytes:&varCount length:4];
                for (int j = 0; j<varCount; j++) {
                    NSRange varRange = NSMakeRange(varListOffset+sizeof(struct ivar64_list_t) + sizeof(struct ivar64_t) * j, sizeof(struct ivar64_t));
                    struct ivar64_t var = (struct ivar64_t){};
                    [fileData getBytes:&var range:varRange];
                    unsigned long long methodNameOffset = var.type;
                    methodNameOffset = [UnusedTool getOffsetFromVmAddress:methodNameOffset fileData:fileData];
                    uint8_t * buffer = (uint8_t *)malloc(METHODNAME_MAX_LEN + 1); buffer[METHODNAME_MAX_LEN] = '\0';
                    if (methodNameOffset > 0 && methodNameOffset < max) {
                        [fileData getBytes:buffer range:NSMakeRange(methodNameOffset,METHODNAME_MAX_LEN)];
                        NSString *typeName = NSSTRING(buffer);
                        if (typeName) {
                            typeName = [typeName stringByReplacingOccurrencesOfString:@"@\"" withString:@""];
                            typeName = [typeName stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                            [classrefSet addObject:typeName];
                        }
                    }
                }
            }
        }
    }
    return classSet;
}

/**
 功能：对类做diff，差集即为无用类集合。在diff过程中，如果遇到Swift类则需要进行demangleName处理
 allClasses：所有的类
 usedClasses：被标记为有用到的类
 */
+ (NSArray*)diffClasses:(NSMutableSet *)allClasses used:(NSMutableSet *)usedClasses classSize:(NSMutableDictionary *)sizeDic fileData:(NSData *)fileData {
    DebugLog(@"allClass: %d  refClass: %d", (int)allClasses.count, (int)usedClasses.count);
    // allClasses和usedClasses做差集
    NSMutableSet *newAllClasses = [[NSMutableSet alloc] init];
    [allClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *className = (NSString *)obj;
        if ([className hasPrefix:@"_TtC"]) {
            NSString *demangleName = [UnusedTool getDemangleName:className];
            if (demangleName.length > 0) {
                [newAllClasses addObject:demangleName];
            } else {
                [newAllClasses addObject:className];
            }
            if ([usedClasses containsObject:className] && className.length > 0) {
                [usedClasses addObject:demangleName];
            }
            return;
        }
        if ([className hasPrefix:@"PodsDummy_"]) {
            //过滤掉PodsDummy_开头的无效类
            [usedClasses addObject:className];
            return;
        }
        [newAllClasses addObject:className];
    }];
    allClasses = newAllClasses;
    
    NSMutableArray *unusedClasses = [NSMutableArray array];
    [allClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([usedClasses containsObject:obj]) {
            return;
        }
        NSString *demangleName = @"";
        if ([obj hasPrefix:@"_Tt"]) {
            demangleName = [UnusedTool getDemangleName:obj] ?: @"";
        }
        NSString *className = demangleName.length > 0 ? demangleName : obj;
        if ([className containsString:@" in "]) {
            return;
        }
        [unusedClasses addObject:className];
    }];
    // 将OC和swift类分开，分别进行类大小估算
    NSMutableArray *ocList = [NSMutableArray array];
    NSMutableDictionary *swiftClsDic = [NSMutableDictionary dictionary];
    [unusedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:@" in "]) {
            [unusedClasses removeObject:obj];
        }
        else if ([obj containsString:@"."]) {
            NSArray *nameArr = [obj componentsSeparatedByString:@"."];
            if (nameArr.count == 2) {
                swiftClsDic[nameArr[1]] = [NSString stringWithFormat:@"%@.%@", nameArr[0], nameArr[1]];
            }
        }
        else {
            [ocList addObject:obj];
        }
    }];
    // 统计OC类大小
    NSDictionary *ocRes = [self statOCClassSize:classList unusedOCClasses:ocList fileData:fileData];
    // 统计swift类大小，swiftRes结构为<类名NSString,类大小NSNumber>
//    NSDictionary *swiftRes = [self statSwiftClassSize:swiftClsDic andSwift5Types:swift5Types fileData:fileData];
//    DebugLog(@"swiftRes: %@",swiftRes);
    
    return @[ocRes, @{}];
}

/**
 统计swift类大小，大小包括：
 (1)SwiftClassType
 (2)FieldDescriptor+MangledTypeName长度+FieldRecord+FieldName长度
 (3)SwiftMethod+imp函数实现的长度
 */
+ (NSDictionary *)statOCClassSize:(struct section_64)classList unusedOCClasses:(NSArray *)unusedClasses fileData:(NSData *)fileData {
    NSMutableDictionary *sizeDic = [NSMutableDictionary dictionary];
    unsigned long long max = [fileData length];
    NSRange range = NSMakeRange(classList.offset, 0);
    for (int i = 0; i < classList.size / 8 ; i++) {
        @autoreleasepool {
            unsigned long long classAddress;
            NSData *data = [UnusedTool readBytes:&range length:8 fromFile:fileData];
            [data getBytes:&classAddress range:NSMakeRange(0, 8)];
            unsigned long long classOffset = [UnusedTool getOffsetFromVmAddress:classAddress fileData:fileData];

            //class struct
            struct class64 targetClass = {0};
            NSRange targetClassRange = NSMakeRange(classOffset, 0);
            data = [UnusedTool readBytes:&targetClassRange length:sizeof(struct class64) fromFile:fileData];
            [data getBytes:&targetClass length:sizeof(struct class64)];

            //class info struct
            struct class64Info targetClassInfo = (struct class64Info){0};
            unsigned long long targetClassInfoOffset = [UnusedTool getOffsetFromVmAddress:targetClass.data fileData:fileData];
            targetClassInfoOffset = (targetClassInfoOffset / 8) * 8;
            NSRange targetClassInfoRange = NSMakeRange(targetClassInfoOffset, 0);
            data = [UnusedTool readBytes:&targetClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
            [data getBytes:&targetClassInfo length:sizeof(struct class64Info)];

            unsigned long long classNameOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.name fileData:fileData];
            //class name 50 bytes maximum
            uint8_t * buffer = (uint8_t *)malloc(CLASSNAME_MAX_LEN + 1); buffer[CLASSNAME_MAX_LEN] = '\0';
            [fileData getBytes:buffer range:NSMakeRange(classNameOffset, CLASSNAME_MAX_LEN)];
            NSString *className = NSSTRING(buffer);
            free(buffer);
            if (![unusedClasses containsObject:className]) {
                continue;
            }
            // 统计对象方法和类方法实现大小
            unsigned long long vm = classList.addr - classList.offset;
            struct class64 metaClass = (struct class64){0};
            NSRange metaClassRange = NSMakeRange([UnusedTool getOffsetFromVmAddress:targetClass.isa fileData:fileData], 0);
            data = [UnusedTool readBytes:&metaClassRange length:sizeof(struct class64) fromFile:fileData];
            [data getBytes:&metaClass length:sizeof(struct class64)];

            struct class64Info metaClassInfo = (struct class64Info){0};
            unsigned long long metaClassInfoOffset = [UnusedTool getOffsetFromVmAddress:metaClass.data fileData:fileData];
            metaClassInfoOffset = (metaClassInfoOffset / 8) * 8;
            NSRange metaClassInfoRange = NSMakeRange(metaClassInfoOffset, 0);
            data = [UnusedTool readBytes:&metaClassInfoRange length:sizeof(struct class64Info) fromFile:fileData];
            [data getBytes:&metaClassInfo length:sizeof(struct class64Info)];

            unsigned long long methodListOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.baseMethods fileData:fileData];
            unsigned long long classMethodListOffset = [UnusedTool getOffsetFromVmAddress:metaClassInfo.baseMethods fileData:fileData];
            int allSize = 0;
            // 加上类结构大小
            allSize = allSize + (sizeof(struct class64Info) + sizeof(struct class64)) * 2;

            //遍历每个class的method (实例方法)
            if (methodListOffset > 0 && methodListOffset < max) {
                allSize = allSize + [self statisticsMethodImp:methodListOffset vm:vm fileData:fileData];
            }
            //类方法
            if (classMethodListOffset > 0 && classMethodListOffset < max) {
                allSize = allSize + [self statisticsMethodImp:classMethodListOffset vm:vm fileData:fileData];
            }

            //统计属性大小
            unsigned long long varListOffset = [UnusedTool getOffsetFromVmAddress:targetClassInfo.instanceVariables fileData:fileData];
            if (varListOffset > 0 && varListOffset < max) {
                unsigned int varCount;
                NSRange varRange = NSMakeRange(varListOffset + 4, 0);
                data = [UnusedTool readBytes:&varRange length:4 fromFile:fileData];
                [data getBytes:&varCount length:4];
                allSize += sizeof(struct ivar64_list_t);
                for (int j = 0; j<varCount; j++) {
                    NSRange varRange = NSMakeRange(varListOffset+sizeof(struct ivar64_list_t) + sizeof(struct ivar64_t) * j, sizeof(struct ivar64_t));
                    struct ivar64_t var = (struct ivar64_t){};
                    [fileData getBytes:&var range:varRange];
                    unsigned long long varNameOffset = [UnusedTool getOffsetFromVmAddress:var.name fileData:fileData];
                    //class name 50 bytes maximum
                    uint8_t * buffer = (uint8_t *)malloc(METHODNAME_MAX_LEN + 1); buffer[METHODNAME_MAX_LEN] = '\0';
                    [fileData getBytes:buffer range:NSMakeRange(varNameOffset, METHODNAME_MAX_LEN)];
                    NSString *varName = NSSTRING(buffer);
                    free(buffer);
                    allSize = allSize + (int)varName.length + sizeof(struct ivar64_t);
                }
            }
            sizeDic[className] = @(allSize);
        }
    }
    return sizeDic;
}

///**
// 统计swift类大小，大小包括：
// (1)SwiftClassType
// (2)FieldDescriptor+MangledTypeName长度+FieldRecord+FieldName长度
// (3)SwiftMethod+imp函数实现的长度
// */
//+ (NSDictionary *)statSwiftClassSize:(NSMutableDictionary *)swiftClsDic andSwift5Types:(struct section_64)swift5Types fileData:(NSData *)fileData {
//    NSMutableDictionary *sizeDic = [NSMutableDictionary dictionary];
//    //Scan Swift5Types
//    NSRange range = NSMakeRange(swift5Types.offset, 0);
//    NSUInteger location = 0;
//    uintptr_t linkBase = swift5Types.addr - swift5Types.offset;
//    NSArray *classList = swiftClsDic.allKeys;
//    for (int i = 0; i < swift5Types.size / 4 ; i++) {
//        unsigned long long typeAddress = swift5Types.addr + location;
//        uintptr_t offset = [UnusedTool getOffsetFromVmAddress:typeAddress fileData:fileData];
//        range = NSMakeRange(offset, 0);
//        uintptr_t content = 0;
//        NSData *data = [UnusedTool readBytes:&range length:4 fromFile:fileData];
//        [data getBytes:&content range:NSMakeRange(0, 4)];
//        uintptr_t vmAddress = content + typeAddress;// 有段迁移情况下
//        if (vmAddress > 2 * linkBase) {
//            vmAddress -= linkBase;// 正常情况下
//        }
//        uintptr_t typeOffset = [UnusedTool getOffsetFromVmAddress:vmAddress fileData:fileData];
//        
//        struct SwiftType swiftType = (struct SwiftType){0};
//        range = NSMakeRange(typeOffset, 0);
//        data = [UnusedTool readBytes:&range length:sizeof(struct SwiftType) fromFile:fileData];
//        [data getBytes:&swiftType range:NSMakeRange(0, sizeof(struct SwiftType))];
//
//        SwiftKind kindType = [UnusedTool getSwiftType:swiftType];
//        if (kindType == SwiftKindClass) {
//            if (typeOffset > fileData.length) {
//                continue;
//            }
////            // 先查看类名是否在未使用类中，如果在则进行统计
//            NSString *className = [UnusedTool getSwiftTypeNameWithSwiftType:swiftType Offset:typeOffset vm:linkBase fileData:fileData];
//            if (![classList containsObject:className]) {
//                location += sizeof(uint32_t);
//                continue;
//            }
//            // 如果有符号表，则此处不返回函数大小，而是通过符号表来进行精确统计，保存在methodSizeDic中
//            int classSize = 0;
////            int classSize = [self scanSwiftClassMethodSymbol:typeOffset
////                                                             swiftType:swiftType
////                                                                    vm:linkBase
////                                                              fileData:fileData];
//            if (hasSymbolTab) {
//                int funSize = [methodSizeDic[className] longLongValue];
//                methodSizeDic[className] = @(funSize + classSize);
//            } else {
//                methodSizeDic[className] = @(classSize);
//            }
//            sizeDic[swiftClsDic[className]] = @(classSize);
//            
//        }
//        location += sizeof(uint32_t);
//    }
//    return sizeDic;
//}

+ (int)statisticsMethodImp:(unsigned long long)methodListOffset
                                   vm:(unsigned long long)vm
                             fileData:(NSData*)fileData{
    
    struct method64_list_t methodList;
    NSRange methodRange = NSMakeRange(methodListOffset, 0);
    NSData* data = [UnusedTool readBytes:&methodRange length:sizeof(struct method64_list_t) fromFile:fileData];
    [data getBytes:&methodList length:sizeof(struct method64_list_t)];
    
    int totalSize = sizeof(struct method64_list_t) + sizeof(struct method64_t) * methodList.count;
//    for (int j = 0; j<methodList.count; j++) {
//        //获取方法名
//        methodRange = NSMakeRange(methodListOffset + sizeof(method64_list_t) + sizeof(method64_t) * j, 0);
//        data = [UnusedTool readBytes:methodRange length:sizeof(method64_t) fromFile:fileData];
//        method64_t method;
//        [data getBytes:&method length:sizeof(method64_t)];
//        unsigned long long imp = method.imp;
//        int impSize = [self scanFuncBegin:imp vm:vm fileData:fileData];
//        totalSize = totalSize + impSize;
//    }
    return totalSize;
}

@end

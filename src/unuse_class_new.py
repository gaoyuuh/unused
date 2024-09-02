# -*- coding: utf-8 -*-

import os
import json
import re
# from check.main import *

from datetime import datetime


#壳工程
base_modules = 'Project'
bosshi_base_modules = 'BossHi'
orange_base_modules = 'Orange'

#所有模块
shopzp_moules = [
    'spboss',
    'spgeek',
    'spbusiness',
    'spchat',
    'spchatbase',
    'splogin',
    'splivevideo',
    'spsupport',
    # 'spoptional',
    'spinterfaces',
    'spbasic',
    'spkit',
    'spnetwork',
    # 'spthirdlib' 三方库无需检测
]

bosszp_modules = [
    'bz_basic',
    'bz_viewmodel',
    'bz_boss',
    'bz_chat',
    'bz_chatbase',
    'bz_company',
    'bz_geek',
    'bz_homepage',
    'bz_login',
    'bz_support',
    'bz_network',
    'bz_setting',
    'bz_user'
           ]

bosshi_modules = [
    'BHAvCall',
    'BHChat',
    'BHContacts',
    'BHHi',
    'BHKit',
    'BHMe',
    'BHMail',
    'BHSchedule',
    'BHSearch',
    'BHSplashScreen',
    'BHWorkbench',
    'BHWorkflow'
           ]

orange_modules = [
    'OGChat',
    'OGDB',
    'OGDebug',
    'OGKit',
    'OGKitSon',
    'OGLogin',
    'OGMatch',
    'OGMe',
    'OGParents',
    'OGSquare',
    'OGThird'
           ]

#有依赖关系模块
shopzp_rely_modules = {
    'spbasic': ['spboss','spgeek','spbusiness','spchat','spchatbase','splogin','splivevideo','spsupport']
}

bosszp_rely_modules = {
    'bz_user' : ['bz_basic','bz_viewmodel','bz_boss','bz_chatbase','bz_company','bz_geek','bz_homepage','bz_login','bz_support','bz_setting'],
    'bz_basic' : ['bz_boss','bz_chat','bz_viewmodel','bz_chatbase','bz_company','bz_geek','bz_homepage','bz_login','bz_support','bz_setting'],
    'bz_viewmodel' : ['bz_boss','bz_chatbase','bz_company','bz_geek','bz_homepage','bz_chat','bz_login','bz_support','bz_setting'],
    'bz_chatbase':['bz_boss','bz_homepage','bz_geek','bz_chat','bz_company'],
}

bosshi_rely_modules = {
    'BHKit':['BHAvCall','BHChat','BHContacts','BHDatabase','BHHi','BHLogin','BHMail','BHMe','BHSchedule','BHSearch','BHWorkbench','BHWorkflow'],
    'BHContacts':['BHAvCall','BHChat','BHDatabase','BHHi','BHLogin','BHSearch','BHWorkbench','BHWorkflow']
}

orange_rely_modules = {
    'OGThird': ['OGChat','OGDB','OGDebug','OGKitSon','OGLogin','OGMatch','OGMe','OGParents','OGSquare','OGKit'],
    'OGKit':['OGChat','OGDB','OGDebug','OGKitSon','OGLogin','OGMatch','OGMe','OGParents','OGSquare'],
    'OGDB': ['OGChat','OGDebug','OGKitSon','OGLogin','OGMatch','OGMe','OGParents','OGSquare'],
    'OGKitSon': ['OGChat','OGDebug','OGLogin','OGMatch','OGMe','OGParents','OGSquare'],
}

#店长路由处理
shopzp_route_maps = {
    'spsupport/SPSupport/Classes/DZSupport/SPURLRoutes/SPURLMap.m',
    'spsupport/SPSupport/Classes/DZSupport/SPURLRoutes/SPURLModuleMap.m',
    'spsupport/SPSupport/Classes/DZSupport/SPURLRoutes/SPURLPresentMap.m',
    'spsupport/SPSupport/Classes/DZSupport/SPURLRoutes/SPURLMap.m',
    'spbasic/SPBasic/Classes/SPAlerter/SPAlerterMaps.m'
}

#三方framework
shopzp_ignoreRes = [
    'Products',
    'protobuf',
    'JXCategoryView',
    'JXPagerView'
    ]

bosszp_ignoreRes = [
    'Products',
    'FaceDetection',
    'WBFace',
    'BZCaptcha',
    'DTShareKit',
    'AliyunPlayerSDK.framework',
    'MGBaseKit.framework',
    'MGLivenessDetection.framework',
    'NETNIMSDK+Category',
    'protobuf',
    'BZNetwork',
    'CrashReporter',
    'iflyMSC.framework',
    'KZContacts',
    'MJRefreshCategory',
    'Expression',
    'DTShareKit.framework',
    'TencentOpenAPI.framework',
    'YTXMonitor.framework',
    'YTXOperators.framework',
    'ATAuthSDK.framework',
    'JXCategoryView',
    'JXPagerView',
    'TYRZUISDK.framework'
]

#特殊类
shopzp_ignoreClass = [
    'SPKeyValueStore'
]
bosszp_ignoreClass = [
    'TXSecurityUtils',
    'TXCommonUtils',
    'KZContactsUnits',
    'MJRefreshClearHeader',
    'BZHunterCompanyIconView',
    'BZStoreKitManager',
    'ForwardMateList',
    'BZAnalyzerManager',
    'TXCustomModel',
    'KeyChainManager',
    'BasicBaseTableCell',
    'BasicXmlBaseView'
]

moduleFiles = {}

regImportNamed = re.compile('#import "(.*?).h"')
regImport = re.compile('#import <(.*?).h>')

reghClass = re.compile('@interface (.*?):')
reghEnum = re.compile('(?<=typedef NS_ENUM\(int, )[_a-zA-Z0-9]+')
reghEnum2 = re.compile('(?<=typedef NS_ENUM\(NSUInteger, )[_a-zA-Z0-9]+')


#用于提取关键字的正则表达式
regFunc = re.compile(r'ROUTER_CLASSS_PROP[(]([_a-zA-Z]+)[)]')
regModule = re.compile(r'@interface[ ]+([_a-zA-Z]+Module)[ ]+:[ ]+NSObject')

# async def start_check(check_info: CheckInfo, project_path: str):
#     return check_unuse_class_new(project_path, check_info.scheme_name)

# 遍历所有文件夹，返回所有申明的类
def listAllPodClass(rootdir,resultlist):
    global reghClass

    ignoreRes = []
    if app_scheme_name == 'ShopZP':
        ignoreRes = shopzp_ignoreRes
    elif app_scheme_name == 'BossZP':
        ignoreRes = bosszp_ignoreRes

    for filename in os.listdir(rootdir):
        if ignoreRes.count(filename)>0:
            continue
        pathname = os.path.join(rootdir, filename)
        if (os.path.isfile(pathname)):
            #忽略每个模块的 Base.h文件
            if filename.endswith('.h') and not filename.endswith('Base.h'):
                htext = open(pathname).read()
                result_finditer = re.finditer(reghClass, htext)
                for m in result_finditer:
                    # BHHidableView<__covariant ObjectType 去除这种情况
                    if m.group(1).strip().find(' ') == -1 or  m.group(1).strip().find('<') == -1:
                        resultlist.append([m.group(1).strip(),pathname])
                
                result_finditer2 = re.finditer(reghEnum, htext)
                for m in result_finditer2:
                    resultlist.append([m.group(0).strip(),pathname])

                result_finditer3 = re.finditer(reghEnum2, htext)
                for m in result_finditer3:
                    resultlist.append([m.group(0).strip(),pathname])
                    
        elif(os.path.isdir(pathname)):
            if rootdir.find('Pods')!=-1:
                continue
            listAllPodClass(pathname,resultlist)

    return

def findDirCount(className,cdir):
    count = 0

    ignoreClass = []
    if app_scheme_name == 'ShopZP':
        ignoreClass = shopzp_ignoreClass
    elif app_scheme_name == 'BossZP':
        ignoreClass = bosszp_ignoreClass
    if ignoreClass.count(className)>0:
        return 1

    command = 'ag -G ".+\.(h|m|mm|xml|xib)$" --ignore *.framework -w "%s" %s'%(className, cdir)
    
    lines = []
    try:
        result = os.popen(command).read()
        lines = result.split('\n')
    except:
         print(command)
#    if className=='BBChatingCardModel':
#         print(result)

    for line in lines:
        if line=='':
            continue
            
        result_finditer1 = line.find('@interface '+className)
        result_finditer2 = line.find('@implementation '+className)
        result_finditer3 = line.find('.framework')
        result_finditer4 = line.find('customClass="'+className)
        result_finditer5 = line.find(className+'.m')

        temp = line.split(':')
        content = line
        if len(temp)>=3:
            content = temp[2]

        if result_finditer1==-1 and result_finditer2==-1 and result_finditer3==-1 and result_finditer4==-1 and result_finditer5==-1 and content.startswith('//')==False and content.startswith('#import')==False and content.find('IMP_BLOCK_SELF')==-1:
            count += 1

        if count>0:
            break

    if count==0:
        command1 = 'ag -c -G ".+\.plist" -w "%s" %s'%(className, cdir)
        result1 = os.popen(command1).read()
        if result1!='':
            count += 1

    return count

def findNoImportClass(className,cdir):
    if className.count('+')>0:
        return False

    # 组件内查找    
    total = findDirCount(className, os.path.join(topDir,cdir))

    if total>0:
        return False

    rely_modules = {}
    if app_scheme_name == 'ShopZP':
        rely_modules = shopzp_rely_modules
    elif app_scheme_name == 'BossZP':
        rely_modules = bosszp_rely_modules
    elif  app_scheme_name == 'BossHi':
        rely_modules = bosshi_rely_modules
    elif app_scheme_name == 'Orange':
        rely_modules = orange_rely_modules
    # 依赖组件查找
    newCdir = cdir

    # bossHi去除Modules
    if app_scheme_name == 'BossHi' or app_scheme_name == 'Orange':
        newCdir = cdir.split('/')[1]

    if newCdir in rely_modules:
        ary = rely_modules[newCdir]
        for mm in ary:
            if app_scheme_name == 'BossHi' or app_scheme_name == 'Orange':
                mm = 'Modules/' + mm
            total += findDirCount(className, os.path.join(topDir,mm))
            if total>0:
                return False
    # 壳工程内查找
    if app_scheme_name == 'ShopZP':

          #处理店长路由
        for route_path in shopzp_route_maps:
            total += findDirCount(className, os.path.join(topDir,route_path))

        total += findDirCount(className, os.path.join(topDir,base_modules))

    elif app_scheme_name == 'BossZP':
        total += findDirCount(className, os.path.join(topDir,base_modules))

    elif app_scheme_name == 'BossHi':
        total += findDirCount(className, os.path.join(topDir,bosshi_base_modules))

    elif app_scheme_name == 'Orange':
        total += findDirCount(className, os.path.join(topDir,orange_base_modules))

    if total>0:
        return False

    return True

# 检查输出当前模块没有用到的类
def findRedundantClass(cdir):
    allClassInSource = []
    result = []
    #找出来所有申明的类
    listAllPodClass(os.path.join(topDir,cdir),allClassInSource)

    #去重逻辑
    # allClassInSourceSet = set(allClassInSource)
    for arr in allClassInSource:
        if len(arr) == 2:
            className = arr[0]
            classPath = arr[1]
            # (filepath,className) = os.path.split(path)
            # 打印进度
            # print(classPath.split(topDir)[1])
            if findNoImportClass(className,cdir):
                result.append(arr)
    return result

# 检查无用类
def check_unuse_class_new(dir='',scheme_name=''):
    if len(dir) == 0:
        return []

    #记录项目scheme
    global app_scheme_name 
    app_scheme_name = scheme_name
    outList = []
    modules = []

    #记录项目路径
    global topDir 
    topDir = dir

    #boss和店长，壳工程和其他仓库同级，需要获取壳工程上层目录，遍历其他仓库
    if app_scheme_name == 'ShopZP':
        topDir  = os.path.dirname(dir)
        modules = shopzp_moules
    elif app_scheme_name == 'BossZP':
        topDir =os.path.dirname(dir)
        modules = bosszp_modules
    elif app_scheme_name == 'BossHi':
        modules = bosshi_modules
    elif app_scheme_name == 'Orange':
        modules = orange_modules

    print('无用头文件检测开始....')
    start_time = datetime.now()
    if len(modules) > 0:
        for module in modules:
            # bosshi组件名称，需要+Modules
            if app_scheme_name == 'BossHi' or app_scheme_name == 'Orange':
                module = 'Modules/' + module

            result = findRedundantClass(module)
            if len(result)>0:
                for arr in result:
                    if len(arr) == 2: 
                        data = {}
                        data["group_name"] = module
                        data["label"] = arr[0]
                        data["belong"] = ('/..' + arr[1].split(topDir)[1])
                        outList.append(data)
                        print(arr[0])
    else:
        #其它项目无用文件扫描
        result =  findRedundantClass(topDir)
        if len(result)>0:
            for arr in result:
                if len(arr) == 2:
                    data = {}
                    data["group_name"] = topDir
                    data["label"] = arr[0]
                    data["belong"] = ('/..' + arr[1].split(topDir)[1])
                    outList.append(data)
                    print(arr[0])
    print('无用头文件检测结束....')
    end_time = datetime.now()
    time_difference = end_time - start_time
    print(len(outList))
    print(time_difference)
    return outList

if __name__ == "__main__":
    check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/o2-2.9.3', 'Orange')

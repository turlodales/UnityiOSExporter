//
//  DetailsInfoData.h
//  IpaExporter
//
//  Created by 何遵祖 on 2016/11/3.
//  Copyright © 2016年 何遵祖. All rights reserved.
//

#import <Foundation/Foundation.h>

#define App_Name_Key @"appName"
#define App_ID_Key @"bundleIdentifier"
#define Code_Sign_Identity_Key @"codeSignIdentity"
#define Provisioning_Profile_key @"provisioningProfile"

@interface DetailsInfoData : NSObject
{
    NSString* _appName;
    NSString* _bundleIdentifier;
    NSString* _codeSignIdentity;
    NSString* _provisioningProfile;
}

-(void)setInfoWithAppName:(NSString*)appName
                    appID:(NSString*)appID
         codeSignIdentity:(NSString*)codeS
      provisioningProfile:(NSString*)profile;

@end
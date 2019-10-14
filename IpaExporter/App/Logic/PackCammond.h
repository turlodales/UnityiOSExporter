//
//  RubyCommand.h
//  IpaExporter
//
//  Created by 4399 on 5/28/19.
//  Copyright © 2019 何遵祖. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSNumber* CammondResult;
#define CAMM_EXIT @0
#define CAMM_SUCCESS @1

typedef NSNumber* CammondCode;
#define CAMM_CODE_EXPORT_XCODE @2
#define CAMM_CODE_EDIT_XCODE @3
#define CAMM_CODE_EXPORT_IPA @4
#define CAMM_CODE_GEN_RESFOLDER @5
#define CAMM_CODE_RUN_CUSTOM_SHELL @6
#define CAMM_CODE_ACTIVE_WND_TOP @7

@interface PackCammond : NSObject
{
@private
    __block BOOL _isExporting;
    NSMutableDictionary *_cammondCode;
}

@end

NS_ASSUME_NONNULL_END

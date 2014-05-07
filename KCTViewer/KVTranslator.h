//
//  KVTranslator.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-21.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KVTranslator : NSObject
{
	AFHTTPRequestOperationManager *_manager;
}

@property (nonatomic, strong) NSDictionary *tldata;
@property (nonatomic, strong) NSDictionary *reportBlacklist;

+ (instancetype)sharedTranslator;

- (NSString *)translate:(NSString *)line pathForReporting:(NSString *)path key:(NSString *)key;
- (NSData *)translateJSON:(NSData *)json pathForReporting:(NSString *)path;

@end

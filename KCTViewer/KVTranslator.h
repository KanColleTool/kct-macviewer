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
	NSMutableArray *reportQueue;
}

@property (nonatomic, strong) NSMutableDictionary *tldata;
@property (nonatomic, strong) NSDictionary *reportBlacklist;
@property (nonatomic, assign) BOOL reportingDisabledDueToErrors;

+ (instancetype)sharedTranslator;

- (NSString *)translate:(NSString *)line;
- (NSString *)translate:(NSString *)line pathForReporting:(NSString *)path key:(NSString *)key;
- (NSData *)translateJSON:(NSData *)json;
- (NSData *)translateJSON:(NSData *)json pathForReporting:(NSString *)path;

@end

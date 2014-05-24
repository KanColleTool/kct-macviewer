//
//  KVUserDataStore.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-13.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KVTempFileHandle.h"

@interface KVUserDataStore : NSObject

@property (nonatomic, readonly) NSString *dataPath, *cachePath;

+ (instancetype)sharedDataStore;

- (KVTempFileHandle *)cacheFileHandleForEndpoint:(NSString *)endpoint page:(NSUInteger)page;

@end

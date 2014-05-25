//
//  KVHTTPProtocol.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-15.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KVChunkTranslator.h"
#import "KVTempFileHandle.h"
#import <GCDAsyncSocket.h>

@interface KVHTTPProtocol : NSURLProtocol <NSURLConnectionDelegate,NSURLConnectionDataDelegate,GCDAsyncSocketDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) GCDAsyncSocket *toolSocket;
@property (nonatomic, strong) KVTempFileHandle *cacheFile;
@property (nonatomic, strong) KVChunkTranslator *translator;
@property (nonatomic, assign, getter=isInteresting) BOOL interesting;
@property (nonatomic, assign, getter=isTranslationEnabled) BOOL translationEnabled;

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client;
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;

- (void)startLoading;
- (void)stopLoading;
- (void)finishForwarding;

@end

//
//  KVHTTPProtocol.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-15.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KVChunkTranslator.h"

@interface KVHTTPProtocol : NSURLProtocol <NSURLConnectionDelegate,NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSOutputStream *toolStream;
@property (nonatomic, strong) AFHTTPRequestOperation *toolForwardOperation;
//@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, strong) KVChunkTranslator *translator;
@property (nonatomic, assign, getter=isInteresting) BOOL interesting;

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client;
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;

- (void)startLoading;
- (void)stopLoading;

//- (void)deliverResponse;

@end

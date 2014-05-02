//
//  KVHTTPProtocol.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-15.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import "KVHTTPProtocol.h"
#import "KVTranslator.h"

@implementation KVHTTPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	return [request.URL.scheme isEqualToString:@"http"] && ![request.URL.host isEqualToString:@"localhost"] && ![request.URL.host isEqualToString:@"127.0.0.1"] && [request.HTTPMethod isEqualToString:@"POST"] && ![[self class] propertyForKey:@"_handled" inRequest:request];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client
{
	if((self = [super initWithRequest:[request mutableCopy] cachedResponse:cachedResponse client:client]))
	{
		[(NSMutableURLRequest*)self.request setValue:@"Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0" forHTTPHeaderField:@"User-Agent"];
	}
	
	return self;
}

- (void)startLoading
{
	[[self class] setProperty:[NSNumber numberWithBool:YES] forKey:@"_handled" inRequest:(NSMutableURLRequest*)self.request];
	self.interesting = [self.request.URL.path hasPrefix:@"/kcsapi"];
	self.translator = [[KVChunkTranslator alloc] init];
	self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
}

- (void)stopLoading
{
	[self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if([self isInteresting])
	{
		NSData *translatedChunk = [_translator receivedChunk:data];
		if(translatedChunk)
			[self.client URLProtocol:self didLoadData:translatedChunk];
		else
		{
			// Bail out if the translator errors!
			[self.client URLProtocol:self didLoadData:data];
			self.interesting = NO;
		}
		
		if(self.buffer) [self.buffer appendData:data];
		else self.buffer = [data mutableCopy];
	}
	else
		[self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.client URLProtocol:self didFailWithError:error];
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[self forwardToTool];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.client URLProtocolDidFinishLoading:self];
	[self forwardToTool];
	self.connection = nil;
}

- (void)forwardToTool
{
	if([self isInteresting])
	{
		NSURL *toolURL = [NSURL URLWithString:@"http://127.0.0.1:54321/"];
		NSMutableURLRequest *toolRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.request.URL.path relativeToURL:toolURL]];
		toolRequest.HTTPMethod = @"POST";
		toolRequest.HTTPBody = self.buffer;
		
		AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:toolRequest];
		op.responseSerializer = [AFJSONResponseSerializer serializer];
		op.responseSerializer.acceptableStatusCodes = [NSMutableIndexSet indexSetWithIndex:200];
		[(NSMutableIndexSet*)op.responseSerializer.acceptableStatusCodes addIndex:404];
		[op start];
	}
	
	self.buffer = nil;
}

@end

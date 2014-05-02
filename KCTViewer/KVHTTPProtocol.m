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
	
	if([self isInteresting])
	{
		// Formulate a request to the tool
		NSURL *toolURL = [NSURL URLWithString:@"http://127.0.0.1:54321/"];
		NSMutableURLRequest *toolRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.request.URL.path relativeToURL:toolURL]];
		toolRequest.HTTPMethod = @"POST";
		
		self.toolForwardOperation = [[AFHTTPRequestOperation alloc] initWithRequest:toolRequest];
		
		// Create an input/output stream pair to stream data to the tool
		CFReadStreamRef readStream;
		CFWriteStreamRef writeStream;
		CFStreamCreateBoundPair(NULL, &readStream, &writeStream, 1024*4);
		self.toolStream = (__bridge NSOutputStream *)(writeStream);
		self.toolForwardOperation.inputStream = (__bridge NSInputStream *)(readStream);
		
		// Start it
		[self.toolForwardOperation start];
	}
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
	}
	else
		[self.client URLProtocol:self didLoadData:data];
	
	[self.toolStream write:[data bytes] maxLength:[data length]];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.client URLProtocol:self didFailWithError:error];
	[self.toolStream close];
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.client URLProtocolDidFinishLoading:self];
	[self.toolStream close];
	self.connection = nil;
}

@end

//
//  KVHTTPProtocol.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-15.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import "KVHTTPProtocol.h"
#import "KVTranslator.h"
#import "KVUserDataStore.h"
#import "NSString+KVUtil.h"

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
		
		// Save this value, since we don't want to start translating in the middle of a stream
		self.translationEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"translationEnabled"];
	}
	
	return self;
}

- (void)startLoading
{
	[[self class] setProperty:[NSNumber numberWithBool:YES] forKey:@"_handled" inRequest:(NSMutableURLRequest*)self.request];
	self.interesting = [self.request.URL.path hasPrefix:@"/kcsapi"];
	self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
	
	if([self isInteresting])
	{
		NSUInteger page = 0;
		if([self.request.HTTPBody length] <= 1024)
		{
			NSString *bodyString = [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding];
			NSDictionary *queryItems = [bodyString queryItems];
			page = (NSUInteger)[[queryItems objectForKey:@"api_page_no"] integerValue];
		}
		
		self.translator = [[KVChunkTranslator alloc] initWithPathForReporting:[self.request.URL.path lastPathComponent]];
		self.toolSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
		self.cacheFile = [[KVUserDataStore sharedDataStore] cacheFileHandleForEndpoint:self.request.URL.path page:page];
		
		NSError *error = nil;
		[self.toolSocket connectToHost:@"127.0.0.1" onPort:54321 error:&error];
		if(error)
		{
			NSLog(@"Couldn't connect to tool: %@", error);
			self.toolSocket = nil;
		}
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
		if([self isTranslationEnabled])
		{
			NSData *translatedChunk = [_translator receivedChunk:data];
			if(!translatedChunk)
			{
				// Bail out if the translator errors!
				NSLog(@"Translation Error!");
				
				self.interesting = NO;
				[self connection:connection didReceiveData:data];
				return;
			}
			
			[self.client URLProtocol:self didLoadData:translatedChunk];
		}
		else [self.client URLProtocol:self didLoadData:data];
		
		if(self.toolSocket)
		{
			NSMutableData *chunk = [[NSMutableData alloc] init];
			[chunk appendData:[[NSString stringWithFormat:@"%lx\r\n", (unsigned long)[data length]] dataUsingEncoding:NSUTF8StringEncoding]];
			[chunk appendData:data];
			[chunk appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
			[self.toolSocket writeData:chunk withTimeout:10 tag:1];
		}
	}
	else [self.client URLProtocol:self didLoadData:data];
	
	[self.cacheFile.fileHandle writeData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.client URLProtocol:self didFailWithError:error];
	[self finishForwarding];
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.client URLProtocolDidFinishLoading:self];
	[self finishForwarding];
	self.connection = nil;
}

- (void)finishForwarding
{
	[self.toolSocket writeData:[@"0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:10 tag:2];
	[self.toolSocket disconnectAfterReadingAndWriting];
	
	NSError *error = nil;
	[self.cacheFile closeAndOverwrite:&error];
	if(error)
		NSLog(@"Couldn't close and overwrite: %@", error);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
	NSLog(@"Connected to %@:%d", host, port);
	NSMutableData *httpHeader = [[NSMutableData alloc] init];
	[httpHeader appendData:[[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", self.request.HTTPMethod, self.request.URL.path] dataUsingEncoding:NSUTF8StringEncoding]];
	[httpHeader appendData:[[NSString stringWithFormat:@"Host: %@:%@\r\n", self.request.URL.host, (self.request.URL.port ? self.request.URL.port : @80)] dataUsingEncoding:NSUTF8StringEncoding]];
	[httpHeader appendData:[@"Transfer-Encoding: chunked\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[httpHeader appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[sock writeData:httpHeader withTimeout:0 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	//NSLog(@"-> Data with Tag %ld Written", tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// POSIX::61 = Connection refused; that just means that the Tool isn't running
	if(err.domain == NSPOSIXErrorDomain && err.code == 61)
		return;
	
	NSLog(@"--> Disconnected: %@", err);
}

@end

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
	return [request.URL.scheme isEqualToString:@"http"] /*&& ![request.URL.host isEqualToString:@"localhost"] && ![request.URL.host isEqualToString:@"127.0.0.1"]*/ && [request.HTTPMethod isEqualToString:@"POST"] && ![[self class] propertyForKey:@"_handled" inRequest:request];
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
	self.interesting = YES;//[self.request.URL.path hasPrefix:@"/kcsapi"];
	self.translator = [[KVChunkTranslator alloc] init];
	self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
	
	// Formulate a request to the tool
	NSURL *toolURL = [NSURL URLWithString:@"http://127.0.0.1:54321/"];
	NSMutableURLRequest *toolRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.request.URL.path relativeToURL:toolURL]];
	toolRequest.HTTPMethod = @"POST";
	
	// Create an input/output stream pair
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
	CFStreamCreateBoundPair(NULL, &readStream, &writeStream, 1024*4);
	self.toolStream = CFBridgingRelease(writeStream);
	toolRequest.HTTPBodyStream = CFBridgingRelease(readStream);
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
	// In the case of multipart requests, this may be called several times, in which case the
	// docs say we should empty the buffer before delivering the new response.
	//if([self.buffer length] > 0)
	//	[self deliverResponse];
	
	for(NSString *key in [(NSHTTPURLResponse*)response allHeaderFields])
		NSLog(@"%@ : %@", key, [[(NSHTTPURLResponse*)response allHeaderFields] objectForKey:key]);
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	// Deliver buffered data
	//[self deliverResponse];
	
	// Tell the client the request is finished
	[self.client URLProtocolDidFinishLoading:self];
	self.connection = nil;
	[self.toolStream close];
}

/*- (void)deliverResponse
{
	if(self.buffer)
	{
		NSURLRequest *request = [self request];
		NSLog(@"Delivering %@", request.URL);
		
		// This should always be true (we shouldn't have a buffer if the request is not interesting,
		// but it's always good to check a second time. That might change in the future or something.)
		if([self isInteresting] && [[NSUserDefaults standardUserDefaults] boolForKey:@"translationEnabled"])
		{
			NSLog(@"--> Performing Translation");
			// Deliver data to the client
			NSData *translatedData = [[KVTranslator sharedTranslator] translateJSON:self.buffer];
			[self.client URLProtocol:self didLoadData:translatedData];
			
			// Forward to the tool
			NSURL *toolURL = [NSURL URLWithString:@"http://127.0.0.1:54321/"];
			NSMutableURLRequest *toolRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.request.URL.path relativeToURL:toolURL]];
			toolRequest.HTTPMethod = @"POST";
			toolRequest.HTTPBody = self.buffer;
			AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:toolRequest];
			op.responseSerializer = [AFJSONResponseSerializer serializer];
			op.responseSerializer.acceptableStatusCodes = [NSMutableIndexSet indexSet];
			[(NSMutableIndexSet*)op.responseSerializer.acceptableStatusCodes addIndex:200];
			[(NSMutableIndexSet*)op.responseSerializer.acceptableStatusCodes addIndex:404];
			[op start];
		}
		// If this request is uninteresting, just feed the client the buffer, and wonder why
		// the heck we buffered the response in the first place.
		else
		{
			NSLog(@"--> Not Translating");
			[self.client URLProtocol:self didLoadData:self.buffer];
		}
		
		// Because properties' magical reference counting, this also releases the buffer
		self.buffer = nil;
	}
}*/

@end

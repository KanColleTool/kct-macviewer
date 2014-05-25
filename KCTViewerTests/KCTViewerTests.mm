//
//  KCTViewerTests.m
//  KCTViewerTests
//
//  Created by Johannes Ekberg on 2013-12-27.
//  Copyright (c) 2013 the KanColleTool team. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KVTranslator.h"
#import "NSURL+KVUtil.h"

@interface KCTViewerTests : XCTestCase

@end

@implementation KCTViewerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVersionComparison
{
	XCTAssertEqual([@"0.8.1" compare:@"0.8.2" options:NSNumericSearch], NSOrderedAscending, @"0.8.1 >= 0.8.2");
	XCTAssertEqual([@"0.8.2" compare:@"0.8.2" options:NSNumericSearch], NSOrderedSame, @"0.8.2 != 0.8.2");
	XCTAssertEqual([@"0.8.3" compare:@"0.8.2" options:NSNumericSearch], NSOrderedDescending, @"0.8.3 <= 0.8.2");
}

- (void)testURLQueryExtraction
{
	NSURL *url = [NSURL URLWithString:@"http://localhost/?param1=test&param2=%E3%83%86%E3%82%B9%E3%83%88"];
	NSDictionary *queryItems = [url queryItems];
	
	XCTAssertEqualObjects([queryItems objectForKey:@"param1"], @"test", @"ASCII query item is incorrect");
	XCTAssertEqualObjects([queryItems objectForKey:@"param2"], @"テスト", @"Escaped Japanese query item is incorrect");
}

- (void)testTranslation
{
	// Local translator instance - not a shared one, the last thing I need right now is singletons
	KVTranslator *translator = [[KVTranslator alloc] init];
	
	// Set up some test data - 那珂 (Naka) has a translation, まるゆ (Maruyu) doesn't
	translator.tldata = [@{ @"124853853": @"Naka", @"3440185848": [NSNull null] } mutableCopy];
	
	// Try translating a translated string (Naka/那珂)
	XCTAssertEqualObjects([translator translate:@"那珂"], @"Naka", @"那珂 doesn't translate to Naka!");
	XCTAssertEqualObjects([translator translate:@"\\u90A3\\u73C2"], @"Naka", @"那珂 (escaped) doesn't translate to Naka!");
	
	// Try translating an unknown string (tesuto/テスト)
	XCTAssertEqualObjects([translator translate:@"テスト"], @"テスト", @"Unknown strings aren't untouched!");
	XCTAssertEqualObjects([translator translate:@"\\u30C6\\u30B9\\u30C8"], @"\\u30C6\\u30B9\\u30C8", @"Unknown Escaped strings aren't untouched!");
	
	// Try translating an untranslated string (Maruyu/まるゆ)
	XCTAssertEqualObjects([translator translate:@"まるゆ"], @"まるゆ", @"Untranslated strings aren't untouched!");
	XCTAssertEqualObjects([translator translate:@"\\u307E\\u308B\\u3086"], @"\\u307E\\u308B\\u3086", @"Untranslated Escaped strings aren't untouched!");
}

- (void)testJSONTranslation
{
	// Make a local translator
	KVTranslator *translator = [[KVTranslator alloc] init];
	
	// Prepare a test server response and translation data
	NSDictionary *testResponse = @{ @"api_result": @1, @"api_result_msg": @"成功", @"api_data": @{		// 成功 = Success
												@"api_data_translatable_string": @"那珂",				// 那珂 = Naka
												@"api_data_untranslatable_string": @"テスト",
												@"api_data_number": @42,
												@"api_data_dict": @{
														@"api_data_l2_translatable_string": @"金剛",		// 金剛 = Kongou
														@"api_data_l2_untranslatable_string": @"おっぱい",
														@"api_data_l2_number": @1337,
														},
												@"api_data_array": @[ @"赤城", @"加賀" ]					// 赤城 = Akagi, 加賀 = Kaga
												} };
	translator.tldata = [@{
						  @"1140633492": @"Success",
						  @"124853853": @"Naka",
						  @"2751887919": @"Kongou",
						  @"34282435": @"Akagi",
						  @"3302450663": @"Kaga"
						  } mutableCopy];
	
	// Encode the response
	NSError *serializationError = nil;
	NSData *testResponseData = [NSJSONSerialization dataWithJSONObject:testResponse options:NSJSONWritingPrettyPrinted error:&serializationError];
	XCTAssertNil(serializationError, @"Serialization Error");
	
	// Try to translate it
	NSData *translatedData = [translator translateJSON:testResponseData];
	XCTAssertNotNil(translatedData, @"Translator returned no data");
	
	// Decode it
	NSError *deserializationError = nil;
	NSDictionary *translatedResponse = [NSJSONSerialization JSONObjectWithData:translatedData options:NSJSONReadingMutableContainers error:&deserializationError];
	XCTAssertNil(deserializationError, @"Deserialization error");
	
	// Sanity check it
	XCTAssertNotEqualObjects(testResponse, translatedResponse, @"The translator didn't even touch the data");
	
	XCTAssertEqualObjects(translatedResponse[@"api_result"], @1, @"api_result changed");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_number"], @42, @"L1 number changed");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_dict"][@"api_data_l2_number"], @1337, @"L2 number changed");
	
	XCTAssertEqualObjects(translatedResponse[@"api_result_msg"], @"Success", @"L0 Translation incorrect");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_translatable_string"], @"Naka", @"L1 Translation incorrect");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_dict"][@"api_data_l2_translatable_string"], @"Kongou", @"L2 Translation incorrect");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_array"][0], @"Akagi", @"L2A:0 Translation Incorrect");
	XCTAssertEqualObjects(translatedResponse[@"api_data"][@"api_data_array"][1], @"Kaga", @"L2A:1 Translation Incorrect");
}

@end

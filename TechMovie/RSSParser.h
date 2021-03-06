//
//  RSSParser.h
//  TestRSSReader
//
//  Created by 達郎 植田 on 12/07/08.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RSSEntry;
@interface RSSParser : NSObject<NSXMLParserDelegate>
{
    int             _totalLines;
    BOOL            _newEntryComes;
    id              _performer;
}

// RSSの記事の配列
// 配列内の要素は「RSSEntry」クラスのインスタンスとする
@property (strong) NSMutableArray *entries;

// 解析中の情報
@property (strong, nonatomic) NSMutableArray *elementStack;
@property (strong, nonatomic) RSSEntry *curEntry;
@property float realProgress;
@property NSArray *oldFeeds;


- (BOOL)parseContentsOfURL:(NSURL *)url fileName:(NSString *)fileName performer:(id)performer;
- (NSDate *)pubDateWithString:(NSString *)string;

@end

//
//  RSSParser.m
//  TestRSSReader
//
//  Created by 達郎 植田 on 12/07/08.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"
#import "RSSEntry.h"
#import "NSURL+OgImage.h"
#import <AFNetworking/AFNetworking.h>
#import "NSString+URLEncode.h"
#import "FeedsTableViewController.h"
#import "NSString+OgImage.h"

@implementation RSSParser

@synthesize entries = _entries;
@synthesize elementStack = _elementStack;
@synthesize curEntry = _curEntry;

- (id)init
{
    self = [super init];
    if (self) {
        
        // インスタンス変数の初期化
        _entries = nil;
        _elementStack = [[NSMutableArray alloc] init];
        _curEntry = nil;
        _performer = nil;
    }
    return self;
}

// URLからRSSファイルを読み込む
// ここではRSS2.0のみ対応する
- (BOOL)parseContentsOfURL:(NSURL *)url fileName:(NSString *)fileName performer:(id)performer
{
    _performer = performer;
    BOOL ret = NO;
    
    // 行数をカウントする
    NSError *error = nil;
    NSString *xmlFileString = [NSString stringWithContentsOfURL:url
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    _totalLines = [xmlFileString componentsSeparatedByString:@"\n"].count;
    
    // XMLパーサーの準備
    NSXMLParser *parser;
    NSLog(@"RSSParser.m: parser init");
    parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    NSLog(@"RSSParser.m: parser init done");

    // 通知を作成する
    NSString *EnableRefreshBotton = [NSString stringWithFormat:@"EnableRefreshBotton"];
    NSNotification *n = [NSNotification notificationWithName:EnableRefreshBotton object:self];
    // 通知実行！
    [[NSNotificationCenter defaultCenter] postNotification:n];

    parser.delegate = self;
    
    // エントリーを入れる配列をクリアする
    @try {
        self.entries = [NSMutableArray arrayWithCapacity:0];
    }
    @catch (NSException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] init];
        alert.title = [NSString stringWithFormat:@"エラー"];
        alert.message = [NSString stringWithFormat:@"%@", exception];
        alert.delegate = self;
        [alert addButtonWithTitle:@"OK"];
        [alert show];
    }
    
    // 以前ダウンロードしたフィードを用意する
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString *oldFileName = [NSString stringWithFormat:@"%@", fileName];
    NSString *filePath = [directory stringByAppendingPathComponent:oldFileName];
    @try {
        self.oldFeeds = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    }
    @catch (NSException *exception) {
        UIAlertView *alertView = [[UIAlertView alloc] init];
        alertView.title = @"エラー";
        alertView.message = [NSString stringWithFormat:@"%@", exception];
        alertView.delegate = self;
        [alertView addButtonWithTitle:@"了解"];
        [alertView show];
        
        [[_performer weakOperation] cancel];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    }
    
    // 解析開始
    if ([parser parse]) {
        
        // アイテムが一つでも取得できていれば成功とする
        if (self.entries.count > 0) {
            ret = YES;
        }
    }
    
    // 中間データを削除する
    [self.elementStack removeAllObjects];
    self.curEntry = nil;
    
    return ret;
}

// エレメント開始時の処理
- (void)parser:(NSXMLParser *)parser 
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName 
    attributes:(NSDictionary *)attributeDict
{
    // エレメント位置を把握するためにスタックにエレメント名を追加する
    [self.elementStack addObject:elementName];
    
    if ([elementName isEqualToString:@"enclosure"])
    /*
     vimeoのURLはenclosureタグのurl属性に書かれている
     まずはこのurlを取り出したい
     */
    {
        NSLog(@"%@", attributeDict[@"url"]);
    }
}

// エレメント終了時の処理
- (void)parser:(NSXMLParser *)parser 
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName
{
    // 「キャンセル」されたら止める
    if([_performer weakOperation].isCancelled){
        parser.delegate = nil;
        return;
    }
    
    // エレメント位置を把握するためのスタックからエレメント名を削除する
    [self.elementStack removeLastObject];
    
    // 終了したエレメントの名前が「item」で現在解析中のエントリーがある場合は、
    // 配列「_entries」に追加して、解放する
    if ([elementName isEqualToString:@"item"] && self.curEntry)
    {
        [self.entries addObject:_curEntry];
        self.curEntry = nil;
    }
    else if ([elementName isEqualToString:@"description"])
    {
        //ogImageを抜き出す
        if ([[self elementPath] isEqualToString:@"/rss/channel/item"])
        {
            NSString *str = [self currentEntry].text;
            //ogImageを抜き出す
            [self currentEntry].ogImageURL = [NSURL ogImageURLWithVimeoDescription:str];
            if (![self currentEntry].ogImageURL)
            {
                [self currentEntry].ogImageURL = [NSURL ogImageURLWithNicoDescription:str];
            }
            if (![self currentEntry].ogImageURL)
            {
                NSLog(@"ogImageURL: %@", [self currentEntry].ogImageURL);
                [self currentEntry].ogImageURL = [NSURL ogImageURLWithURL:[self currentEntry].url];
            }
            str = [NSString ogImageURLWithNicoDescription:str];
            str = [NSString ogImageURLWithVimeoDescription:str];
            [self currentEntry].text = str;
        }
    }
}

// エレメントスタックをファイルパスのような文字列にする
- (NSString *)elementPath
{
    NSMutableString *path = [NSMutableString stringWithCapacity:0];
    
    for (NSString *str in self.elementStack) {
        
        [path appendFormat:@"/%@", str];
    }
    return path;
}

// 現在解析中のエントリーを返す
- (RSSEntry *)currentEntry
{
    if (!self.curEntry) {
        
        // まだ解析中のエントリーがないので新しく作成する
        self.curEntry = [[RSSEntry alloc] init];
    }
    return self.curEntry;
}

// 文字列が見つかったときに呼ばれる
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    // 「キャンセル」されたら止める
    if([_performer weakOperation].isCancelled){
        
        return;
    }

    // エレメント位置によってテキストノードの意味が異なる
    // 位置の判定を容易にするため、ファイルパスのような文字列にする
    NSString *str = [self elementPath];
    
    // 作成した文字列を使って判定する
    if ([str isEqualToString:@"/rss/channel/item/title"]) {
        
        // 記事のタイトル
        NSString *str = [[self currentEntry] title];
        
        if (str) {
            str = [str stringByAppendingString:string];
        }
        else {
            str = string;
        }
        [[self currentEntry] setTitle:str];
    }
    else if ([str isEqualToString:@"/rss/channel/item/pubDate"]) {
        
        // 記事の日時
        NSDate *date = [self pubDateWithString:string];
        [[self currentEntry] setDate:date];
    }
    else if ([str isEqualToString:@"/rss/channel/item/description"]) {
        
        // 記事の本文
        NSString *str = [[self currentEntry] text];
                
        if (str) {
            str = [str stringByAppendingString:string];
        }
        else {
            str = string;
        }
        
        [[self currentEntry] setText:str];
        
    }
    else if ([str isEqualToString:@"/rss/channel/item/link"]) {
        
        // 記事のアドレス
        NSURL *url = [NSURL URLWithString:string];
        [[self currentEntry] setUrl:url];
        
        // _oldFeedsが空のときは[self currentEntry]はすべてisNewEntry
        if (_oldFeeds.count == 0) {
            [self currentEntry].isNewEntry = YES;
        }
#ifdef TEST
#else
        
        // _oldFeedsが空でないときは[self currentEntry]と照合してurlが同じ物があれば既得エントリーとみなす
        for (RSSEntry *entry in _oldFeeds) {
            if ([url isEqual:entry.url]) {
                [[self currentEntry] setDate:entry.date];
                [[self currentEntry] setText:entry.text];
                [[self currentEntry] setOgImageURL:entry.ogImageURL];
                [[self currentEntry] setIsNewEntry:NO];
                
                // どっちが正しいの？
                return;
                //                break;
            }
            // 既得エントリーでなければ新規エントリー
            [[self currentEntry] setIsNewEntry:YES];
        }
#endif
#define TEST2
#ifdef TEST2
#else
        if (![[self currentEntry] ogImageURL]) {
            
            // 該当ページのog:imageを取得する
            [self currentEntry].ogImageURL = [NSURL ogImageURLWithURL:url];
            
            // og:imageがない場合
            NSLog(@"ogImage does not exist: %@", [self currentEntry].ogImageURL);
            if ([self currentEntry].ogImageURL == nil) {
                
                // はてなAPIに問い合わせるURLをつくる
                NSString *urlStringHatena = @"http://b.hatena.ne.jp/entry/jsonlite/?url=";
                NSString *urlStringTarget = [NSString stringWithFormat:@"%@", url];
                
                urlStringTarget = [urlStringTarget urlEncodeUsingEncoding:NSASCIIStringEncoding];
                
                NSString *urlStringWhole = [NSString stringWithFormat:@"%@%@", urlStringHatena, urlStringTarget];
                NSURL *hatenaAPIURL = [NSURL URLWithString:urlStringWhole];
                
                // はてなAPIにリクエストを送り、返ってきたJSONを解析してスクリーンショットのURLを見つけ出す
                NSURLRequest *request = [NSURLRequest requestWithURL:hatenaAPIURL];
                __block NSURL *ssURL = nil;
                AFJSONRequestOperation *operation =
                [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                    ssURL = [NSURL URLWithString:[JSON valueForKeyPath:@"screenshot"]];
                    [self currentEntry].ogImageURL = ssURL;
                } failure:nil];
                NSOperationQueue *queue = [[NSOperationQueue alloc] init];
                [queue addOperation: operation];
                [queue waitUntilAllOperationsAreFinished];
            }
            //         }];
        }
#endif
    }
}

// RSS2.0の表記方法で書かれた日時からオブジェクトを取得する
- (NSDate *)pubDateWithString:(NSString *)string
{
    NSDate *date = nil;
    
    // スペース区切りで文字列を分割する
    NSArray *tokens = [string componentsSeparatedByString:@" "];
    
    // 区切った文字列から日時の情報を構築する
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    
    // 最低限、4つ必要とする（曜日、日、月、年）
    if (tokens.count >= 4) {
        
        // タイムゾーン
        NSTimeZone *tz = [NSTimeZone localTimeZone];
        
        // 日
        [comps setDay:[[tokens objectAtIndex:1] integerValue]];
        
        // 年
        [comps setYear:[[tokens objectAtIndex:3] integerValue]];
        
        // 月を文字列から変換するため、配列を作成する
        NSArray *monthNames = [NSArray arrayWithObjects:
                               @"Jan", @"Feb", @"Mar", @"Apr",
                               @"May", @"Jun", @"Jul", @"Aug",
                               @"Sep", @"Oct", @"Nov", @"Dec", nil];
        NSInteger month = [monthNames indexOfObject:[tokens objectAtIndex:2]];
        if (month != NSNotFound) {
            
            // インデックス番号は0から始まるので、1足す
            [comps setMonth:month + 1];
            
            // 時間は「：」で区切る
            if (tokens.count > 4) {
                
                NSArray *timeTokens = [[tokens objectAtIndex:4] componentsSeparatedByString:@":"];
                
                // 時を読み込む
                if (timeTokens.count > 0) {
                    [comps setHour:[[timeTokens objectAtIndex:0] integerValue]];
                }
                
                // 分を読み込む
                if (timeTokens.count > 1) {
                    [comps setMinute:[[timeTokens objectAtIndex:1] integerValue]];
                }
                
                // 秒を読み込む
                if (timeTokens.count > 2) {
                    [comps setSecond:[[timeTokens objectAtIndex:2] integerValue]];
                }
                
                // タイムゾーンを読み込む
                if (tokens.count > 5) {
                    
                    NSString *timezoneStr = [tokens objectAtIndex:5];
                    
                    if (timezoneStr.length >= 4) {
                        
                        // うしろ4文字はオフセット値
                        // その前は符号
                        NSString *hOffset = [timezoneStr substringWithRange:
                                             NSMakeRange(timezoneStr.length - 4, 2)];
                        NSString *mOffset = [timezoneStr substringFromIndex:(timezoneStr.length - 2)];
                        NSInteger sign = 1;
                        
                        // 符号がついていれば、符号を調べる
                        if (timezoneStr.length > 4) {
                            
                            unichar uc;
                            uc = [timezoneStr characterAtIndex:(timezoneStr.length - 5)];
                            
                            if (uc == L'-') {
                                sign = -1;
                            }
                        }
                        
                        // 読み込んだ文字列からオフセット秒を計算する
                        NSInteger offsetSecond =
                        hOffset.integerValue * 3600 +
                        mOffset.integerValue * 60;
                        offsetSecond *= sign;
                        
                        // タイムゾーンを取得する
                        tz = [NSTimeZone timeZoneForSecondsFromGMT:offsetSecond];
                    }
                }
            }
            // 日付を取得する
            NSCalendar *calendar;
            calendar = [[NSCalendar alloc]
                        initWithCalendarIdentifier:NSGregorianCalendar];
            calendar.timeZone = tz;
            
            date = [calendar dateFromComponents:comps];
        }
    }
    return date;
}

@end
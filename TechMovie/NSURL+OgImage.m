//
//  NSURL+OgImage.m
//  GetOgImage
//
//  Created by 達郎 植田 on 12/08/01.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "NSURL+OgImage.h"
#import "NSString+Encode.h"

@implementation NSURL (OgImageURL)

/*
 HTMLからog:imageのアドレスを取得する
 */
+ (NSURL *)extractImageURLFromHTML:(NSString *)html withRegularExpression:(NSString *)str
{
    /*
     * og:image Check for Vimeo
     */
    // prepare regular expression to find text
    NSError *error   = nil;
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern: str options:0 error:&error];
    
    // エラーならば表示する
    if (error != nil) {
        NSLog(@"%@", error);
    }
    
    // find by regular expression
    NSTextCheckingResult *match =
    [regexp firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
    
    // get the first result
    NSRange resultRange = [match rangeAtIndex:0];
    if (match) {
        
        // get the og:image URL from the find result
        NSRange urlRange = NSMakeRange(resultRange.location + 1, resultRange.length - 2);
        
        // og:image URL
        return [NSURL URLWithString:[html substringWithRange:urlRange]];
    }
    
    return nil;
}

// get URL of og:image by [NSURL ogImageWithURL:url]
+ (NSURL *)ogImageURLWithVimeoDescription:(NSString *)html
{
    NSURL* u = [self extractImageURLFromHTML:html withRegularExpression:@"\"http://b.vimeocdn.com.+.jpg\""];
    return u;
}

// get URL of og:image by [NSURL ogImageWithURL:url]
+ (NSURL *)ogImageURLWithNicoDescription:(NSString *)html
{
    NSURL* u = [self extractImageURLFromHTML:html withRegularExpression:@"\"http://.+\\.smilevideo\\.jp/smile\\?i=[0-9]{8}+\""];
    return u;
}

// get URL of og:image by [NSURL ogImageWithURL:url]
+ (NSURL *)ogImageURLWithURL:(NSURL *)url
{
    // Get the web page HTML
    NSString *data_str = [NSString encodedStringWithContentsOfURL:url];

    // prepare regular expression to find text
    NSError *error   = nil;
    NSRegularExpression *regexp =
    [NSRegularExpression regularExpressionWithPattern:
     @"<meta property=\"og:image\" content=\".+\""
                                              options:0
                                                error:&error];

    // find by regular expression
    NSTextCheckingResult *match =
    [regexp firstMatchInString:data_str options:0 range:NSMakeRange(0, data_str.length)];

    // get the first result
    NSRange resultRange = [match rangeAtIndex:0];
    NSLog(@"match=%@", [data_str substringWithRange:resultRange]);

    if (match) {

        // get the og:image URL from the find result
        NSRange urlRange = NSMakeRange(resultRange.location + 35, resultRange.length - 35 - 1);

        // make image with data from og:image URL
        return [NSURL URLWithString:[data_str substringWithRange:urlRange]];
    }
    return nil;
}


@end

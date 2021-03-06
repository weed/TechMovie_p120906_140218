//
//  FeedsTableViewController.m
//  TechMovie
//
//  Created by 達郎 植田 on 12/07/11.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "FeedsTableViewController.h"
#import "RSSParser.h"
#import "RSSEntry.h"
#import "WebViewController.h"
//#import "GANTracker.h"
#import "Const.h"

#define TEST
#define FREE

//const NSString *kStrURLPipesWith2Keywords = @"http://p120908-new-movies-server.herokuapp.com/new_movie?";
const NSString *kStrURLPipesWith2Keywords =
@"http://pipes.yahoo.com/pipes/pipe.run?_id=d6736f52235d6c16befbf95d7320fd1e&_render=rss&";
const NSString *kStrURLPipesWith1Keyword = @"http://p120908-new-movies-server.herokuapp.com/new_movie?";

@interface FeedsTableViewController ()

@end

@implementation FeedsTableViewController
@synthesize itemsArray = _itemsArray;
@synthesize tableView = _tableView;
@synthesize weakOperation;

// リストアイテムのソート用関数
// 日付の降順ソートで使用する
static NSInteger dateDescending(id item1, id item2, void *context)
{
    // ここでは比較対象が必ず「RSSListTableDataSource」クラスの
    // 「_listItemsArray」の要素となる（それ以外の場所から呼び出さないため）
    
    NSDate *date1 = [item1 date];
    NSDate *date2 = [item2 date];
    
    return [date2 compare:date1];
}

// Storyboardファイルからインスタンスが作成されたときに
// 使われるイニシャライザメソッド
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        // インスタンス変数の初期化
        _itemsArray = nil;
        ogImages = [NSMutableArray array];
        bkmImages = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // デフォルトの通知センターを取得する
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // 通知センターに通知要求を登録する
    // この例だと、通知センターに"requestTableData"という名前の通知がされた時に、
    // requestTableDataメソッドを呼び出すという通知要求の登録を行っている。
    NSString *requestTableData = [NSString stringWithFormat:@"requestTableData"];
    [nc addObserver:self selector:@selector(requestTableData) name:requestTableData object:nil];

    NSString *EnableRefreshBotton = [NSString stringWithFormat:@"EnableRefreshBotton"];
    [nc addObserver:self selector:@selector(enableRefreshBotton) name:EnableRefreshBotton object:nil];
}

- (void)viewDidUnload
{
    [self setTableView:nil];
    [self setItemsArray:nil];
    [self setBanner:nil];
    [self setRefreshButton:nil];
    [self setBannerImageView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    // 親クラスの処理を呼び出す
    [super viewWillAppear:animated];
    
    // ユーザーデフォルトからキーワードを読み込む
    NSString *keywordPlainString0 = [[NSUserDefaults standardUserDefaults] objectForKey:@"keyword0"];
    
    // ナビゲーションバーの表示を変更する
    [self reloadNavBarTitleWithString:keywordPlainString0];
    
    /*
    // Google Analytics
    NSString *trackPageTitle = [NSString stringWithFormat:@"/tableView/%@", keywordPlainString0];
    NSError *error;
    if (![[GANTracker sharedTracker] trackPageview:trackPageTitle withError:&error]) {
        // エラーハンドリング
    }
     */
#ifdef FREE
    // WebViewからの戻りならフラグを元に戻す
    BOOL b = [[NSUserDefaults standardUserDefaults] boolForKey:didGoToWebView];
    if (b) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:didGoToWebView];
    }
#endif
    
    NSInteger numAct = [[NSUserDefaults standardUserDefaults] integerForKey:@"numAct"];
    if (5 < numAct) {
        _bannerImageView.image = [UIImage imageNamed:@"banner.png"];
    }
}

- (void)requestTableData
{
    NSLog(@"FeedsTableViewController.m: #requestTableData");
    if (!_refreshButton.enabled) {
        return;
    }
    _refreshButton.enabled = NO;
    
    // URLの配列を作成するためユーザーデフォルトからキーワードを読み込む
    NSString *keywordPlainString0 = [[NSUserDefaults standardUserDefaults] objectForKey:@"keyword0"];
    NSString *keywordPlainString1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"keyword1"];

    // ナビゲーションバーの表示を変更する
    [self reloadNavBarTitleWithString:keywordPlainString0];
    
    // 「読込中」のアラートビューを表示する
    parsingAlertView = [[UIAlertView alloc] initWithTitle:@"読み込んでいます"
                                                        message:@"\n\n"
                                                       delegate:self
                                              cancelButtonTitle:@"キャンセル"
                                              otherButtonTitles:nil];
    [parsingAlertView show];
    
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    weakOperation = operation;
    [operation addExecutionBlock:^{
        /*
         * サーバーに問い合わせるURLをつくる
         */
        NSString *escapedUrlString0 = [keywordPlainString0
                                       stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *escapedUrlString1 = @"";
        NSString *myPipeURLString;
        if ([keywordPlainString1 isEqualToString:@""]) {
            myPipeURLString =
            [NSString stringWithFormat:@"%@&tag1=%@", kStrURLPipesWith1Keyword, escapedUrlString0];
        }
        else{
            escapedUrlString1 = [keywordPlainString1 stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            myPipeURLString =
            /*
             オリジナル
            [NSString stringWithFormat:@"%@&tag1=%@&tag2=%@", kStrURLPipesWith2Keywords, escapedUrlString0, escapedUrlString1];
             */
            /*
             Yahoo Pipes用
             */
            [NSString stringWithFormat:@"%@&tag0=%@&tag1=%@", kStrURLPipesWith2Keywords, escapedUrlString0, escapedUrlString1];
        }
#ifdef TEST
        NSLog(@"%@", myPipeURLString);
#endif
        
        // urlArrayをつくる
        // RSSリーダーの名残
        NSArray *urls = [NSArray arrayWithObject:myPipeURLString];
        NSMutableArray *urlArray = [NSMutableArray array];
        for (NSString *str in urls) {
            NSURL *url = [NSURL URLWithString:str];
            if (url) {
                [urlArray addObject:url];
            }
        }
        
        // 「URLエスケープした文字列0__URLエスケープした文字列1.dat」に保存する
        NSString *fileName = [NSString stringWithFormat:@"%@__%@.dat", escapedUrlString0, escapedUrlString1];
        
        // 「キャンセル」されたら止める
        if(weakOperation.isCancelled){
            return;
        }

        // RSSファイルを読み込む
        [self reloadFromContentsOfURLsFromArray:urlArray fileName:fileName performer:self];
        
        // 「キャンセル」されたら止める
        if(weakOperation.isCancelled){
            return;
        }

        /*
         * 検索結果を保存する
         */
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *directory = [paths objectAtIndex:0];
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        BOOL successful = [NSKeyedArchiver archiveRootObject:self.itemsArray toFile:filePath];
        if (successful) {
            NSLog(@"%@", @"データの保存に成功しました。");
        }
        
        // メインスレッドに戻す
        NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
        [mainQueue addOperationWithBlock:^{
            
            /*
             * 検索結果を整えて表示する
             */
            // テーブル更新
            [parsingAlertView dismissWithClickedButtonIndex:0 animated:YES];
            [self.tableView reloadData];
            
            // テーブルの一番上へ
            [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            
            // 新着動画の件数を表示する
            NSInteger numNewEntry = 0;
            for (RSSEntry *entry in self.itemsArray) {
                if (entry.isNewEntry) {
                    numNewEntry++;
                }
            }
            
            // performselectoer:judgeServerAliveをキャンセルする
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(judgeServerAlive) object: nil];

            UIAlertView *av = [[UIAlertView alloc] init];
            if (numNewEntry > 0) {
                av.title = [NSString stringWithFormat:@"%d 件の新着動画があります",numNewEntry];
            }
            else {
                av.title = @"新着動画はありません";
            }
            av.message = nil;
            av.delegate = self;
            [av addButtonWithTitle:@"OK"];
            [av show];
            
            /*
            // Google Analytics
            NSString *trackPageTitle = [NSString stringWithFormat:@"/alertView/%@:%d", keywordPlainString0, numNewEntry];
            NSError *error;
            if (![[GANTracker sharedTracker] trackPageview:trackPageTitle withError:&error]) {
                // エラーハンドリング
            }
             */
        }];
    }];
    
    // 別スレッドを立てる
    queue = [[NSOperationQueue alloc] init];
    [queue addOperation:operation];
        
}

#pragma mark - Table view data source

// リストテーブルのアイテム数を返すメソッド
// 「UITableViewDataSource」プロトコルの必須メソッド
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.itemsArray.count;
}

// リストテーブルに表示するセルを返すメソッド
// 「UITableViewDataSource」プロトコルの必須メソッド
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    // 範囲チェックを行う
    if (indexPath.row < self.itemsArray.count) {
        
        // セルを作成する
        cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
        
        // og:imageのビュー
        UIImageView *imageViewOgImage = (UIImageView *)[cell viewWithTag:5];
        NSURL *ogImageURL = [[self.itemsArray objectAtIndex:indexPath.row] ogImageURL];

        if (ogImageURL != nil) {
            UIImage* li = [UIImage animatedGIFNamed:@"loading3"];
            [imageViewOgImage setImageWithURL:ogImageURL
                             placeholderImage:li];
        }
        else {
            UIImage *noImage = [UIImage imageNamed:@"noImage2.png"];
            imageViewOgImage.image = noImage;
        }
        
        // 文字列を設定する
        UILabel *labelTitle = (UILabel*)[cell viewWithTag:1];
        UILabel *labelDate = (UILabel*)[cell viewWithTag:2];
        UILabel *labelDetail = (UILabel*)[cell viewWithTag:3];
        UILabel *labelHatebuNumber = (UILabel*)[cell viewWithTag:4];
        UILabel *labelNew = (UILabel*)[cell viewWithTag:6];
        
        // タイトルラベル
        labelTitle.text = [[NSString alloc] initWithString:
                       [[self.itemsArray objectAtIndex:indexPath.row] title]];
        
        // 「N日前」というラベル
        NSDate *datePub = [[self.itemsArray objectAtIndex:indexPath.row] date];
        NSTimeInterval t = [datePub timeIntervalSinceNow];
        NSInteger intervalDays = - t / (60 * 60 * 12);
        labelDate.text = [[NSString alloc] initWithFormat:@"%d 日前", intervalDays];
        
        // 「NEW」ラベル
        if ([[self.itemsArray objectAtIndex:indexPath.row] isNewEntry]) {
            labelNew.text = @"新着";
        }
        else {
            labelNew.text = nil;
        }

        // 詳細ラベル
        // nilチェックしないとクラッシュする
        NSString *s = [[self.itemsArray objectAtIndex:indexPath.row] text];
        if (s == nil) {
            labelDetail.text = @"";
        }
        else {
            labelDetail.text = [[NSString alloc] initWithString:s];
        }
        
        // はてブ数初期化
        labelHatebuNumber.text = @"";
        
        // はてなに問い合わせるURLをつくる
        NSString *urlStringHatena = @"http://b.hatena.ne.jp/entry/jsonlite/?url=";
        NSString *urlStringTarget = 
        [NSString stringWithFormat:@"%@", [[self.itemsArray objectAtIndex:indexPath.row] url]];
        NSString *urlStringWhole = [NSString stringWithFormat:@"%@%@", urlStringHatena, urlStringTarget];
        NSURL *url = [NSURL URLWithString:urlStringWhole];
        
        // リクエストを送り、返ってきたJSONを解析してはてブ数を見つけ出す
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc]
                                             initWithRequest:request];
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id JSON)
        {
            NSInteger count = [[JSON valueForKeyPath:@"count"] integerValue];
            
            // はてブ数を表示させる
            labelHatebuNumber.text = [NSString stringWithFormat:@"%d users", count];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            // Handle error
        }];
        
        /*
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSInteger count = [[JSON valueForKeyPath:@"count"] integerValue];
            
            // はてブ数を表示させる
            labelHatebuNumber.text = [NSString stringWithFormat:@"%d users", count];
        } failure:nil];
         */
        
        [operation start];
    }
    return cell;
}

// URLの配列を受け取り、「_listItemsArray」の内容を設定するメソッド
// 配列の各要素は「NSURL」クラスのインスタンスとする
- (void)reloadFromContentsOfURLsFromArray:(NSArray *)urlsArray fileName:(NSString *)fileName performer:(id)performer
{
    NSMutableArray *entryArray = [NSMutableArray arrayWithCapacity:0];
    
    for (NSURL *url in urlsArray) {
        @autoreleasepool {

            // URLから読み込む
            NSArray *itemsArray = [self itemsArrayFromContentsOfURL:url fileName:fileName performer:performer];
            
            // 配列に追加する
            [entryArray addObjectsFromArray:itemsArray];
        }
    }
    
    /*
     * ソートする
     */
    // まずNEWエントリとそれ以外のエントリを分ける
    NSMutableArray *newArray = [NSMutableArray array];
    NSMutableArray *oldArray = [NSMutableArray array];
    for (id entry in entryArray) {
        NSLog(@"%@", entry);
        if ([entry isNewEntry]) {
            [newArray addObject:entry];
        }
        else
        {
            [oldArray addObject:entry];
        }
    }
    // まずNEWエントリを、日付をキーにして、降順ソートする
    [newArray sortUsingFunction:dateDescending context:NULL];
    // 次にそれ以外のエントリを、日付をキーにして、降順ソートする
    [oldArray sortUsingFunction:dateDescending context:NULL];
    // newArrayのうしろにoldArrayを付ける
    [newArray addObjectsFromArray:oldArray];
    
    // データメンバーに設定する
    self.itemsArray = newArray;
}

// URLからファイルを読み込み、アイテムの配列を返すメソッド
- (NSArray *)itemsArrayFromContentsOfURL:(NSURL *)url fileName:(NSString *)fileName performer:(id)performer
{
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:0];
    self.parser = [[RSSParser alloc] init];

    // URLから読み込む
    if ([self.parser parseContentsOfURL:url fileName:fileName performer:performer]) {
        
        // 記事を読み込む
        [newArray addObjectsFromArray:[_parser entries]];
    }
    
    return newArray;
}

// 記事のURLを取得する
- (NSURL *)urlAtIndex:(NSInteger)index
{
    NSURL *url = nil;
    
    // 範囲チェック
    if (index < self.itemsArray.count) {
        
        url = [[self.itemsArray objectAtIndex:index] url];
    }
    return url;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }   
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }   
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // データソースからURLを取得する
    NSURL *url;
    url = [self urlAtIndex:indexPath.row];
    
    // WebViewを開く
    [self performSegueWithIdentifier:@"showWebView" sender:url];
}

#pragma warning

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showWebView"]) {
        WebViewController *controller = segue.destinationViewController;
        NSLog(@"sender = %@", sender);
        controller.URLForSegue = (NSURL *)sender;
        controller.hidesBottomBarWhenPushed = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:didGoToWebView];
    }
}

- (IBAction)showSetting:(id)sender {
    [self performSegueWithIdentifier:@"showSetting" sender:self];
}

- (IBAction)refresh:(id)sender {
    [self requestTableData];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == parsingAlertView)
    {
        [weakOperation cancel];
    }
}

- (IBAction)jumpToPaidApp:(id)sender {
    NSInteger numAct = [[NSUserDefaults standardUserDefaults] integerForKey:@"numAct"];
    if (5 < numAct) {
        [[UIApplication sharedApplication] openURL: [NSURL URLWithString:URLPayed]];
    }
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    return YES;
}

- (void)reloadNavBarTitleWithString:(NSString *)title
{
    // タブバーのタイトルを変える
    self.navigationController.title = title;
    
    // ナビゲーションアイテムのタイトルを変える
    self.navigationItem.title = [NSString stringWithFormat:@"「%@」の新着動画", title];
}

- (void)judgeServerAlive
{
    // もしまったく応答がなければあきらめる
    if (_parser.realProgress == 0) {
        UIAlertView *av = [[UIAlertView alloc] init];
        av.title = @"ネットワークに問題があるか、サーバーが混雑しています。場所・時間を変えるなどして再度お試しください。";
        av.message = nil;
        av.delegate = self;
        [av addButtonWithTitle:@"了解"];
        [av show];

        [weakOperation cancel];
    }
    // さもなくば残りの情報を待つ
}

- (void)enableRefreshBotton
{
    // メインスレッドに戻す
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    [mainQueue addOperationWithBlock:^{
        _refreshButton.enabled = YES;
    }];
    NSLog(@"FeedTableController.m: #enableRefreshButton");
}

@end

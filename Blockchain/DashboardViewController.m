//
//  DashboardViewController.m
//  Blockchain
//
//  Created by kevinwu on 8/23/17.
//  Copyright © 2017 Blockchain Luxembourg S.A. All rights reserved.
//



#import "DashboardViewController.h"
#import "UIView+ChangeFrameAttribute.h"
#import "NSNumberFormatter+Currencies.h"
#import "GraphTimeFrame.h"
#import "Blockchain-Swift.h"
#import "BCPriceChartView.h"
#import "BCBalancesChartView.h"
#import "BCPricePreviewView.h"
#import "BCPriceChartContainerViewController.h"

#define DASHBOARD_HORIZONTAL_PADDING 15
#define PRICE_CHART_PADDING 20

@import Charts;

@interface CardsViewController ()
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIView *contentView;
@end

@interface DashboardViewController () <IChartAxisValueFormatter, BCPriceChartViewDelegate, BCBalancesChartViewDelegate>
@property (nonatomic) BCBalancesChartView *balancesChartView;
@property (nonatomic) BCPriceChartContainerViewController *chartContainerViewController;
@property (nonatomic) BCPricePreviewView *bitcoinPricePreview;
@property (nonatomic) BCPricePreviewView *etherPricePreview;
@property (nonatomic) BCPricePreviewView *bitcoinCashPricePreview;
@property (nonatomic) NSDecimalNumber *lastEthExchangeRate;
@end

@implementation DashboardViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetScrollView) name:@"applicationDidEnterBackground" object:nil];
    // This contentView can be any custom view - intended to be placed at the top of the scroll view, moved down when the cards view is present, and moved back up when the cards view is dismissed
    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.clipsToBounds = YES;
    self.contentView.backgroundColor = [UIColor clearColor];
    self.view.backgroundColor = COLOR_BACKGROUND_LIGHT_GRAY;
    [self.scrollView addSubview:self.contentView];
    
    [self setupPieChart];
    
    [self setupPriceCharts];

    CGFloat balancesChartHeight = _balancesChartView.frame.size.height;
    CGFloat titleLabelHeight = 2 * (40 + 16);
    CGFloat pricePreviewHeight = 3 * 140;
    CGFloat privePreviewSpacing = 3 * 16;
    CGFloat bottomPadding = 8;
    CGFloat contentHeight = balancesChartHeight + titleLabelHeight + pricePreviewHeight + privePreviewSpacing + bottomPadding;
    CGRect contentViewFrame = CGRectMake(0, 0, self.view.frame.size.width, contentHeight);
    self.contentView.frame = contentViewFrame;
}

- (void)resetScrollView
{
    [self.scrollView setContentOffset:CGPointZero animated:NO];
}

- (void)setAssetType:(LegacyAssetType)assetType
{
    _assetType = assetType;
    
    [self reload];
}

- (void)setupPieChart
{
    CGFloat horizontalPadding = DASHBOARD_HORIZONTAL_PADDING;

    UILabel *balancesLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizontalPadding, 16, self.view.frame.size.width/2, 40)];
    balancesLabel.textColor = COLOR_BLOCKCHAIN_BLUE;
    balancesLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_LARGE];
    balancesLabel.text = [BC_STRING_BALANCES uppercaseString];
    [self.contentView addSubview:balancesLabel];
    
    self.balancesChartView = [[BCBalancesChartView alloc] initWithFrame:CGRectMake(horizontalPadding, balancesLabel.frame.origin.y + balancesLabel.frame.size.height, self.view.frame.size.width - horizontalPadding*2, 320)];
    self.balancesChartView.delegate = self;
    self.balancesChartView.layer.masksToBounds = NO;
    self.balancesChartView.layer.cornerRadius = 2;
    self.balancesChartView.layer.shadowOffset = CGSizeMake(0, 2);
    self.balancesChartView.layer.shadowRadius = 3;
    self.balancesChartView.layer.shadowOpacity = 0.25;
    [self.contentView addSubview:self.balancesChartView];
}

- (void)setupPriceCharts
{
    CGFloat horizontalPadding = DASHBOARD_HORIZONTAL_PADDING;
    
    UILabel *balancesLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizontalPadding, self.balancesChartView.frame.origin.y + self.balancesChartView.frame.size.height + 16, self.view.frame.size.width/2, 40)];
    balancesLabel.textColor = COLOR_BLOCKCHAIN_BLUE;
    balancesLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_LARGE];
    balancesLabel.text = [BC_STRING_PRICE_CHARTS uppercaseString];
    [self.contentView addSubview:balancesLabel];
    
    BCPricePreviewView *bitcoinPreviewView = [[BCPricePreviewView alloc] initWithFrame:CGRectMake(horizontalPadding, balancesLabel.frame.origin.y + balancesLabel.frame.size.height, self.view.frame.size.width - horizontalPadding*2, 140) assetName:BC_STRING_BITCOIN price:[NSNumberFormatter formatMoney:SATOSHI localCurrency:YES] assetImage:@"bitcoin_white"];
    [self.contentView addSubview:bitcoinPreviewView];
    self.bitcoinPricePreview = bitcoinPreviewView;
    
    UITapGestureRecognizer *bitcoinChartTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bitcoinChartTapped)];
    [bitcoinPreviewView addGestureRecognizer:bitcoinChartTapGesture];
    
    BCPricePreviewView *etherPreviewView = [[BCPricePreviewView alloc] initWithFrame:CGRectMake(horizontalPadding, bitcoinPreviewView.frame.origin.y + bitcoinPreviewView.frame.size.height + 16, self.view.frame.size.width - horizontalPadding*2, 140) assetName:BC_STRING_ETHER price:[self getEthPrice] assetImage:@"ether_white"];
    [self.contentView addSubview:etherPreviewView];
    self.etherPricePreview = etherPreviewView;
    
    UITapGestureRecognizer *etherChartTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(etherChartTapped)];
    [etherPreviewView addGestureRecognizer:etherChartTapGesture];
    
    BCPricePreviewView *bitcoinCashPreviewView = [[BCPricePreviewView alloc] initWithFrame:CGRectMake(horizontalPadding, etherPreviewView.frame.origin.y + etherPreviewView.frame.size.height + 16, self.view.frame.size.width - horizontalPadding*2, 140) assetName:BC_STRING_BITCOIN_CASH price:[self getBchPrice] assetImage:@"bitcoin_cash_white"];
    [self.contentView addSubview:bitcoinCashPreviewView];
    self.bitcoinCashPricePreview = bitcoinCashPreviewView;
    
    UITapGestureRecognizer *bitcoinCashChartTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bitcoinCashChartTapped)];
    [bitcoinCashPreviewView addGestureRecognizer:bitcoinCashChartTapGesture];
}

- (void)reload
{
    double btcBalance = [self getBtcBalance];
    double ethBalance = [self getEthBalance];
    double bchBalance = [self getBchBalance];
    double totalFiatBalance = btcBalance + ethBalance + bchBalance;
    if (WalletManager.sharedInstance.wallet.isInitialized) {
        [self.balancesChartView updateFiatSymbol:WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local.symbol];
        // Fiat balances
        [self.balancesChartView updateBitcoinFiatBalance:btcBalance];
        [self.balancesChartView updateEtherFiatBalance:ethBalance];
        [self.balancesChartView updateBitcoinCashFiatBalance:bchBalance];
        [self.balancesChartView updateTotalFiatBalance:[NSNumberFormatter appendStringToFiatSymbol:[NSNumberFormatter fiatStringFromDouble:totalFiatBalance]]];
        // Balances
        [self.balancesChartView updateBitcoinBalance:[NSNumberFormatter formatAmount:[WalletManager.sharedInstance.wallet getTotalActiveBalance] localCurrency:NO]];
        [self.balancesChartView updateEtherBalance:[WalletManager.sharedInstance.wallet getEthBalanceTruncated]];
        [self.balancesChartView updateBitcoinCashBalance:[NSNumberFormatter formatAmount:[WalletManager.sharedInstance.wallet bitcoinCashTotalBalance] localCurrency:NO]];
    }

    [self.balancesChartView updateChart];
    
    [self reloadPricePreviews];

    [self reloadCards];
}

- (void)fetchChartDataForAsset:(LegacyAssetType)assetType
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_KEY_GRAPH_TIME_FRAME];
    GraphTimeFrame *timeFrame = [NSKeyedUnarchiver unarchiveObjectWithData:data] ? : [GraphTimeFrame timeFrameWeek];
    NSInteger startDate;
    NSInteger entryDate;
    NSString *scale = timeFrame.scale;
        
    NSString *base;
    
    if (assetType == LegacyAssetTypeBitcoin) {
        base = [CURRENCY_SYMBOL_BTC lowercaseString];
        entryDate = [timeFrame startDateBitcoin];
    } else if (assetType == LegacyAssetTypeEther) {
        base = [CURRENCY_SYMBOL_ETH lowercaseString];
        entryDate = [timeFrame startDateEther];
    } else if (assetType == LegacyAssetTypeBitcoinCash) {
        base = [CURRENCY_SYMBOL_BCH lowercaseString];
        entryDate = [timeFrame startDateBitcoinCash];
    }
    
    startDate = timeFrame.timeFrame == TimeFrameAll || timeFrame.startDate < entryDate ? entryDate : timeFrame.startDate;
    
    NSString *quote = [NSNumberFormatter localCurrencyCode];
    
    if (!quote) {
        [self showError:BC_STRING_ERROR_CHARTS];
        return;
    }
    NSURL *URL = [NSURL URLWithString:[[[BlockchainAPI sharedInstance] apiUrl] stringByAppendingString:[NSString stringWithFormat:CHARTS_URL_SUFFIX_ARGUMENTS_BASE_QUOTE_START_SCALE, base, quote, [NSString stringWithFormat:@"%lu", startDate], scale]]];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *task = [[[NetworkManager sharedInstance] session] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            DLog(@"Error getting chart data - %@", [error localizedDescription]);
            [self showError:[error localizedDescription]];
        } else {
            NSError *jsonError;
            NSArray *values = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
            if (jsonError || !values) {
                [self showError:BC_STRING_ERROR_CHARTS];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([values count] == 0) {
                        [self.chartContainerViewController clearChart];
                        [self showError:BC_STRING_ERROR_CHARTS];
                    } else {
                        [self.chartContainerViewController updateChartWithValues:values];
                    }
                });
            }
        }
    }];
    
    [task resume];
}

- (void)updateEthExchangeRate:(NSDecimalNumber *)rate
{
    self.lastEthExchangeRate = rate;
    [self reloadPricePreviews];
}

- (void)showChartContainerViewController
{
    if (!self.chartContainerViewController.view.window) {
        self.chartContainerViewController = [[BCPriceChartContainerViewController alloc] init];
        self.chartContainerViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        self.chartContainerViewController.delegate = self;
        TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
        [tabControllerManager.tabViewController presentViewController:self.chartContainerViewController animated:YES completion:nil];
    }
}

- (void)bitcoinChartTapped
{
    [self showChartContainerViewController];
    
    CGFloat padding = PRICE_CHART_PADDING;
    BCPriceChartView *priceChartView = [[BCPriceChartView alloc] initWithFrame:CGRectMake(padding, padding, self.view.frame.size.width - padding, self.view.frame.size.height*3/4 - padding) assetType:LegacyAssetTypeBitcoin dataPoints:nil delegate:self];
    [self.chartContainerViewController addPriceChartView:priceChartView atIndex:0];
    [self fetchChartDataForAsset:LegacyAssetTypeBitcoin];
}

- (void)etherChartTapped
{
    [self showChartContainerViewController];
    
    CGFloat padding = PRICE_CHART_PADDING;
    BCPriceChartView *priceChartView = [[BCPriceChartView alloc] initWithFrame:CGRectMake(padding, padding, self.view.frame.size.width - padding, self.view.frame.size.height*3/4 - padding) assetType:LegacyAssetTypeEther dataPoints:nil delegate:self];
    [self.chartContainerViewController addPriceChartView:priceChartView atIndex:1];
    [self.chartContainerViewController updateEthExchangeRate:self.lastEthExchangeRate];
    [self fetchChartDataForAsset:LegacyAssetTypeEther];
}

- (void)bitcoinCashChartTapped
{
    [self showChartContainerViewController];

    CGFloat padding = PRICE_CHART_PADDING;
    BCPriceChartView *priceChartView = [[BCPriceChartView alloc] initWithFrame:CGRectMake(padding, padding, self.view.frame.size.width - padding, self.view.frame.size.height*3/4 - padding) assetType:LegacyAssetTypeBitcoinCash dataPoints:nil delegate:self];
    [self.chartContainerViewController addPriceChartView:priceChartView atIndex:2];
    [self fetchChartDataForAsset:LegacyAssetTypeBitcoinCash];
}

#pragma mark - Balances Chart Delegate

- (void)bitcoinLegendTapped
{
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager showTransactionsBitcoin];
}

- (void)etherLegendTapped
{
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager showTransactionsEther];
}

- (void)bitcoinCashLegendTapped
{
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager showTransactionsBitcoinCash];
}

#pragma mark - View Helpers

- (void)showError:(NSString *)error
{
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    PEPinEntryController *pinEntryViewController = AuthenticationCoordinator.sharedInstance.pinEntryViewController;

    if ([BlockchainSettings sharedAppInstance].isPinSet &&
        !pinEntryViewController &&
        [WalletManager.sharedInstance.wallet isInitialized] &&
        tabControllerManager.tabViewController.selectedIndex == TAB_DASHBOARD
        && ![ModalPresenter sharedInstance].modalView) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_ERROR message:error preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view.window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    }
}

#pragma mark - Text Helpers

- (NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis
{
    if (axis == [self.chartContainerViewController leftAxis]) {
        return [NSString stringWithFormat:@"%@%.f", WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local.symbol, value];
    } else if (axis == [self.chartContainerViewController xAxis]) {
        return [self dateStringFromGraphValue:value];
    } else {
        DLog(@"Warning: no axis found!");
        return nil;
    }
}

- (NSString *)dateStringFromGraphValue:(double)value
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = [self getDateFormat];
    return [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
}

- (NSString *)getDateFormat
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_KEY_GRAPH_TIME_FRAME];
    GraphTimeFrame *timeFrame = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return timeFrame.dateFormat;
}

- (NSString *)getBtcPrice
{
    return WalletManager.sharedInstance.wallet.isInitialized ? [NSNumberFormatter formatMoney:SATOSHI localCurrency:YES] : nil;
}

- (NSString *)getBchPrice
{
    return WalletManager.sharedInstance.wallet.isInitialized ? [NSNumberFormatter formatBchWithSymbol:SATOSHI localCurrency:YES] : nil;
}

- (NSString *)getEthPrice
{
    if (!WalletManager.sharedInstance.wallet.isInitialized || !self.lastEthExchangeRate) {
        return nil;
    }
    return [NSNumberFormatter formatEthToFiatWithSymbol:@"1" exchangeRate:self.lastEthExchangeRate];
}

- (double)getBtcBalance
{
    return [self doubleFromString:[NSNumberFormatter formatAmount:[WalletManager.sharedInstance.wallet getTotalActiveBalance] localCurrency:YES]];
}

- (double)getEthBalance
{
    return [self doubleFromString:[NSNumberFormatter formatEthToFiat:[WalletManager.sharedInstance.wallet getEthBalance] exchangeRate:WalletManager.sharedInstance.wallet.latestEthExchangeRate localCurrencyFormatter:[NSNumberFormatter localCurrencyFormatter]]];
}

- (double)getBchBalance
{
    return [self doubleFromString:[NSNumberFormatter formatBch:[WalletManager.sharedInstance.wallet bitcoinCashTotalBalance] localCurrency:YES]];
}

- (double)doubleFromString:(NSString *)string
{
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    return [[numberFormatter numberFromString:string] doubleValue];
}

- (void)reloadPricePreviews
{
    [self.bitcoinPricePreview updatePrice:[self getBtcPrice]];
    [self.etherPricePreview updatePrice:[self getEthPrice]];
    [self.bitcoinCashPricePreview updatePrice:[self getBchPrice]];
}

#pragma mark - BCPriceChartView Delegate

- (void)addPriceChartView:(LegacyAssetType)assetType
{
    switch (assetType) {
        case LegacyAssetTypeBitcoin: [self bitcoinChartTapped]; return;
        case LegacyAssetTypeEther: [self etherChartTapped]; return;
        case LegacyAssetTypeBitcoinCash: [self bitcoinCashChartTapped]; return;
    }
}

- (void)reloadPriceChartView:(LegacyAssetType)assetType
{
    [self fetchChartDataForAsset:assetType];
}

@end

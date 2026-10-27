Map<String, dynamic> holdingFixture({
  String symbol = 'NVDA',
  String type = 'OFFSHORE_STOCK',
  double quantity = 2,
  double nativeCost = 200,
  double historicalCost = 6400,
  double nativeValue = 240,
  double thbValue = 8400,
  double nativePnl = 40,
  double thbPnl = 1400,
}) {
  final usd = type == 'OFFSHORE_STOCK';
  Map<String, dynamic> basis(String currency, double cost) => {
    'currency': currency,
    'status': 'CALCULATED',
    'remainingCost': cost,
    'averageCostPerUnit': quantity == 0 ? null : cost / quantity,
  };
  Map<String, dynamic> money(String currency, double buy, double fees) => {
    'currency': currency,
    'isComplete': true,
    'grossIsComplete': true,
    'feeIsComplete': true,
    'totalBuyGross': buy,
    'totalBuy': buy + fees,
    'totalSell': buy / 4,
    'totalFeeIncludeVat': fees,
  };
  return {
    'assetType': type,
    'accountNumber': 'account-A',
    'symbol': symbol,
    'exchange': usd ? 'XNAS' : null,
    'currency': usd ? 'USD' : 'THB',
    'quantity': quantity,
    'status': quantity > 0 ? 'HELD' : 'CLOSED',
    'transactionCount': 3,
    'amounts': [
      if (usd) money('USD', 230, 2),
      money('THB', usd ? 7360 : historicalCost, 10),
    ],
    'costBasis': [
      if (usd) basis('USD', nativeCost),
      basis('THB', historicalCost),
    ],
    'realizedPnl': [
      {'currency': 'THB', 'status': 'CALCULATED', 'realizedPnl': 100},
    ],
    if (usd)
      'displayThb': {
        'costBasis': {
          'status': 'CALCULATED',
          'remainingCost': nativeCost * 35,
          'averageCostPerUnit': quantity == 0
              ? null
              : nativeCost * 35 / quantity,
        },
      },
    'marketValuation': {
      'quote': {
        'status': 'AVAILABLE',
        'source': usd
            ? 'FINNHUB'
            : type == 'MUTUAL_FUND'
            ? 'SEC_OPEN_API'
            : 'YAHOO_FINANCE',
        'price': quantity > 0 ? nativeValue / quantity : null,
        'changePercent': 2.5,
        'change': 3,
        'priceAt': '2026-10-28T03:00:00Z',
      },
      if (usd)
        'usd': {
          'marketValue': nativeValue,
          'remainingCost': nativeCost,
          'unrealizedPnl': nativePnl,
          'unrealizedPnlPercent': 20,
        },
      'thb': {
        'marketValue': thbValue,
        'unrealizedPnl': thbPnl,
        'unrealizedPnlPercent': 20,
      },
    },
  };
}

Map<String, dynamic> holdingsFixture() {
  Map<String, dynamic> valuation(double value, double profit) => {
    'missingPriceCount': 0,
    'thb': {
      'marketValue': value,
      'unrealizedPnl': profit,
      'unrealizedPnlPercent': 20,
    },
  };
  return {
    'scope': 'STOCKS_AND_MUTUAL_FUNDS',
    'includeClosed': true,
    'excludedTransactions': [],
    'fx': {
      'status': 'AVAILABLE',
      'baseCurrency': 'USD',
      'quoteCurrency': 'THB',
      'rate': 35,
    },
    'remainingCostTotals': [
      {'currency': 'THB', 'remainingCost': 7900, 'isComplete': true},
    ],
    'realizedPnlTotals': [
      {
        'currency': 'THB',
        'realizedPnl': 300,
        'soldCost': 2000,
        'isComplete': true,
      },
    ],
    'offshoreValuation': {
      ...valuation(8400, 1400),
      'usd': {
        'marketValue': 240,
        'unrealizedPnl': 40,
        'unrealizedPnlPercent': 20,
      },
    },
    'thaiStockValuation': valuation(1200, 200),
    'mutualFundValuation': valuation(550, 50),
    'items': [
      holdingFixture(),
      holdingFixture(
        symbol: 'ASK',
        type: 'THAI_STOCK',
        quantity: 10,
        historicalCost: 1000,
        nativeCost: 1000,
        nativeValue: 1200,
        thbValue: 1200,
        nativePnl: 200,
        thbPnl: 200,
      ),
      holdingFixture(
        symbol: 'KKP US500',
        type: 'MUTUAL_FUND',
        quantity: 50,
        historicalCost: 500,
        nativeCost: 500,
        nativeValue: 550,
        thbValue: 550,
        nativePnl: 50,
        thbPnl: 50,
      ),
    ],
    'latestChange': {
      'portfolio': {
        'isComplete': true,
        'status': 'CALCULATED',
        'currency': 'THB',
        'change': 100,
        'changePercent': 1,
      },
    },
  };
}

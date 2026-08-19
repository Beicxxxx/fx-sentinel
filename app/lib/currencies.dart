class CurrencyInfo {
  const CurrencyInfo(this.code, this.nameZh, this.flag);
  final String code;
  final String nameZh;
  /// ISO 3166-1 alpha-2 for flagcdn, or empty if none.
  final String flag;
}

const currencies = <CurrencyInfo>[
  CurrencyInfo('USD', '美元', 'us'),
  CurrencyInfo('CNY', '人民币', 'cn'),
  CurrencyInfo('EUR', '欧元', 'eu'),
  CurrencyInfo('JPY', '日元', 'jp'),
  CurrencyInfo('GBP', '英镑', 'gb'),
  CurrencyInfo('HKD', '港元', 'hk'),
  CurrencyInfo('AUD', '澳元', 'au'),
  CurrencyInfo('NZD', '新西兰元', 'nz'),
  CurrencyInfo('CAD', '加元', 'ca'),
  CurrencyInfo('CHF', '瑞士法郎', 'ch'),
  CurrencyInfo('KRW', '韩元', 'kr'),
  CurrencyInfo('SGD', '新加坡元', 'sg'),
  CurrencyInfo('TWD', '新台币', 'tw'),
  CurrencyInfo('THB', '泰铢', 'th'),
  CurrencyInfo('MYR', '马来西亚林吉特', 'my'),
  CurrencyInfo('IDR', '印尼盾', 'id'),
  CurrencyInfo('PHP', '菲律宾比索', 'ph'),
  CurrencyInfo('VND', '越南盾', 'vn'),
  CurrencyInfo('INR', '印度卢比', 'in'),
  CurrencyInfo('AED', '阿联酋迪拉姆', 'ae'),
  CurrencyInfo('SAR', '沙特里亚尔', 'sa'),
  CurrencyInfo('TRY', '土耳其里拉', 'tr'),
  CurrencyInfo('RUB', '俄罗斯卢布', 'ru'),
  CurrencyInfo('BRL', '巴西雷亚尔', 'br'),
  CurrencyInfo('MXN', '墨西哥比索', 'mx'),
  CurrencyInfo('ZAR', '南非兰特', 'za'),
  CurrencyInfo('SEK', '瑞典克朗', 'se'),
  CurrencyInfo('NOK', '挪威克朗', 'no'),
  CurrencyInfo('DKK', '丹麦克朗', 'dk'),
  CurrencyInfo('PLN', '波兰兹罗提', 'pl'),
  CurrencyInfo('CZK', '捷克克朗', 'cz'),
  CurrencyInfo('HUF', '匈牙利福林', 'hu'),
  CurrencyInfo('ILS', '以色列新谢克尔', 'il'),
  CurrencyInfo('CLP', '智利比索', 'cl'),
  CurrencyInfo('ARS', '阿根廷比索', 'ar'),
  CurrencyInfo('COP', '哥伦比亚比索', 'co'),
  CurrencyInfo('PEN', '秘鲁索尔', 'pe'),
  CurrencyInfo('EGP', '埃及镑', 'eg'),
  CurrencyInfo('NGN', '尼日利亚奈拉', 'ng'),
  CurrencyInfo('PKR', '巴基斯坦卢比', 'pk'),
  CurrencyInfo('BDT', '孟加拉塔卡', 'bd'),
  CurrencyInfo('KZT', '哈萨克斯坦坚戈', 'kz'),
  CurrencyInfo('UAH', '乌克兰格里夫纳', 'ua'),
  CurrencyInfo('RON', '罗马尼亚列伊', 'ro'),
  CurrencyInfo('BGN', '保加利亚列弗', 'bg'),
  CurrencyInfo('QAR', '卡塔尔里亚尔', 'qa'),
  CurrencyInfo('KWD', '科威特第纳尔', 'kw'),
  CurrencyInfo('BHD', '巴林第纳尔', 'bh'),
  CurrencyInfo('OMR', '阿曼里亚尔', 'om'),
  CurrencyInfo('JOD', '约旦第纳尔', 'jo'),
  CurrencyInfo('LKR', '斯里兰卡卢比', 'lk'),
  CurrencyInfo('MMK', '缅甸元', 'mm'),
  CurrencyInfo('KHR', '柬埔寨瑞尔', 'kh'),
  CurrencyInfo('LAK', '老挝基普', 'la'),
  CurrencyInfo('MOP', '澳门元', 'mo'),
  CurrencyInfo('CNH', '离岸人民币', 'cn'),
];

CurrencyInfo? currencyOf(String code) {
  final upper = code.toUpperCase();
  for (final c in currencies) {
    if (c.code == upper) return c;
  }
  return null;
}

String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'CNY':
    case 'CNH':
    case 'JPY':
      return '¥';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'KRW':
      return '₩';
    case 'HKD':
      return 'HK\$';
    case 'AUD':
      return 'A\$';
    case 'CAD':
      return 'C\$';
    case 'SGD':
      return 'S\$';
    case 'TWD':
      return 'NT\$';
    case 'THB':
      return '฿';
    case 'INR':
      return '₹';
    case 'RUB':
      return '₽';
    case 'TRY':
      return '₺';
    case 'CHF':
      return 'Fr';
    default:
      return '';
  }
}

String pairLabel(String base, String quote) {
  final a = currencyOf(base)?.nameZh ?? base;
  final b = currencyOf(quote)?.nameZh ?? quote;
  return '$a / $b';
}

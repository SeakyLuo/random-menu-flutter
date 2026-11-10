enum MenuCurrency {
  cny('CNY', '人民币', '¥'),
  thb('THB', '泰铢', '฿'),
  sgd('SGD', '新加坡元', 'S\$'),
  jpy('JPY', '日元', 'JP¥'),
  hkd('HKD', '港币', 'HK\$'),
  mop('MOP', '澳门元', 'MOP\$'),
  twd('TWD', '新台币', 'NT\$'),
  usd('USD', '美元', 'US\$'),
  eur('EUR', '欧元', '€'),
  gbp('GBP', '英镑', '£'),
  myr('MYR', '马来西亚林吉特', 'RM'),
  krw('KRW', '韩元', '₩'),
  aud('AUD', '澳元', 'A\$'),
  cad('CAD', '加拿大元', 'CA\$'),
  vnd('VND', '越南盾', '₫'),
  idr('IDR', '印尼盾', 'Rp');

  const MenuCurrency(this.code, this.label, this.symbol);
  final String code;
  final String label;
  final String symbol;
  static MenuCurrency fromCode(String code) =>
      values.firstWhere((currency) => currency.code == code);
}

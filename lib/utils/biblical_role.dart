/// Translate dataset role strings (English uppercase canonical
/// values) into the user's UI locale. Pass-through for unknown
/// roles so we never lose information.
String localizedRole(String role, String locale) {
  const map = {
    'PATRIARCH': {'zh-Hans': '族长', 'zh-Hant': '族長'},
    'MATRIARCH': {'zh-Hans': '女族长', 'zh-Hant': '女族長'},
    'FIRST MAN': {'zh-Hans': '人类始祖', 'zh-Hant': '人類始祖'},
    'FIRST WOMAN': {'zh-Hans': '人类始母', 'zh-Hant': '人類始母'},
    'PROPHET': {'zh-Hans': '先知', 'zh-Hant': '先知'},
    'PROPHETESS': {'zh-Hans': '女先知', 'zh-Hant': '女先知'},
    'CONCUBINE': {'zh-Hans': '妾', 'zh-Hant': '妾'},
    'WIFE': {'zh-Hans': '妻', 'zh-Hant': '妻'},
    'TRIBE': {'zh-Hans': '支派', 'zh-Hant': '支派'},
    'PRIESTLY TRIBE': {'zh-Hans': '祭司支派', 'zh-Hant': '祭司支派'},
    'ROYAL TRIBE': {'zh-Hans': '王室支派', 'zh-Hant': '王室支派'},
    'HALF-TRIBE': {'zh-Hans': '半支派', 'zh-Hant': '半支派'},
    'DAUGHTER': {'zh-Hans': '女儿', 'zh-Hant': '女兒'},
    'GENTILE': {'zh-Hans': '外邦人', 'zh-Hant': '外邦人'},
    'KING': {'zh-Hans': '王', 'zh-Hant': '王'},
    'QUEEN': {'zh-Hans': '王后', 'zh-Hant': '王后'},
    'GOVERNOR': {'zh-Hans': '省长', 'zh-Hant': '省長'},
    'HIGH PRIEST': {'zh-Hans': '大祭司', 'zh-Hant': '大祭司'},
    'EDOMITES': {'zh-Hans': '以东人', 'zh-Hant': '以東人'},
    'ARABS': {'zh-Hans': '阿拉伯人', 'zh-Hant': '阿拉伯人'},
    'MOABITES': {'zh-Hans': '摩押人', 'zh-Hant': '摩押人'},
    'AMMONITES': {'zh-Hans': '亚扪人', 'zh-Hant': '亞捫人'},
    'MOTHER OF JESUS': {'zh-Hans': '耶稣的母亲', 'zh-Hant': '耶穌的母親'},
    'MESSIAH': {'zh-Hans': '弥赛亚', 'zh-Hant': '彌賽亞'},
    'CARPENTER': {'zh-Hans': '木匠', 'zh-Hant': '木匠'},
  };
  if (locale == 'en') return role;
  return map[role.toUpperCase()]?[locale] ?? role;
}

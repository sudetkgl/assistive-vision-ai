class TurkishColor {
  final String nameTr;
  final String nameEn;
  final int r, g, b;
  const TurkishColor(this.nameTr, this.nameEn, this.r, this.g, this.b);
}

class TurkishColorDB {
  static const List<TurkishColor> colors = [
    TurkishColor('kırmızı',       'red',          220, 38,  38),
    TurkishColor('bordo',         'burgundy',     128, 0,   32),
    TurkishColor('kiremit',       'brick red',    183, 65,  14),
    TurkishColor('turuncu',       'orange',       249, 115, 22),
    TurkishColor('kehribar',      'amber',        245, 158, 11),
    TurkishColor('sarı',          'yellow',       234, 179, 8),
    TurkishColor('altın sarısı',  'gold',         202, 138, 4),
    TurkishColor('limon sarısı',  'lemon',        236, 252, 103),
    TurkishColor('krem',          'cream',        254, 252, 232),
    TurkishColor('fıstık yeşili', 'lime',         132, 204, 22),
    TurkishColor('yeşil',         'green',        34,  197, 94),
    TurkishColor('koyu yeşil',    'dark green',   20,  83,  45),
    TurkishColor('zeytin yeşili', 'olive',        85,  107, 47),
    TurkishColor('haki',          'khaki',        189, 183, 107),
    TurkishColor('turkuaz',       'turquoise',    6,   182, 212),
    TurkishColor('teal',          'teal',         20,  184, 166),
    TurkishColor('nane yeşili',   'mint',         167, 243, 208),
    TurkishColor('mavi',          'blue',         59,  130, 246),
    TurkishColor('lacivert',      'navy',         26,  35,  126),
    TurkishColor('gök mavisi',    'sky blue',     56,  189, 248),
    TurkishColor('firuze',        'firuze',       0,   172, 193),
    TurkishColor('indigo',        'indigo',       99,  102, 241),
    TurkishColor('mor',           'purple',       168, 85,  247),
    TurkishColor('eflatun',       'violet',       139, 92,  246),
    TurkishColor('lila',          'lilac',        192, 132, 252),
    TurkishColor('pembe',         'pink',         244, 114, 182),
    TurkishColor('fuşya',         'fuchsia',      217, 70,  239),
    TurkishColor('gül pembe',     'rose',         251, 113, 133),
    TurkishColor('mercan',        'coral',        248, 113, 113),
    TurkishColor('somon',         'salmon',       252, 165, 165),
    TurkishColor('kahverengi',    'brown',        120, 53,  15),
    TurkishColor('toprak',        'earth',        161, 100, 55),
    TurkishColor('ten rengi',     'skin',         240, 194, 164),
    TurkishColor('bej',           'beige',        245, 245, 220),
    TurkishColor('beyaz',         'white',        255, 255, 255),
    TurkishColor('açık gri',      'light gray',   209, 213, 219),
    TurkishColor('gri',           'gray',         107, 114, 128),
    TurkishColor('koyu gri',      'dark gray',    55,  65,  81),
    TurkishColor('antrasit',      'anthracite',   41,  50,  65),
    TurkishColor('siyah',         'black',        0,   0,   0),
  ];
}

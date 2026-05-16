const Map<String, Map<String, dynamic>> _categoriesTr = {
  'car':          {'label': 'Araç',            'priority': 1, 'danger': true},
  'bus':          {'label': 'Araç',            'priority': 1, 'danger': true},
  'truck':        {'label': 'Araç',            'priority': 1, 'danger': true},
  'motorcycle':   {'label': 'Araç',            'priority': 1, 'danger': true},
  'bicycle':      {'label': 'Bisiklet',        'priority': 1, 'danger': true},
  'person':       {'label': 'İnsan',           'priority': 2, 'danger': false},
  'chair':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'bench':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'couch':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'potted plant': {'label': 'Engel',           'priority': 3, 'danger': false},
  'bottle':       {'label': 'Küçük nesne',     'priority': 4, 'danger': false},
  'cup':          {'label': 'Küçük nesne',     'priority': 4, 'danger': false},
  'cell phone':   {'label': 'Kişisel eşya',    'priority': 4, 'danger': false},
  'book':         {'label': 'Kişisel eşya',    'priority': 4, 'danger': false},
  'laptop':       {'label': 'Elektronik eşya', 'priority': 4, 'danger': false},
};

const Map<String, Map<String, dynamic>> _categoriesEn = {
  'car':          {'label': 'Vehicle',         'priority': 1, 'danger': true},
  'bus':          {'label': 'Vehicle',         'priority': 1, 'danger': true},
  'truck':        {'label': 'Vehicle',         'priority': 1, 'danger': true},
  'motorcycle':   {'label': 'Vehicle',         'priority': 1, 'danger': true},
  'bicycle':      {'label': 'Bicycle',         'priority': 1, 'danger': true},
  'person':       {'label': 'Person',          'priority': 2, 'danger': false},
  'chair':        {'label': 'Obstacle',        'priority': 3, 'danger': false},
  'bench':        {'label': 'Obstacle',        'priority': 3, 'danger': false},
  'couch':        {'label': 'Obstacle',        'priority': 3, 'danger': false},
  'potted plant': {'label': 'Obstacle',        'priority': 3, 'danger': false},
  'bottle':       {'label': 'Small object',    'priority': 4, 'danger': false},
  'cup':          {'label': 'Small object',    'priority': 4, 'danger': false},
  'cell phone':   {'label': 'Personal item',   'priority': 4, 'danger': false},
  'book':         {'label': 'Personal item',   'priority': 4, 'danger': false},
  'laptop':       {'label': 'Electronic item', 'priority': 4, 'danger': false},
};

class S {
  final String locale;
  const S(this.locale);

  bool get isTr => locale == 'tr';
  String get ttsLocale => isTr ? 'tr-TR' : 'en-US';

  Map<String, Map<String, dynamic>> get assistiveCategories =>
      isTr ? _categoriesTr : _categoriesEn;

  // Home
  String get selectMode => isTr ? 'Mod Seçin' : 'Select Mode';
  String get subtitle => isTr
      ? 'Çevrenizi tanımlamak için bir mod seçin.\nUygulama sesli yönlendirme yapar.'
      : 'Select a mode to identify your surroundings.\nThe app provides audio guidance.';
  String get objectDetection => isTr ? 'Nesne Tespiti' : 'Object Detection';
  String get objectDetectionDesc => isTr
      ? 'Çevredeki araçları, engelleri ve\nnesneleri gerçek zamanlı sesli tanımlar.'
      : 'Identifies vehicles, obstacles and\nobjects around you in real-time.';
  String get textReading => isTr ? 'Metin Okuma' : 'Text Reading';
  String get textReadingDesc => isTr
      ? 'Tabelaları, belgeleri ve yazılı\nmetinleri sesli olarak okur.'
      : 'Reads signs, documents and written\ntexts aloud.';
  String get repeatGuidance =>
      isTr ? 'Yönlendirmeyi Tekrarla' : 'Repeat Guidance';
  String get welcomeSpeech => isTr
      ? 'Hoş geldiniz. Nesne tespiti, metin okuma veya renk tespiti modunu seçin.'
      : 'Welcome. Please select object detection, text reading, or color detection mode.';
  String get openingObjectMode =>
      isTr ? 'Nesne tespiti açılıyor.' : 'Opening object detection.';
  String get openingTextMode =>
      isTr ? 'Metin okuma açılıyor.' : 'Opening text reading.';
  String get openingColorMode =>
      isTr ? 'Renk tespiti açılıyor.' : 'Opening color detection.';
  String get repeatSpeech => isTr
      ? 'Nesne tespiti, metin okuma veya renk tespiti modunu seçin.'
      : 'Select object detection, text reading, or color detection mode.';
  String get startLabel => isTr ? 'Başlat' : 'Start';
  String get repeatGuidanceSemantic =>
      isTr ? 'Sesli yönlendirmeyi tekrar dinle' : 'Replay audio guidance';

  // Color mode
  String get colorDetection => isTr ? 'Renk Tespiti' : 'Color Detection';
  String get colorDetectionDesc => isTr
      ? 'Kameraya tuttuğunuz nesnenin\nrengini gerçek zamanlı sesli tanımlar.'
      : 'Identifies the color of objects\nin front of the camera in real-time.';
  String get colorModeTitle => isTr ? 'RENK TESPİTİ' : 'COLOR DETECTION';
  String get colorStartBtn =>
      isTr ? 'RENK TANIMA — Başlat' : 'COLOR DETECT — Start';
  String get colorPauseBtn => isTr ? 'DURDUR — Dokun' : 'PAUSE — Tap';
  String get colorStartedSpeech =>
      isTr ? 'Renk tanıma başladı.' : 'Color detection started.';
  String get colorPausedSpeech => isTr ? 'Durduruldu.' : 'Paused.';
  String get colorTapHint => isTr
      ? 'Renk tanımayı başlatmak için butona dokun'
      : 'Tap the button to start color detection';

  // Object mode plain-language
  String get liveLabel => isTr ? 'CANLI' : 'LIVE';
  String objectsDetectedPlain(int n) =>
      isTr ? '$n nesne tespit edildi' : '$n object${n != 1 ? 's' : ''} detected';

  // Text mode accessibility
  String get readTextBtnSemantic => isTr
      ? 'Kamerayı metne tutun ve bu butona basın'
      : 'Point camera at text and press this button';

  // Object mode
  String get starting => isTr ? 'Başlatılıyor...' : 'Starting...';
  String get loadingModel => isTr ? 'Model yükleniyor...' : 'Loading model...';
  String get listening => isTr ? 'Dinleniyor...' : 'Listening...';
  String get objectModeTitle => isTr ? 'NESNE TESPİTİ' : 'OBJECT DETECTION';
  String get posLeft => isTr ? 'sol tarafta' : 'on your left';
  String get posAhead => isTr ? 'önünde' : 'ahead';
  String get posRight => isTr ? 'sağ tarafta' : 'on your right';
  String objectsDetected(int n) =>
      isTr ? '$n nesne' : '$n object${n != 1 ? 's' : ''}';

  // Text mode
  String get textModeTitle => isTr ? 'METİN OKUMA' : 'TEXT READING';
  String get tapToScan =>
      isTr ? 'Metin okumak için butona bas' : 'Press button to scan text';
  String get scanning => isTr ? 'Taranıyor...' : 'Scanning...';
  String get noTextFound => isTr ? 'Metin bulunamadı' : 'No text found';
  String get noTextDetected => isTr ? 'Metin algılanamadı' : 'No text detected';
  String get readTextBtn => isTr ? 'METNİ OKU' : 'READ TEXT';
  String textBlocks(int n, int ms) => isTr
      ? '$n metin bloğu · ${ms}ms'
      : '$n text block${n != 1 ? 's' : ''} · ${ms}ms';
  String get metricBlock => isTr ? 'blok' : 'blocks';
  String get metricScan => isTr ? 'tarama' : 'scan';

  // Settings
  String get settingsTitle => isTr ? 'Ayarlar' : 'Settings';
  String get sectionAudio => isTr ? 'Ses Ayarları' : 'Audio';
  String get settingTtsSpeed => isTr ? 'Konuşma Hızı' : 'Speech Speed';
  String get speedSlow => isTr ? 'Yavaş' : 'Slow';
  String get speedNormal => isTr ? 'Normal' : 'Normal';
  String get speedFast => isTr ? 'Hızlı' : 'Fast';
  String get settingVolume => isTr ? 'Ses Seviyesi' : 'Volume';
  String get sectionDetection => isTr ? 'Algılama' : 'Detection';
  String get settingDescFreq => isTr ? 'Betimleme Sıklığı' : 'Description Frequency';
  String get settingVibration => isTr ? 'Titreşim' : 'Vibration';
  String get sectionDisplay => isTr ? 'Görünüm' : 'Display';
  String get settingFontSize => isTr ? 'Yazı Boyutu' : 'Font Size';
  String get fontSmall => isTr ? 'Küçük' : 'Small';
  String get fontMedium => isTr ? 'Orta' : 'Medium';
  String get fontLarge => isTr ? 'Büyük' : 'Large';
  String get settingHighContrast => isTr ? 'Yüksek Kontrast' : 'High Contrast';
  String get sectionLanguage => isTr ? 'Dil' : 'Language';
  String get settingLanguage => isTr ? 'Uygulama Dili' : 'App Language';
}

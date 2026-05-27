class CarrierMapper {
  static const Map<String, String> displayNames = {
    "MNG": "MNG Kargo",
    "SURAT": "Sürat Kargo",
    "ARAS": "Aras Kargo",
    "YURTICI": "Yurtiçi Kargo",
    "PTT": "PTT Kargo",
    "UPS": "UPS Türkiye",
    "DHL": "DHL Express",
    "KOLAYGELSIN": "Kolay Gelsin",
  };

  static String toDisplay(String code) {
    final key = code.toUpperCase();
    return displayNames[key] ?? code;
  }
}

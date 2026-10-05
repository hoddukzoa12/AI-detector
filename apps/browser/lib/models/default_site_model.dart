class DefaultSiteModel {
  final String name;
  final String url;

  const DefaultSiteModel({required this.name, required this.url});

  Map<String, dynamic> toMap() {
    return {"name": name, "url": url};
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

// ignore: constant_identifier_names
const GoogleDefaultSite = DefaultSiteModel(
  name: "Google",
  url: "https://www.google.com/",
);

// ignore: constant_identifier_names
const NaverDefaultSite = DefaultSiteModel(
  name: "Naver",
  url: "https://www.naver.com/",
);

// ignore: constant_identifier_names
const DaumDefaultSite = DefaultSiteModel(
  name: "Daum",
  url: "https://www.daum.net/",
);

// ignore: constant_identifier_names
const YouTubeDefaultSite = DefaultSiteModel(
  name: "YouTube",
  url: "https://www.youtube.com/",
);

// ignore: constant_identifier_names
const DuckDuckGoDefaultSite = DefaultSiteModel(
  name: "DuckDuckGo",
  url: "https://duckduckgo.com/",
);

// ignore: constant_identifier_names
const DefaultSites = <DefaultSiteModel>[
  GoogleDefaultSite,
  NaverDefaultSite,
  DaumDefaultSite,
  YouTubeDefaultSite,
  DuckDuckGoDefaultSite,
];

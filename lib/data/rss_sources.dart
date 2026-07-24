class RssSource {
  const RssSource({
    required this.name,
    required this.feedUrl,
    required this.topic,
    this.featured = false,
  });

  final String name;
  final String feedUrl;
  final String topic;
  final bool featured;
}

const newsCategories = <String>[
  'Top Stories',
  'World',
  'Politics',
  'Business',
  'Technology',
  'Science',
  'Health',
  'Sports',
  'Policy',
];

/// The full catalog is deliberately broader than the set contacted per load.
/// Each refresh uses at most 12 feeds with bounded concurrency; the catalog can
/// still support category-specific coverage without issuing a request storm.
const rssSources = <RssSource>[
  RssSource(
    name: 'CBS News',
    feedUrl: 'https://www.cbsnews.com/latest/rss/main',
    topic: 'Top Stories',
    featured: true,
  ),
  RssSource(
    name: 'Los Angeles Times',
    feedUrl: 'https://www.latimes.com/local/rss2.0.xml',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Mercury News',
    feedUrl: 'https://www.mercurynews.com/feed',
    topic: 'Technology',
  ),
  RssSource(
    name: 'MinnPost',
    feedUrl: 'https://www.minnpost.com/feed',
    topic: 'Policy',
    featured: true,
  ),
  RssSource(name: 'WTOP', feedUrl: 'https://wtop.com/feed', topic: 'Politics'),
  RssSource(
    name: 'New York Daily News',
    feedUrl: 'https://www.nydailynews.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Newsweek',
    feedUrl: 'https://www.newsweek.com/rss',
    topic: 'Politics',
  ),
  RssSource(
    name: 'Yahoo News',
    feedUrl: 'https://www.yahoo.com/news/rss',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Boston.com',
    feedUrl: 'https://www.boston.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'WGN-TV',
    feedUrl: 'https://wgntv.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'KTLA',
    feedUrl: 'https://ktla.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'ABC7 San Francisco',
    feedUrl: 'https://abc7news.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'ABC13 Houston',
    feedUrl: 'https://abc13.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'KXAN',
    feedUrl: 'https://www.kxan.com/feed',
    topic: 'Politics',
  ),
  RssSource(
    name: 'FOX31 Denver',
    feedUrl: 'https://kdvr.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'WFLA',
    feedUrl: 'https://www.wfla.com/feed',
    topic: 'Politics',
  ),
  RssSource(
    name: 'KRON4',
    feedUrl: 'https://www.kron4.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'WSVN Miami',
    feedUrl: 'https://wsvn.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'WIVB Buffalo',
    feedUrl: 'https://www.wivb.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: '7News Boston',
    feedUrl: 'https://whdh.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'NEWS10 ABC',
    feedUrl: 'https://www.news10.com/feed',
    topic: 'Politics',
  ),
  RssSource(
    name: 'Observer',
    feedUrl: 'https://observer.com/feed',
    topic: 'Business',
  ),
  RssSource(
    name: 'Pioneer Press',
    feedUrl: 'https://www.twincities.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'PhillyVoice',
    feedUrl: 'https://www.phillyvoice.com/feed',
    topic: 'Health',
    featured: true,
  ),
  RssSource(
    name: 'Times of San Diego',
    feedUrl: 'https://timesofsandiego.com/feed',
    topic: 'Politics',
  ),
  RssSource(
    name: 'Miami Today',
    feedUrl: 'https://miamitodaynews.com/feed',
    topic: 'Business',
  ),
  RssSource(
    name: 'Denver Westword',
    feedUrl: 'https://www.westword.com/denver/Rss.xml',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Detroit Metro Times',
    feedUrl: 'https://www.metrotimes.com/detroit/Rss.xml',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Forest Hills Times',
    feedUrl: 'https://foresthillstimes.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'New York Post',
    feedUrl: 'https://nypost.com/feed',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Breitbart',
    feedUrl: 'https://feeds.feedburner.com/breitbart',
    topic: 'Politics',
  ),
  RssSource(
    name: 'New York Times',
    feedUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml',
    topic: 'Top Stories',
    featured: true,
  ),
  RssSource(
    name: 'Washington Post World',
    feedUrl: 'https://feeds.washingtonpost.com/rss/world',
    topic: 'World',
    featured: true,
  ),
  RssSource(
    name: 'BBC World',
    feedUrl: 'https://feeds.bbci.co.uk/news/world/rss.xml',
    topic: 'World',
    featured: true,
  ),
  RssSource(
    name: 'Guardian World',
    feedUrl: 'https://www.theguardian.com/world/rss',
    topic: 'World',
    featured: true,
  ),
  RssSource(
    name: 'CNN World',
    feedUrl: 'https://rss.cnn.com/rss/edition_world.rss',
    topic: 'World',
  ),
  RssSource(
    name: 'CNBC Top News',
    feedUrl: 'https://www.cnbc.com/id/100003114/device/rss/rss.html',
    topic: 'Business',
    featured: true,
  ),
  RssSource(
    name: 'Investing.com',
    feedUrl: 'https://www.investing.com/rss/news.rss',
    topic: 'Business',
  ),
  RssSource(
    name: 'Forbes Business',
    feedUrl: 'https://www.forbes.com/business/feed/',
    topic: 'Business',
  ),
  RssSource(
    name: 'Fortune',
    feedUrl: 'https://fortune.com/feed',
    topic: 'Business',
  ),
  RssSource(
    name: 'Yahoo Finance',
    feedUrl: 'https://finance.yahoo.com/news/rssindex',
    topic: 'Business',
  ),
  RssSource(
    name: 'Scientific American',
    feedUrl: 'https://rss.sciam.com/ScientificAmerican-Global',
    topic: 'Science',
    featured: true,
  ),
  RssSource(
    name: 'ScienceDaily',
    feedUrl: 'https://www.sciencedaily.com/rss/all.xml',
    topic: 'Science',
  ),
  RssSource(
    name: 'Nature',
    feedUrl: 'https://www.nature.com/nature.rss',
    topic: 'Science',
    featured: true,
  ),
  RssSource(
    name: 'Phys.org',
    feedUrl: 'https://phys.org/rss-feed/',
    topic: 'Science',
  ),
  RssSource(
    name: 'Wired Science',
    feedUrl: 'https://www.wired.com/feed/category/science/latest/rss',
    topic: 'Science',
  ),
  RssSource(
    name: 'NASA Breaking News',
    feedUrl: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
    topic: 'Science',
  ),
  RssSource(
    name: 'Space.com',
    feedUrl: 'https://www.space.com/feeds/all',
    topic: 'Science',
  ),
  RssSource(
    name: 'Ars Technica',
    feedUrl: 'https://feeds.arstechnica.com/arstechnica/index',
    topic: 'Technology',
    featured: true,
  ),
  RssSource(
    name: 'CNET News',
    feedUrl: 'https://www.cnet.com/rss/news/',
    topic: 'Technology',
  ),
  RssSource(
    name: 'Gizmodo',
    feedUrl: 'https://gizmodo.com/rss',
    topic: 'Technology',
  ),
  RssSource(
    name: 'The Verge',
    feedUrl: 'https://www.theverge.com/rss/index.xml',
    topic: 'Technology',
    featured: true,
  ),
  RssSource(
    name: 'TechCrunch',
    feedUrl: 'https://feeds.feedburner.com/TechCrunch',
    topic: 'Technology',
  ),
  RssSource(
    name: 'Engadget',
    feedUrl: 'https://www.engadget.com/rss.xml',
    topic: 'Technology',
  ),
  RssSource(
    name: 'BBC Sport',
    feedUrl: 'https://feeds.bbci.co.uk/sport/rss.xml',
    topic: 'Sports',
    featured: true,
  ),
  RssSource(
    name: 'Sky Sports',
    feedUrl: 'https://feeds.skynews.com/feeds/rss/sports.xml',
    topic: 'Sports',
  ),
  RssSource(
    name: 'Yahoo Sports',
    feedUrl: 'https://sports.yahoo.com/rss/',
    topic: 'Sports',
  ),
  RssSource(
    name: 'ESPN',
    feedUrl: 'https://www.espn.com/espn/rss/news',
    topic: 'Sports',
  ),
  RssSource(
    name: 'CBC Top Stories',
    feedUrl: 'https://www.cbc.ca/cmlink/rss-topstories',
    topic: 'Top Stories',
    featured: true,
  ),
  RssSource(
    name: 'CTV Top Stories',
    feedUrl:
        'https://www.ctvnews.ca/rss/ctvnews-ca-top-stories-public-rss-1.822009',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Toronto Star',
    feedUrl:
        'https://www.thestar.com/content/thestar/feed.RSSManagerServlet.articles.topstories.rss',
    topic: 'Top Stories',
  ),
  RssSource(
    name: 'Deutsche Welle',
    feedUrl: 'https://rss.dw.com/rdf/rss-en-all',
    topic: 'World',
    featured: true,
  ),
  RssSource(
    name: 'France 24',
    feedUrl: 'https://www.france24.com/en/rss',
    topic: 'World',
    featured: true,
  ),
  RssSource(
    name: 'Le Monde',
    feedUrl: 'https://www.lemonde.fr/rss/une.xml',
    topic: 'World',
  ),
  RssSource(
    name: 'Japan Times',
    feedUrl: 'https://www.japantimes.co.jp/feed/topstories/',
    topic: 'World',
  ),
  RssSource(
    name: 'Kyodo News',
    feedUrl: 'https://english.kyodonews.net/rss/all.xml',
    topic: 'World',
  ),
  RssSource(
    name: 'Mexico News Daily',
    feedUrl: 'https://mexiconewsdaily.com/feed/',
    topic: 'World',
  ),
  RssSource(
    name: 'Premium Times Nigeria',
    feedUrl: 'https://www.premiumtimesng.com/feed',
    topic: 'World',
  ),
  RssSource(
    name: 'Inquirer Philippines',
    feedUrl: 'https://www.inquirer.net/fullfeed',
    topic: 'World',
  ),
  RssSource(
    name: 'Express Tribune',
    feedUrl: 'https://tribune.com.pk/feed/home',
    topic: 'World',
  ),
  RssSource(
    name: 'Ukrainska Pravda',
    feedUrl: 'https://www.pravda.com.ua/rss/',
    topic: 'World',
  ),
  RssSource(
    name: 'Moscow Times',
    feedUrl: 'https://www.themoscowtimes.com/rss/news',
    topic: 'World',
  ),
  RssSource(
    name: 'News24 South Africa',
    feedUrl: 'https://feeds.news24.com/articles/news24/TopStories/rss',
    topic: 'World',
  ),
  RssSource(
    name: 'Axios',
    feedUrl: 'https://api.axios.com/feed/',
    topic: 'Politics',
    featured: true,
  ),
];

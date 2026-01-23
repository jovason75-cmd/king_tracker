import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const KingTrackerApp());
}

/* ---------------- ENUM ---------------- */

enum SortMode {
  yearPublished,
  alphabetic,
}

/* ---------------- APP ---------------- */

class KingTrackerApp extends StatelessWidget {
  const KingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'King Tracker',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

/* ---------------- MODEL ---------------- */

class Connection {
  final String type;
  final List<String> withIds;

  Connection({
    required this.type,
    required this.withIds,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      type: json['type'],
      withIds: List<String>.from(json['with']),
    );
  }
}

class Book {
  final String id;
  final String title;
  final int yearPublished;
  final String type;
  final bool darkTowerExtended;
  final List<Connection> connections;
  final List<String>? stories;
  final String? coAuthor;
  final String? synopsis;

  bool owned;
  bool read;
  bool wished = false;
  double rating;
  String notes;
  Set<int> storiesRead = {};
  bool synopsisFetched = false;

  Book({
    required this.id,
    required this.title,
    required this.yearPublished,
    required this.type,
    required this.darkTowerExtended,
    required this.connections,
    this.stories,
    this.coAuthor,
    this.synopsis,
    this.owned = false,
    this.read = false,
    this.wished = false,
    this.rating = 0,
    this.notes = '',
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      yearPublished: json['yearPublished'],
      type: json['type'],
      darkTowerExtended: json['darkTowerExtended'] ?? false,
      connections: (json['connections'] as List<dynamic>? ?? [])
          .map((e) => Connection.fromJson(e))
          .toList(),
      stories: json['stories'] != null
          ? List<String>.from(json['stories'])
          : null,
      coAuthor: json['coAuthor'],
      synopsis: json['synopsis'],
    );
  }
}

class Adaptation {
  final String id;
  final String title;
  final int year;
  final String type;
  final String? basedOn;

  bool owned;
  bool watched;
  bool wished;
  double rating;
  String notes;

  Adaptation({
    required this.id,
    required this.title,
    required this.year,
    required this.type,
    this.basedOn,
    this.owned = false,
    this.watched = false,
    this.wished = false,
    this.rating = 0,
    this.notes = '',
  });

  factory Adaptation.fromJson(Map<String, dynamic> json) {
    return Adaptation(
      id: json['id'],
      title: json['title'],
      year: json['year'],
      type: json['type'],
      basedOn: json['basedOn'],
    );
  }
}

IconData iconForConnectionType(String type) {
  switch (type.toLowerCase()) {
    case 'trilogy':
      return Icons.menu_book;
    case 'duology':
      return Icons.book;
    case 'novella':
      return Icons.note;
    case 'short story collection':
      return Icons.collections;
    case 'non fiction':
    case 'non-fiction':
    case 'nonfiction':
      return Icons.info;
    case 'shared':
    case 'connected':
    case 'shared_universe':
      return Icons.public;
    case 'dark tower':
      return Icons.castle;
    default:
      return Icons.link;
  }
}

IconData iconForBookType(String type) {
  switch (type.toLowerCase()) {
    case 'novel':
      return Icons.auto_stories;
    case 'short story collection':
    case 'collection':
      return Icons.collections;
    case 'novella':
      return Icons.note;
    case 'non-fiction':
    case 'non fiction':
    case 'nonfiction':
      return Icons.info;
    case 'dark tower':
      return Icons.castle;
    case 'bachman':
      return Icons.auto_stories;
    default:
      return Icons.book;
  }
}

Color colorForBookType(String type) {
  switch (type.toLowerCase()) {
    case 'bachman':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}

String formatBookType(String type, {String? coAuthor}) {
  if (type.toLowerCase() == 'bachman') {
    return 'Writing as Richard Bachman';
  }
  if (coAuthor != null) {
    return 'Writing with $coAuthor';
  }
  return type;
}

String? darkTowerOrder(String id) {
  const orders = {
    'the_gunslinger': 'TDT 1',
    'the_drawing_of_the_three': 'TDT 2',
    'the_waste_lands': 'TDT 3',
    'wizard_and_glass': 'TDT 4',
    'the_wind_through_the_keyhole': 'TDT 4.5',
    'wolves_of_the_calla': 'TDT 5',
    'song_of_susannah': 'TDT 6',
    'the_dark_tower': 'TDT 7',
  };
  return orders[id];
}

String normalizeTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]"), '');
}

Widget buildDarkTowerBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.deepPurple.shade700,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber, width: 1),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Widget buildConnectionIcon(Connection conn) {
  if (conn.type.toLowerCase() == 'dark tower') {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.castle,
          size: 18,
          color: Colors.amber,
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: const Icon(
              Icons.star,
              size: 8,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }
  
  return Icon(
    iconForConnectionType(conn.type),
    size: 18,
    color: Colors.amber,
  );
}

Future<String?> fetchSynopsisFromOpenLibrary(String title, int year) async {
  try {
    // Try exact title search first
    final query = '${title.replaceAll(' ', '+')}';
    final url = Uri.parse('https://openlibrary.org/search.json?title=$query&author=stephen+king&limit=10');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['docs'] != null && (data['docs'] as List).isNotEmpty) {
        for (final doc in data['docs']) {
          final publishYear = doc['first_publish_year'];
          if (publishYear != null && ((publishYear as int) - year).abs() <= 2) {
            final key = doc['key'];
            final workUrl = Uri.parse('https://openlibrary.org$key.json');
            final workResponse = await http.get(workUrl).timeout(const Duration(seconds: 10));
            
            if (workResponse.statusCode == 200) {
              final workData = json.decode(workResponse.body);
              final description = workData['description'];
              
              if (description != null) {
                if (description is Map) {
                  return description['value']?.toString() ?? description.toString();
                } else if (description is String && description.isNotEmpty) {
                  return description;
                }
              }
            }
          }
        }
      }
    }
    return null;
  } catch (e) {
    return null;
  }
}

/* ---------------- HOME SCREEN ---------------- */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SortMode sortMode = SortMode.yearPublished;
  List<Book> books = [];
  List<Adaptation> adaptations = [];
  bool loading = true;
  late SharedPreferences prefs;
  String librarySearchQuery = '';
  String adaptationSearchQuery = '';
  String tdtexSearchQuery = '';
  
  // Filter state
  Set<String> selectedTypes = {};
  bool? filterRead;
  bool? filterOwned;
  
  // Adaptation filter state
  Set<String> selectedAdaptationTypes = {};
  bool? filterWatched;
  bool? filterAdaptationOwned;
  SortMode adaptationSortMode = SortMode.yearPublished;
  
  // Search state
  bool showSearch = false;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    await _loadBooks();
    await _loadAdaptations();
  }

  Future<void> _loadBooks() async {
    final jsonString =
        await rootBundle.loadString('lib/assets/data/stephen_king_books.json');
    final List data = json.decode(jsonString);

    final loadedBooks = data.map((e) => Book.fromJson(e)).toList();

    for (final book in loadedBooks) {
      book.owned = prefs.getBool('${book.id}_owned') ?? false;
      book.read = prefs.getBool('${book.id}_read') ?? false;
      book.wished = prefs.getBool('${book.id}_wished') ?? false;
      book.rating = prefs.getDouble('${book.id}_rating') ?? 0;
      book.notes = prefs.getString('${book.id}_notes') ?? '';
      final storiesReadList = prefs.getStringList('${book.id}_stories_read') ?? [];
      book.storiesRead = storiesReadList.map((e) => int.parse(e)).toSet();
    }

    setState(() {
      books = loadedBooks;
      loading = false;
    });
  }

  Future<void> _loadAdaptations() async {
    final jsonString = await rootBundle.loadString(
        'lib/assets/data/stephen_king_adaptations.json');
    final List data = json.decode(jsonString);

    final loadedAdaptations = data.map((e) => Adaptation.fromJson(e)).toList();

    for (final adaptation in loadedAdaptations) {
      adaptation.owned = prefs.getBool('${adaptation.id}_owned') ?? false;
      adaptation.watched = prefs.getBool('${adaptation.id}_watched') ?? false;
      adaptation.wished = prefs.getBool('${adaptation.id}_wished') ?? false;
      adaptation.rating = prefs.getDouble('${adaptation.id}_rating') ?? 0;
      adaptation.notes = prefs.getString('${adaptation.id}_notes') ?? '';
    }

    setState(() {
      adaptations = loadedAdaptations;
    });
  }

  void _saveBook(Book book) {
    prefs.setBool('${book.id}_owned', book.owned);
    prefs.setBool('${book.id}_read', book.read);
    prefs.setBool('${book.id}_wished', book.wished);
    prefs.setDouble('${book.id}_rating', book.rating);
    prefs.setString('${book.id}_notes', book.notes);
    prefs.setStringList('${book.id}_stories_read', 
        book.storiesRead.map((e) => e.toString()).toList());
  }

  void _saveAdaptation(Adaptation adaptation) {
    prefs.setBool('${adaptation.id}_owned', adaptation.owned);
    prefs.setBool('${adaptation.id}_watched', adaptation.watched);
    prefs.setBool('${adaptation.id}_wished', adaptation.wished);
    prefs.setDouble('${adaptation.id}_rating', adaptation.rating);
    prefs.setString('${adaptation.id}_notes', adaptation.notes);
  }

  List<Book> get sortedBooks {
    final list = List<Book>.from(books);

    switch (sortMode) {
      case SortMode.yearPublished:
        list.sort((a, b) => a.yearPublished.compareTo(b.yearPublished));
        break;
      case SortMode.alphabetic:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    const tdtexOrderRaw = [
      'The Stand',
      'The Eyes of the Dragon',
      'The Dark Tower: The Gunslinger',
      'The Little Sisters of Eluria',
      'The Dark Tower: The Drawing of the Three',
      'The Dark Tower: The Waste Lands',
      'The Dark Tower: Wizard and Glass',
      'Salem’s Lot',
      'Hearts in Atlantis',
      'Insomnia',
      "Everything’s Eventual",
      'The Dark Tower: The Wind Through the Keyhole',
      'The Dark Tower: Wolves of the Calla',
      'The Dark Tower: Song of Susannah',
      'Black House',
      'The Dark Tower: The Dark Tower',
    ];

    final tdtexOrderNorm = tdtexOrderRaw
        .map(normalizeTitle)
        .toList();

    final orderIndex = <String, int>{};
    for (var i = 0; i < tdtexOrderNorm.length; i++) {
      orderIndex[tdtexOrderNorm[i]] = i;
    }

    final tdtexBooks = books
        .where((b) => orderIndex.containsKey(normalizeTitle(b.title)))
        .toList()
      ..sort((a, b) => orderIndex[normalizeTitle(a.title)]!
          .compareTo(orderIndex[normalizeTitle(b.title)]!));

    return DefaultTabController(
      length: 5,
      child: Builder(
        builder: (BuildContext context) {
          final TabController tabController = DefaultTabController.of(context);
          return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('King Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Books'),
              Tab(text: 'Film & TV'),
              Tab(text: 'Wish List'),
              Tab(text: 'TDT'),
              Tab(text: 'Statistics'),
            ],
          ),
        ),
        drawer: Drawer(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/app_background_4.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'King Tracker',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${books.length} books • ${adaptations.length} adaptations',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          books: books,
                          adaptations: adaptations,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Iconology Explained'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const IconologyScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('More on King'),
                  onTap: () {
                    Navigator.pop(context);
                    html.window.open('https://stephenking.com/', '_blank');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Export Wish List to PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportWishlistToPdf();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Export Statistics to PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportStatisticsToPdf();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Close'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/App_background_2.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: TabBarView(
            children: [
              /* ---------------- BOOKS TAB ---------------- */
              Column(
                children: [
                  if (showSearch)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
                      child: Column(
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: 'Search books...',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              fillColor: Colors.grey.shade900.withValues(alpha: 0.7),
                              filled: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                librarySearchQuery = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            color: Colors.grey.shade900.withValues(alpha: 0.7),
                            child: DropdownButtonFormField<SortMode>(
                              value: sortMode,
                              decoration: const InputDecoration(
                                labelText: 'Sort order',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: SortMode.yearPublished,
                                  child: Text('Year Published'),
                                ),
                                DropdownMenuItem(
                                  value: SortMode.alphabetic,
                                  child: Text('Alphabetic'),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  sortMode = v!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  color: Colors.grey.shade900.withValues(alpha: 0.7),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedTypes.isEmpty ? null : selectedTypes.first,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: null, child: Text('All')),
                                      DropdownMenuItem(value: 'Novel', child: Text('Novels')),
                                      DropdownMenuItem(value: 'Short Story Collection', child: Text('Short Stories')),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        selectedTypes.clear();
                                        if (v != null) selectedTypes.add(v);
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  color: Colors.grey.shade900.withValues(alpha: 0.7),
                                  child: DropdownButtonFormField<bool?>(
                                    value: filterRead,
                                    decoration: const InputDecoration(
                                      labelText: 'Read',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: null, child: Text('All')),
                                      DropdownMenuItem(value: true, child: Text('Read')),
                                      DropdownMenuItem(value: false, child: Text('Unread')),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        filterRead = v;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  color: Colors.grey.shade900.withValues(alpha: 0.7),
                                  child: DropdownButtonFormField<bool?>(
                                    value: filterOwned,
                                    decoration: const InputDecoration(
                                      labelText: 'Owned',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: null, child: Text('All')),
                                      DropdownMenuItem(value: true, child: Text('Owned')),
                                      DropdownMenuItem(value: false, child: Text('Not Owned')),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        filterOwned = v;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                  child: Builder(
                    builder: (context) {
                      var filtered = sortedBooks;
                      
                      if (selectedTypes.isNotEmpty) {
                        filtered = filtered.where((b) => selectedTypes.contains(b.type)).toList();
                      }
                      if (filterRead != null) {
                        filtered = filtered.where((b) => b.read == filterRead).toList();
                      }
                      if (filterOwned != null) {
                        filtered = filtered.where((b) => b.owned == filterOwned).toList();
                      }
                      if (librarySearchQuery.isNotEmpty) {
                        filtered = filtered.where((b) => 
                          b.title.toLowerCase().contains(librarySearchQuery.toLowerCase())
                        ).toList();
                      }
                      
                      return ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: filtered.map((book) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(
                                    book: book,
                                    allBooks: books,
                                    onChanged: _saveBook,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Tooltip(
                                    message: book.type,
                                    child: Icon(
                                      iconForBookType(book.type),
                                      color: colorForBookType(book.type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (darkTowerOrder(book.id) != null) ...[
                                    buildDarkTowerBadge(darkTowerOrder(book.id)!),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${book.yearPublished} • ${formatBookType(book.type, coAuthor: book.coAuthor)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (book.rating > 0) ...[
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    Text(' ${book.rating.toStringAsFixed(1)}'),
                                    const SizedBox(width: 8),
                                  ],
                                  if (book.connections.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        ...book.connections.map((conn) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 4.0),
                                            child: Tooltip(
                                              message: conn.type,
                                              child: buildConnectionIcon(conn),
                                            ),
                                          );
                                        }).toList(),
                                        const SizedBox(width: 4),
                                        Text(
                                          book.connections
                                              .fold<int>(0, (sum, c) => sum + c.withIds.length)
                                              .toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: Icon(
                                      book.wished ? Icons.favorite : Icons.favorite_border,
                                      color: book.wished ? Colors.red : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        book.wished = !book.wished;
                                      });
                                      _saveBook(book);
                                    },
                                  ),
                                  Checkbox(
                                    value: book.owned,
                                    onChanged: (v) {
                                      setState(() {
                                        book.owned = v ?? false;
                                      });
                                      _saveBook(book);
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Checkbox(
                                    value: book.read,
                                    onChanged: (v) {
                                      setState(() {
                                        book.read = v ?? false;
                                      });
                                      _saveBook(book);
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
            }).toList(),
          );
        },
      ),
    ),
  ],
),

    /* ---------------- FILM & TV TAB ---------------- */
    Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search adaptations...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    fillColor: Colors.grey.shade900.withValues(alpha: 0.7),
                    filled: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      adaptationSearchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.grey.shade900.withValues(alpha: 0.7),
                  child: DropdownButtonFormField<SortMode>(
                    value: adaptationSortMode,
                    decoration: const InputDecoration(
                      labelText: 'Sort order',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SortMode.yearPublished,
                        child: Text('Released'),
                      ),
                      DropdownMenuItem(
                        value: SortMode.alphabetic,
                        child: Text('Alphabetic'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        adaptationSortMode = v!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade900.withValues(alpha: 0.7),
                        child: DropdownButtonFormField<String>(
                          value: selectedAdaptationTypes.isEmpty ? null : selectedAdaptationTypes.first,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(value: 'Movie', child: Text('Movies')),
                            DropdownMenuItem(value: 'TV Series', child: Text('TV Series')),
                            DropdownMenuItem(value: 'Miniseries', child: Text('Miniseries')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              selectedAdaptationTypes.clear();
                              if (v != null) selectedAdaptationTypes.add(v);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade900.withValues(alpha: 0.7),
                        child: DropdownButtonFormField<bool?>(
                          value: filterWatched,
                          decoration: const InputDecoration(
                            labelText: 'Watched',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(value: true, child: Text('Watched')),
                            DropdownMenuItem(value: false, child: Text('Unwatched')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              filterWatched = v;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade900.withValues(alpha: 0.7),
                        child: DropdownButtonFormField<bool?>(
                          value: filterAdaptationOwned,
                          decoration: const InputDecoration(
                            labelText: 'Owned',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(value: true, child: Text('Owned')),
                            DropdownMenuItem(value: false, child: Text('Not Owned')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              filterAdaptationOwned = v;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
                  child: Builder(
                    builder: (context) {
                      var filtered = List<Adaptation>.from(adaptations);
                      
                      // Apply sorting
                      switch (adaptationSortMode) {
                        case SortMode.yearPublished:
                          filtered.sort((a, b) => a.year.compareTo(b.year));
                          break;
                        case SortMode.alphabetic:
                          filtered.sort((a, b) => a.title.compareTo(b.title));
                          break;
                      }
                      
                      // Apply filters
                      if (selectedAdaptationTypes.isNotEmpty) {
                        filtered = filtered.where((a) => selectedAdaptationTypes.contains(a.type)).toList();
                      }
                      if (filterWatched != null) {
                        filtered = filtered.where((a) => a.watched == filterWatched).toList();
                      }
                      if (filterAdaptationOwned != null) {
                        filtered = filtered.where((a) => a.owned == filterAdaptationOwned).toList();
                      }
                      if (adaptationSearchQuery.isNotEmpty) {
                        filtered = filtered.where((a) =>
                            a.title.toLowerCase().contains(adaptationSearchQuery) ||
                            (a.basedOn != null &&
                                books.any((b) =>
                                    b.id == a.basedOn &&
                                    b.title.toLowerCase().contains(adaptationSearchQuery)))
                        ).toList();
                      }

                      return ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: filtered.map((adaptation) {
                          final basedOnBook = adaptation.basedOn != null
                              ? books.firstWhere((b) => b.id == adaptation.basedOn,
                                  orElse: () => books.first)
                              : null;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdaptationDetailScreen(
                                        adaptation: adaptation,
                                        books: books,
                                        onChanged: _saveAdaptation,
                                      ),
                                    ),
                                  );
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        adaptation.type.contains('Movie') || adaptation.type == 'Movie'
                                            ? Icons.movie
                                            : Icons.tv,
                                        color: Colors.blue,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${adaptation.title} (${adaptation.year})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              adaptation.type,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            if (basedOnBook != null)
                                              Text(
                                                'Based on: ${basedOnBook.title}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (adaptation.rating > 0) ...[
                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                        Text(' ${adaptation.rating.toStringAsFixed(1)}'),
                                        const SizedBox(width: 8),
                                      ],
                                      IconButton(
                                        icon: Icon(
                                          adaptation.wished ? Icons.favorite : Icons.favorite_border,
                                          color: adaptation.wished ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            adaptation.wished = !adaptation.wished;
                                          });
                                          _saveAdaptation(adaptation);
                                        },
                                      ),
                                      Checkbox(
                                        value: adaptation.owned,
                                        onChanged: (v) {
                                          setState(() {
                                            adaptation.owned = v ?? false;
                                          });
                                          _saveAdaptation(adaptation);
                                        },
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Checkbox(
                                        value: adaptation.watched,
                                        onChanged: (v) {
                                          setState(() {
                                            adaptation.watched = v ?? false;
                                          });
                                          _saveAdaptation(adaptation);
                                        },
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),

            /* ---------------- WISH LIST TAB ---------------- */
            Column(
              children: [
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search wish list...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        fillColor: Colors.grey.shade900.withValues(alpha: 0.7),
                        filled: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          librarySearchQuery = value;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final wishlist = books.where((b) => b.wished).toList();
                      final filtered = wishlist
                          .where((b) => b.title.toLowerCase().contains(librarySearchQuery))
                          .toList();
                      
                      filtered.sort((a, b) => a.yearPublished.compareTo(b.yearPublished));
                      
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No books in your wish list yet\n\nLike a book to add it'),
                        );
                      }
                      
                      return ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: filtered.map((book) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.grey.shade900.withValues(alpha: 0.7),
                              elevation: 4,
                              child: ListTile(
                                title: Text(book.title),
                                trailing: IconButton(
                                  icon: const Icon(Icons.favorite, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      book.wished = false;
                                    });
                                    _saveBook(book);
                                  },
                                ),
                                onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(
                                    book: book,
                                    allBooks: books,
                                    onChanged: _saveBook,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),

            /* ---------------- TDT TAB ---------------- */
            Builder(
              builder: (context) {
                if (tdtexBooks.isEmpty) {
                  return const Center(child: Text('No Dark Tower extended books found'));
                }
                
                // Separate main Dark Tower books from extended reading list
                final mainTowerBooks = tdtexBooks.where((book) => darkTowerOrder(book.id) != null).toList();
                final extendedBooks = tdtexBooks.where((book) => darkTowerOrder(book.id) == null).toList();
                
                // Sort main tower books by order
                mainTowerBooks.sort((a, b) {
                  final orderA = darkTowerOrder(a.id) ?? '';
                  final orderB = darkTowerOrder(b.id) ?? '';
                  return orderA.compareTo(orderB);
                });
                
                return ListView(
                  padding: const EdgeInsets.only(top: 10),
                  children: [
                    // Main Dark Tower Series Card
                    Card(
                      color: Colors.transparent,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.castle, color: Colors.amber, size: 28),
                                const SizedBox(width: 12),
                                const Text(
                                  'The Dark Tower Series',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...mainTowerBooks.map((book) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BookDetailScreen(
                                            book: book,
                                            allBooks: books,
                                            onChanged: _saveBook,
                                          ),
                                        ),
                                      );
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amber.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          buildDarkTowerBadge(darkTowerOrder(book.id)!),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  book.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  '${book.yearPublished}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Checkbox(
                                            value: book.owned,
                                            onChanged: (v) {
                                              setState(() {
                                                book.owned = v ?? false;
                                              });
                                              _saveBook(book);
                                            },
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          Checkbox(
                                            value: book.read,
                                            onChanged: (v) {
                                              setState(() {
                                                book.read = v ?? false;
                                              });
                                              _saveBook(book);
                                            },
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    
                    // Extended Reading List Info Card
                    Card(
                      color: Colors.grey.shade900.withValues(alpha: 0.4),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.purple.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_stories, color: Colors.purple.shade200, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'Extended Reading List',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The list below is a suggested readinglist for the extended experience to The Dark Tower Universe.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade300,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Extended books list
                    ...extendedBooks.map((book) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(
                                    book: book,
                                    allBooks: books,
                                    onChanged: _saveBook,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  buildDarkTowerBadge('TDTex'),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${book.yearPublished}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: book.owned,
                                    onChanged: (v) {
                                      setState(() {
                                        book.owned = v ?? false;
                                      });
                                      _saveBook(book);
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Checkbox(
                                    value: book.read,
                                    onChanged: (v) {
                                      setState(() {
                                        book.read = v ?? false;
                                      });
                                      _saveBook(book);
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),

            /* ---------------- STATISTICS TAB ---------------- */
            ListView(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
              children: [
                Card(
                  color: Colors.grey.shade900.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Books Statistics',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildStatRow('Total Books', books.length.toString()),
                        const SizedBox(height: 8),
                        _buildProgressStatRow('Read', books.where((b) => b.read).length, books.length, color: Colors.green),
                        _buildProgressStatRow('Owned', books.where((b) => b.owned).length, books.length, color: Colors.blue),
                        _buildProgressStatRow('Wish List', books.where((b) => b.wished).length, books.length, color: Colors.red),
                        const Divider(),
                        _buildStatRow('Novels', books.where((b) => b.type == 'Novel').length.toString()),
                        _buildStatRow('Short Story Collections', books.where((b) => b.type == 'Short Story Collection').length.toString()),
                        _buildStatRow('Novellas', books.where((b) => b.type == 'Novella').length.toString()),
                        _buildStatRow('Rated', books.where((b) => b.rating > 0).length.toString()),
                        _buildStatRow('Dark Tower Extended', books.where((b) => b.darkTowerExtended).length.toString()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.grey.shade900.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Film & TV Statistics',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildStatRow('Total Adaptations', adaptations.length.toString()),
                        const SizedBox(height: 8),
                        _buildProgressStatRow('Watched', adaptations.where((a) => a.watched).length, adaptations.length, color: Colors.green),
                        _buildProgressStatRow('Owned', adaptations.where((a) => a.owned).length, adaptations.length, color: Colors.blue),
                        const Divider(),
                        _buildStatRow('Movies', adaptations.where((a) => a.type == 'Movie').length.toString()),
                        _buildStatRow('TV Series', adaptations.where((a) => a.type == 'TV Series' || a.type == 'Miniseries').length.toString()),
                        _buildStatRow('Rated', adaptations.where((a) => a.rating > 0).length.toString()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
        floatingActionButton: AnimatedBuilder(
          animation: tabController,
          builder: (context, child) {
            return tabController.index < 2 ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  showSearch = !showSearch;
                  if (!showSearch) {
                    searchController.clear();
                    librarySearchQuery = '';
                    adaptationSearchQuery = '';
                    tdtexSearchQuery = '';
                    selectedAdaptationTypes.clear();
                    filterWatched = null;
                    filterAdaptationOwned = null;
                  }
                });
              },
              child: Icon(showSearch ? Icons.close : Icons.search),
            ) : const SizedBox.shrink();
          },
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressStatRow(String label, int current, int total, {Color color = Colors.blue}) {
    final percentage = total > 0 ? (current / total * 100).toStringAsFixed(1) : '0.0';
    final progress = total > 0 ? current / total : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 16)),
              Text('$current/$total ($percentage%)', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportWishlistToPdf() async {
    final pdf = pw.Document();
    final wishlist = books.where((b) => b.wished).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Stephen King - Wish List', 
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Total items: ${wishlist.length}', 
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Title', 'Year', 'Type', 'Owned', 'Read'],
            data: wishlist.map((book) => [
              book.title,
              book.yearPublished.toString(),
              book.type,
              book.owned ? 'Yes' : 'No',
              book.read ? 'Yes' : 'No',
            ]).toList(),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportStatisticsToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Stephen King - Statistics', 
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Books Statistics', 
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Category', 'Count'],
            data: [
              ['Total Books', books.length.toString()],
              ['Read', books.where((b) => b.read).length.toString()],
              ['Owned', books.where((b) => b.owned).length.toString()],
              ['Wish List', books.where((b) => b.wished).length.toString()],
              ['Novels', books.where((b) => b.type == 'Novel').length.toString()],
              ['Short Story Collections', books.where((b) => b.type == 'Short Story Collection').length.toString()],
              ['Novellas', books.where((b) => b.type == 'Novella').length.toString()],
              ['Dark Tower Extended', books.where((b) => b.darkTowerExtended).length.toString()],
            ],
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Film & TV Statistics', 
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Category', 'Count'],
            data: [
              ['Total Adaptations', adaptations.length.toString()],
              ['Movies', adaptations.where((a) => a.type == 'Movie').length.toString()],
              ['TV Series', adaptations.where((a) => a.type == 'TV Series' || a.type == 'Miniseries').length.toString()],
              ['Watched', adaptations.where((a) => a.watched).length.toString()],
              ['Owned', adaptations.where((a) => a.owned).length.toString()],
              ['Rated', adaptations.where((a) => a.rating > 0).length.toString()],
            ],
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

/* ---------------- DETAIL SCREEN ---------------- */

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final List<Book> allBooks;
  final void Function(Book) onChanged;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.allBooks,
    required this.onChanged,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late SharedPreferences prefs;
  bool synopsisLoading = false;

  @override
  void initState() {
    super.initState();
    _initSynopsis();
  }

  Future<void> _initSynopsis() async {
    prefs = await SharedPreferences.getInstance();
    final book = widget.book;
    
    // Først sjekk om synopsis finnes i JSON-dataen
    if (book.synopsis != null && book.synopsis!.isNotEmpty && book.notes.isEmpty) {
      setState(() {
        book.notes = book.synopsis!;
        book.synopsisFetched = true;
      });
      await prefs.setString('${book.id}_synopsis', book.synopsis!);
      return;
    }
    
    // Deretter sjekk SharedPreferences
    final savedSynopsis = prefs.getString('${book.id}_synopsis');
    if (savedSynopsis != null && savedSynopsis.isNotEmpty) {
      setState(() {
        book.notes = savedSynopsis;
        book.synopsisFetched = true;
      });
    } else if (!book.synopsisFetched && book.notes.isEmpty) {
      await _fetchAndSaveSynopsis();
    }
  }

  Future<void> _fetchAndSaveSynopsis() async {
    if (synopsisLoading) return;
    
    setState(() {
      synopsisLoading = true;
    });

    final synopsis = await fetchSynopsisFromOpenLibrary(widget.book.title, widget.book.yearPublished);
    
    if (synopsis != null && synopsis.isNotEmpty) {
      setState(() {
        widget.book.notes = synopsis;
        widget.book.synopsisFetched = true;
      });
      await prefs.setString('${widget.book.id}_synopsis', synopsis);
      widget.onChanged(widget.book);
    }
    
    setState(() {
      synopsisLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(book.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('lib/App_background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Published: ${book.yearPublished}'),
            Text('Type: ${book.type}'),
            if (darkTowerOrder(book.id) != null) ...[
              const SizedBox(height: 8),
              buildDarkTowerBadge(darkTowerOrder(book.id)!),
            ],
            
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Read'),
                      value: book.read,
                      onChanged: (value) {
                        setState(() {
                          book.read = value;
                          widget.onChanged(book);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Owned'),
                      value: book.owned,
                      onChanged: (value) {
                        setState(() {
                          book.owned = value;
                          widget.onChanged(book);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Wish List'),
                      value: book.wished,
                      onChanged: (value) {
                        setState(() {
                          book.wished = value;
                          widget.onChanged(book);
                        });
                      },
                    ),
                    const Divider(),
                    const Text('Rating:', style: TextStyle(fontSize: 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < book.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              book.rating = (index + 1).toDouble();
                              widget.onChanged(book);
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            if (book.connections.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                'Connections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...book.connections.map((connection) {
                final connectedBooks = widget.allBooks
                    .where((b) => connection.withIds.contains(b.id))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.type.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...connectedBooks.map((b) {
                      return ListTile(
                        title: Text(b.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(
                                book: b,
                                allBooks: widget.allBooks,
                                onChanged: widget.onChanged,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                );
              }),
            ],

            if (book.stories != null && book.stories!.isNotEmpty) ...[
              const SizedBox(height: 32),
              Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Text(
                      'READ',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.withOpacity(0.1),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Text(
                    'Stories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(book.stories!.length, (index) {
                return CheckboxListTile(
                  title: Row(
                    children: [
                      Text(
                        '${index + 1}. ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: Text(book.stories![index]),
                      ),
                    ],
                  ),
                  value: book.storiesRead.contains(index),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        book.storiesRead.add(index);
                      } else {
                        book.storiesRead.remove(index);
                      }
                    });
                    widget.onChanged(book);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Synopsis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (synopsisLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!book.synopsisFetched && book.notes.isEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.cloud_download, size: 18),
                    label: const Text('Fetch'),
                    onPressed: _fetchAndSaveSynopsis,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: TextEditingController(text: book.notes),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Book synopsis or description...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  book.notes = value;
                  widget.onChanged(book);
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/* ========================== ADAPTATION DETAIL SCREEN ========================== */
class AdaptationDetailScreen extends StatefulWidget {
  final Adaptation adaptation;
  final List<Book> books;
  final Function(Adaptation) onChanged;

  const AdaptationDetailScreen({
    super.key,
    required this.adaptation,
    required this.books,
    required this.onChanged,
  });

  @override
  State<AdaptationDetailScreen> createState() => _AdaptationDetailScreenState();
}

class _AdaptationDetailScreenState extends State<AdaptationDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final adaptation = widget.adaptation;
    final basedOnBook = adaptation.basedOn != null
        ? widget.books.firstWhere((b) => b.id == adaptation.basedOn,
            orElse: () => widget.books.first)
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(adaptation.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('lib/App_background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
          children: [
            Card(
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          adaptation.type.contains('Movie') || adaptation.type == 'Movie'
                              ? Icons.movie
                              : Icons.tv,
                          size: 40,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adaptation.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('${adaptation.year} • ${adaptation.type}'),
                              if (basedOnBook != null)
                                Text(
                                  'Based on: ${basedOnBook.title}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Watched'),
                      value: adaptation.watched,
                      onChanged: (value) {
                        setState(() {
                          adaptation.watched = value;
                          widget.onChanged(adaptation);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Owned'),
                      value: adaptation.owned,
                      onChanged: (value) {
                        setState(() {
                          adaptation.owned = value;
                          widget.onChanged(adaptation);
                        });
                      },
                    ),
                    const Divider(),
                    const Text('Rating:', style: TextStyle(fontSize: 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < adaptation.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              adaptation.rating = (index + 1).toDouble();
                              widget.onChanged(adaptation);
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Notes:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: adaptation.notes),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Your thoughts on this adaptation...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                adaptation.notes = value;
                widget.onChanged(adaptation);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================
   SETTINGS SCREEN
   ============================================ */

class SettingsScreen extends StatelessWidget {
  final List<Book> books;
  final List<Adaptation> adaptations;
  
  const SettingsScreen({
    super.key,
    required this.books,
    required this.adaptations,
  });

  Future<void> _exportData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all saved books
      final savedBooks = <String, dynamic>{};
      for (var book in books) {
        final key = 'book_${book.id}';
        final json = prefs.getString(key);
        if (json != null) {
          savedBooks[key] = jsonDecode(json);
        }
      }
      
      // Get all saved adaptations
      final savedAdaptations = <String, dynamic>{};
      for (var adaptation in adaptations) {
        final key = 'adaptation_${adaptation.id}';
        final json = prefs.getString(key);
        if (json != null) {
          savedAdaptations[key] = jsonDecode(json);
        }
      }
      
      final exportData = {
        'books': savedBooks,
        'adaptations': savedAdaptations,
        'exportDate': DateTime.now().toIso8601String(),
      };
      
      final jsonString = jsonEncode(exportData);
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'king_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json')
        ..click();
      
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Export error: $e');
    }
  }
  
  Future<void> _importData(BuildContext context) async {
    try {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = '.json';
      uploadInput.click();
      
      await uploadInput.onChange.first;
      final file = uploadInput.files?.first;
      if (file == null) return;
      
      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      
      final jsonString = reader.result as String;
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final prefs = await SharedPreferences.getInstance();
      
      // Import books
      final booksMap = importData['books'] as Map<String, dynamic>;
      for (var entry in booksMap.entries) {
        await prefs.setString(entry.key, jsonEncode(entry.value));
      }
      
      // Import adaptations
      final adaptationsMap = importData['adaptations'] as Map<String, dynamic>;
      for (var entry in adaptationsMap.entries) {
        await prefs.setString(entry.key, jsonEncode(entry.value));
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data imported successfully! Please restart the app.')),
        );
      }
    } catch (e) {
      print('Import error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
  
  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to clear all your saved data? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared. Please restart the app.')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/App_background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          children: [
            const SizedBox(height: 100),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Data Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(8),
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Data'),
                subtitle: const Text('Download your data as JSON'),
                onTap: _exportData,
              ),
            ),
            Card(
              margin: const EdgeInsets.all(8),
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Import Data'),
                subtitle: const Text('Restore data from JSON file'),
                onTap: () => _importData(context),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(8),
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear All Data'),
                subtitle: const Text('Reset all books and adaptations'),
                onTap: () => _clearData(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================
   ABOUT SCREEN
   ============================================ */

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/App_background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
          children: [
            Card(
              color: Colors.grey.shade900.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'King Tracker',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Version 1.0'),
                    const SizedBox(height: 16),
                    const Text(
                      'A comprehensive tracker for Stephen King\'s bibliography and adaptations.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Features:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Track 80+ Stephen King books'),
                    const Text('• Follow 83+ film and TV adaptations'),
                    const Text('• Multiple sorting modes including Dark Tower Extended reading order'),
                    const Text('• Connection tracking between books'),
                    const Text('• Statistics and analytics'),
                    const Text('• Wish list and favorites'),
                    const Text('• Data export and import'),
                    const SizedBox(height: 16),
                    const Text(
                      'About Stephen King:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Stephen King (born 1947) is an American author known as the "King of Horror". '
                      'He has published over 60 novels and 200 short stories, many of which have been '
                      'adapted into films, TV series, and miniseries.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IconologyScreen extends StatelessWidget {
  const IconologyScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Iconology Explained'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/App_background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
          children: [
            _buildIconSection(
              'Book Types',
              [
                _IconExplanation(Icons.auto_stories, 'Novel', 'Regular Stephen King novel'),
                _IconExplanation(Icons.castle, 'Dark Tower', 'Part of The Dark Tower series'),
                _IconExplanation(Icons.auto_stories, 'Bachman', 'Published under Richard Bachman pseudonym', color: Colors.orange),
                _IconExplanation(Icons.library_books, 'Short Story Collection', 'Collection of short stories'),
                _IconExplanation(Icons.people, 'Co-Authored', 'Written with another author'),
                _IconExplanation(Icons.article, 'Non-Fiction', 'Non-fiction work'),
              ],
            ),
            const SizedBox(height: 16),
            _buildIconSection(
              'Badges',
              [
                _IconExplanation(null, 'TDT 1-8', 'Main Dark Tower series book', badge: buildDarkTowerBadge('TDT 1')),
                _IconExplanation(null, 'TDTex', 'Extended Dark Tower reading list', 
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple, width: 1),
                    ),
                    child: const Text(
                      'TDTex',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildIconSection(
              'Connection Icons',
              [
                _IconExplanation(null, 'Duology/Trilogy', 'Book is part of a series', 
                  badge: buildConnectionIcon(Connection(type: 'duology', withIds: ['test']))),
                _IconExplanation(null, 'Dark Tower', 'Connected to Dark Tower universe', 
                  badge: buildConnectionIcon(Connection(type: 'dark tower', withIds: ['test']))),
              ],
            ),
            const SizedBox(height: 16),
            _buildIconSection(
              'Action Icons',
              [
                _IconExplanation(Icons.favorite, 'Wishlist', 'Book/adaptation on your wishlist', color: Colors.red),
                _IconExplanation(Icons.favorite_border, 'Not Wished', 'Add to wishlist', color: Colors.grey),
                _IconExplanation(Icons.star, 'Rating', 'Your rating (0-5 stars)', color: Colors.amber),
                _IconExplanation(Icons.check_box, 'Owned/Watched', 'You own this book or watched this adaptation'),
                _IconExplanation(Icons.check_box_outline_blank, 'Not Owned/Watched', 'You don\'t own/haven\'t watched this'),
              ],
            ),
            const SizedBox(height: 16),
            _buildIconSection(
              'Adaptation Types',
              [
                _IconExplanation(Icons.movie, 'Movie', 'Film adaptation'),
                _IconExplanation(Icons.tv, 'TV Series', 'Television series'),
                _IconExplanation(Icons.live_tv, 'Miniseries', 'TV miniseries'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection(String title, List<_IconExplanation> items) {
    return Card(
      color: Colors.grey.shade900.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (item.icon != null)
                    Icon(item.icon, color: item.color ?? Colors.blue, size: 24)
                  else if (item.badge != null)
                    item.badge!,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          item.description,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}

class _IconExplanation {
  final IconData? icon;
  final String title;
  final String description;
  final Color? color;
  final Widget? badge;

  _IconExplanation(this.icon, this.title, this.description, {this.color, this.badge});
}

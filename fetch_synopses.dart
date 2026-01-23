// Script for å hente synopser fra stephenking.com og oppdatere JSON-filen
// Kjør med: dart fetch_synopses.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('Henter synopser fra stephenking.com...\n');
  
  // Les eksisterende JSON
  final file = File('lib/assets/data/stephen_king_books.json');
  final jsonString = await file.readAsString();
  final List<dynamic> books = jsonDecode(jsonString);
  
  int updated = 0;
  int skipped = 0;
  int failed = 0;
  
  for (var book in books) {
    final title = book['title'] as String;
    final id = book['id'] as String;
    
    // Hopp over hvis synopsis allerede finnes
    if (book['synopsis'] != null && (book['synopsis'] as String).isNotEmpty) {
      skipped++;
      print('⊘ Hopper over $title - har allerede synopsis');
      continue;
    }
    
    print('→ Henter synopsis for: $title');
    
    try {
      final synopsis = await fetchSynopsisFromStephenKing(id, title);
      if (synopsis != null && synopsis.isNotEmpty) {
        book['synopsis'] = synopsis;
        updated++;
        print('✓ Funnet synopsis for: $title\n');
      } else {
        failed++;
        print('✗ Ingen synopsis funnet for: $title\n');
      }
      
      // Vent litt mellom requests
      await Future.delayed(Duration(milliseconds: 800));
    } catch (e) {
      failed++;
      print('✗ Feil for $title: $e\n');
    }
  }
  
  // Lagre oppdatert JSON med pen formatering
  final encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(books));
  
  print('\n========== FERDIG ==========');
  print('✓ Oppdatert: $updated bøker');
  print('⊘ Hoppet over: $skipped bøker');
  print('✗ Feilet: $failed bøker');
  print('============================\n');
}

Future<String?> fetchSynopsisFromStephenKing(String bookId, String title) async {
  // Prøv forskjellige URL-varianter
  final types = ['novel', 'collection', 'nonfiction', 'novella'];
  
  // Lag slug fra ID
  final slugFromId = bookId.replaceAll('_', '-');
  
  for (final type in types) {
    final url = 'https://stephenking.com/works/$type/$slugFromId.html';
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final body = response.body;
        
        // Synopsis kommer rett etter PUBLISHER og før ## Images
        // Mønster: PUBLISHER\n\nDoubleday\n\nSynopsis text\n\n## Images
        final synopsisPattern = RegExp(
          r'PUBLISHER\s+.*?\s+(.*?)\s+(?:##\s*Images|From the Flap)',
          dotAll: true,
          multiLine: true,
        );
        
        final match = synopsisPattern.firstMatch(body);
        if (match != null) {
          var synopsis = match.group(1)?.trim() ?? '';
          
          // Fjern HTML-tags og whitespace
          synopsis = synopsis
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .replaceAll('&#39;', "'")
              .replaceAll('&rsquo;', "'")
              .replaceAll('&ldquo;', '"')
              .replaceAll('&rdquo;', '"')
              .replaceAll('&ndash;', '–')
              .replaceAll('&mdash;', '—')
              .trim();
          
          // Valider at synopsis er brukbar
          if (synopsis.length > 50 && !synopsis.contains('RELEASED') && !synopsis.contains('AVAILABLE FORMAT')) {
            return synopsis;
          }
        }
      }
    } catch (e) {
      // Prøv neste type/URL
      continue;
    }
  }
  
  return null;
}

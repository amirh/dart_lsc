import 'dart:convert';

import 'package:http/http.dart' as http;

class DependentsFetcher {
  DependentsFetcher(this.targetPackage) : assert(targetPackage != null) {
    final Uri url = Uri.http('pub.dev', '/api/search', {
      'q': 'dependency:$targetPackage',
    });
    _nextPageUrl = url.toString();
  }

  get dependentPackages => _dependentPackages;
  List<String> _dependentPackages = [];
  String targetPackage;
  String _nextPageUrl;

  Future<bool> fetchNextPage() async {
    print('Getting $_nextPageUrl');
    final http.Response response = await http.get(
        _nextPageUrl,
      headers: {
         'User-Agent': 'dart-lsc / 1.0.0+dev'
      }
    );

    if (response.statusCode != 200) {
      throw Exception('Failed fetching $_nextPageUrl response was: ${response.body}');
    }

    Map<String, dynamic> responseMap = jsonDecode(response.body);
    List<dynamic> dependents = responseMap['packages'];
    _dependentPackages.addAll(dependents.map((e) => e['package']));
    
    if (responseMap.containsKey('next')) {
      _nextPageUrl = responseMap['next'];
      return true;
    } else {
      _nextPageUrl = null;
      return false;
    }
  }
}
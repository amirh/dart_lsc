import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubIssue {
  GitHubIssue(this.repository, this.project, this.number, this.id, this.title, this.cardId) :
        assert(repository != null),
        assert(number != null),
        assert(title != null);

  final GitHubRepository repository;
  final GitHubProject project;
  final int number;
  String id;
  final String title;
  final String cardId;

  String get package {
    int closingBracketIndex = title.indexOf(']');
    if (!title.startsWith('[') || closingBracketIndex == -1) {
      throw Exception('Expecting issue title to start with "[<package]" was: $title');
    }
    return title.substring(1, closingBracketIndex);
  }

  void moveToProjectColumn(String columnName) async {
    String columnId = project.columns[columnName];
    if (columnId == null) {
      throw Exception("Can't move card to an unknown column $columnName");
    }
    final String query = '''
      mutation {
        moveProjectCard(input:{cardId:"${cardId}",columnId:"$columnId"}) {
          clientMutationId
        }
      }
    ''';

    await repository.client.executeGraphQL(query);
  }

  void addComment(String body) async {
    final String query = '''
      mutation {
        addComment(input:{subjectId:"$id",body:"""$body"""}) {
          clientMutationId
        }
      }
    ''';

    await repository.client.executeGraphQL(query);
  }

  void closeIssue() async {
    final String query = '''
      mutation {
        closeIssue(input:{issueId:"$id"}) {
          clientMutationId
        }
      }
    ''';

    await repository.client.executeGraphQL(query);
  }

  @override
  String toString() {
    return 'GitHubIssue{number: $number, title: $title}';
  }
}

class GitHubProject {
  GitHubProject(this.repository, this.projectId, this.projectNumber, this.columns, this.url)
      : assert(repository != null),
        assert(projectId != null),
        assert(projectNumber != null),
        assert(columns != null);

  final GitHubRepository repository;
  final String projectId;
  final String projectNumber;
  final Map<String, String> columns;
  final String url;

  static Future<GitHubProject> initProject(GitHubRepository repository, String projectId, String projectNumber, String url) async {
    Map<String, String> columns = await fetchColumns(repository, projectNumber);
    return GitHubProject(repository, projectId, projectNumber, columns, url);
  }

  static Future<Map<String, String>> fetchColumns(GitHubRepository repository, String projectNumber) async {
    final String query = '''
      query {
        repository(owner:"${repository.owner}", name:"${repository.name}") {
          project(number:  $projectNumber) {
            columns(first: 10){
              nodes {
                id
                name
              }
            }
          }
        }
      }
    ''';

    Map<String, dynamic> result = await repository.client.executeGraphQL(query);

    Map<String, String> columns = {};
    for(var column in result['data']['repository']['project']['columns']['nodes']) {
      columns[column['name']] = column['id'];
    }
    return columns;
  }

  Future<List<GitHubIssue>> getColumnIssues(String columnName) async {
    if (!columns.containsKey(columnName)) {
      throw Exception('Column "$columnName" does not exist in project $url');
    }
    final int pageSize = 100;
    String cursor = null;
    int seen = 0;
    int totalCount;
    List<GitHubIssue> allIssues = [];
    do {
      String pageFilter;
      if (cursor == null) {
        pageFilter = 'first: $pageSize';
      } else {
        pageFilter = 'first: $pageSize after:"$cursor"';
      }
      final String query = '''
        query {
          node(id:"${columns[columnName]}") {
            ... on ProjectColumn {
              cards($pageFilter) {
                totalCount
                edges {
                  node {
                    id
                    content {
                      ... on Issue {
                        id
                        number
                        title
                      }
                    }
                  }
                  cursor
                }
              }
            }
          }
        }
      ''';
      Map<String, dynamic> result = await repository.client.executeGraphQL(query);
      print ('$result');
      Map<String, dynamic> cards = result['data']['node']['cards'];
      totalCount = cards['totalCount'];
      if (totalCount == 0) {
        break;
      }
      cursor = cards['edges'].last['cursor'];

      for (Map<String,dynamic> edge in cards['edges']) {
        Map<String, dynamic> issueMap = edge['node']['content'];
        String cardId = edge['node']['id'];
        allIssues.add(GitHubIssue(
            repository,
            this,
            issueMap['number'],
            issueMap['id'],
            issueMap['title'],
            cardId
        ));
      }
      seen += pageSize;
    } while (seen < totalCount);

    return allIssues;
  }

  void createIssue(String title, String body) async {
    final String query = '''
      mutation {
        createIssue(input:{repositoryId:"${repository.repositoryId}",title:"$title",body:"$body"}) {
          issue {
            id
            number
            url
          }
        }
      }
    ''';

    dynamic result = await repository.client.executeGraphQL(query);
    String issueId = result['data']['createIssue']['issue']['id'];
    int issueNumber = result['data']['createIssue']['issue']['number'];
    String url = result['data']['createIssue']['issue']['url'];

    await addCard(issueId);
  }

  void addCard(String issueId) async {
    final String todoId = columns['TODO'];
    final String query = '''
      mutation {
        addProjectCard(input:{contentId:"${issueId}",projectColumnId:"$todoId"}) {
          clientMutationId
        }
      }
    ''';


    await repository.client.executeGraphQL(query);
  }

  Future<List<GitHubIssue>> getIssuesByColumn(String columnName) async {
    if (!columns.containsKey(columnName)) {
      throw Exception('No project named "$columnName" in project $url');
    }

    final String query = '''
      query {
        repository(owner:"${repository.owner}", name:"${repository.name}") {
          project(number:  $projectNumber) {
            columns(first: 10){
              nodes {
                id
                name
              }
            }
          }
        }
      }
    ''';
  }

}

class GitHubRepository {
  GitHubRepository(this.client, this.repositoryId, this.owner, this.name) :
        assert(client != null),
        assert(repositoryId != null),
        assert(owner != null),
        assert(name != null);

  final GitHubClient client;
  final String repositoryId;
  final String owner;
  final String name;

  Future<GitHubProject> getLscProject(String number) async {
    final String projectId = await client.getProjectId(owner, name, number);
    return GitHubProject.initProject(this, projectId, '$number', null);

  }

  Future<GitHubProject> createLscProject(String name) async {
    final String templateProjectId = await client.getProjectId('amirh', 'dart_lsc', '1');

    final String query = '''
      mutation {
        cloneProject(input:{name:"$name",sourceId:"$templateProjectId",targetOwnerId:"$repositoryId",includeWorkflows:true}) {
          project {
            id
            number 
            url
          }
        }
      }
    ''';

    dynamic result = await client.executeGraphQL(query);
    String projectId = result['data']['cloneProject']['project']['id'];
    int projectNumber = result['data']['cloneProject']['project']['number'];
    String url = result['data']['cloneProject']['project']['url'];
    return GitHubProject.initProject(this, projectId, '$projectNumber', url);
  }


}
class GitHubClient {
  static final Uri GitHubEndPoint = Uri.https('api.github.com', '/graphql');

  GitHubClient(this._authToken) : assert(_authToken != null);

  final String _authToken;

  Future<GitHubRepository> getRepository(String owner, String repository) async {
    final String repositoryId = await getRepositoryId(owner, repository);
    return GitHubRepository(this, repositoryId, owner, repository);
  }

  Future<String> getRepositoryId(String owner, String repository) async {
    final String query = '''
      query {
        repository(owner:"$owner", name:"$repository") {
          id
        }
      }
    ''';

    Map<String, dynamic> result = await executeGraphQL(query);
    return result['data']['repository']['id'];
  }

  Future<String> getProjectId(String owner, String repository, String projectNumber) async {
    final String query = '''
      query {
        repository(owner:"$owner", name:"$repository") {
          project(number:  $projectNumber) {
            id
          }
        }
      }
    ''';

    Map<String, dynamic> result = await executeGraphQL(query);
    return result['data']['repository']['project']['id'];
  }

  dynamic executeGraphQL(String query) async {

    final String command = jsonEncode({
      'query': query,
    });

    http.Response response = await http.post(GitHubEndPoint,
      body: command,
      headers: {
        'Authorization': 'bearer $_authToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed posting query to GitHub response was: ${response.body}\ncommand was: $command');
    }

    return jsonDecode(response.body);
  }
}
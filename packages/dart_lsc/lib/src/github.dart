import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

class GitHubPullRequest {
  GitHubPullRequest(this.id, this.merged, this.commentsCount, this.closed);

  final String id;
  final bool merged;
  final int commentsCount;
  final bool closed;

  @override
  String toString() {
    return 'GitHubPullRequest{id: $id, merged: $merged, commentsCount: $commentsCount}';
  }
}

class GitHubIssue {
  GitHubIssue(this.repository, this.project, this.number, this.id, this.title, this.cardId, this.body) :
        assert(repository != null),
        assert(number != null),
        assert(title != null);

  final GitHubRepository repository;
  final GitHubProject project;
  final int number;
  String id;
  final String title;
  final String cardId;
  final String body;

  String get package {
    int closingBracketIndex = title.indexOf(']');
    if (!title.startsWith('[') || closingBracketIndex == -1) {
      throw Exception('Expecting issue title to start with "[<package]" was: $title');
    }
    return title.substring(1, closingBracketIndex);
  }

  void markManualIntervention(String comment, {bool dryRun=false}) async {
    if (dryRun) {
      print('[dry_run] Marking $package for manual intervention with comment: $comment');
      return;
    }
    await addComment(comment);
    moveToProjectColumn('Need Manual Intervention');
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

  Map<String, dynamic> getMetadata() {
    List<String> lines = body.split('\n');
    bool inMetadataSection = false;
    StringBuffer rawMetadata = StringBuffer();
    for (String line in lines) {
      if (line == '```') {
        if (!inMetadataSection) {
          inMetadataSection = true;
          continue;
        }
        break;
      }
      if (inMetadataSection) {
        rawMetadata.write('$line\n');
      }
    }
    if (!inMetadataSection) {
      return {};
    }
    return jsonDecode(rawMetadata.toString());
  }

  void setMetadata(Map<String, dynamic> metaData) async {
    List<String> lines = body.split('\n');
    StringBuffer newBody = StringBuffer();
    for (String line in lines) {
      if (line == '```') {
        break;
      }
      newBody.write('$line\n');
    }
    newBody.write('```\n');
    newBody.write('${jsonEncode(metaData)}\n');
    newBody.write('```');

    final String query = '''
      mutation {
        updateIssue(input:{id:"$id",body:"""$newBody"""}) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubIssue &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
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
                        body
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
          cardId,
          issueMap['body'],
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

  Future<Set<String>> getForks() async {
    final int pageSize = 100;
    String cursor = null;
    int totalCount;
    int seen = 0;
    Set<String> allForks = {};
    do {
      String pageFilter;
      if (cursor == null) {
        pageFilter = 'first: $pageSize';
      } else {
        pageFilter = 'first: $pageSize after:"$cursor"';
      }
      final String query = '''
        query {
          node(id:"$repositoryId") {
            ... on Repository {
              forks(affiliations:[OWNER],$pageFilter) {
                totalCount
                edges {
                  node {
                    nameWithOwner
                  }
                  cursor
                }
              }
            }
          }
        }
    ''';
      dynamic result = await client.executeGraphQL(query);
      Map<String, dynamic> forks = result['data']['node']['forks'];
      totalCount = forks['totalCount'];
      if (totalCount == 0) {
        break;
      }
      cursor = forks['edges'].last['cursor'];
      for (Map<String,dynamic> edge in forks['edges']) {
        allForks.add(edge['node']['nameWithOwner']);
      }
      seen += pageSize;
    } while (seen < totalCount);

    return allForks;
  }

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

  Future<String> sendPullRequest({
    @required String targetBranch,
    @required String sendingOwner,
    @required String headBranch,
    @required String title,
    @required String body,
  }) async {
    String input =
        'baseRefName:"$targetBranch",'
        'headRefName:"$sendingOwner:$headBranch",'
        'repositoryId:"$repositoryId",'
        'maintainerCanModify:true,'
        'title:"$title",'
        'body:"$body"';
    final String query = '''
      mutation {
        createPullRequest(input:{$input}) {
          pullRequest {
            url
          }
        }
      }
    ''';

    //print('query would have been:\n$query');
    //return 'https://github.com/flutter/plugins/pull/2597';
    dynamic result = await client.executeGraphQL(query);
    String url = result['data']['createPullRequest']['pullRequest']['url'];
    return url;
  }
}

class GitHubAuthData {
  GitHubAuthData(this.scopes, this.userName, this.userLogin);

  final Set<String> scopes;
  final String userName;
  final String userLogin;
}

class GitHubClient {
  static final Uri GitHubEndPoint = Uri.https('api.github.com', '/graphql');
  static final String GitHubV3EndPoint = 'api.github.com';

  GitHubClient(this._authToken) : assert(_authToken != null);

  final String _authToken;

  Future<GitHubRepository> getRepository(String owner, String repository) async {
    final String repositoryId = await getRepositoryId(owner, repository);
    return GitHubRepository(this, repositoryId, owner, repository);
  }

  Future<GitHubPullRequest> getPullRequest(String owner, String repository, String number) async {
    final String query = '''
      query {
        repository(owner:"$owner", name:"$repository") {
          pullRequest(number:$number) {
            id
            merged
            closed
            comments {
              totalCount
            }
          }
        }
      }
    ''';

    Map<String, dynamic> result = await executeGraphQL(query);
    String id = result['data']['repository']['pullRequest']['id'];
    bool merged = result['data']['repository']['pullRequest']['merged'];
    bool closed = result['data']['repository']['pullRequest']['closed'];
    int commentsCount = result['data']['repository']['pullRequest']['comments']['totalCount'];
    return GitHubPullRequest(id, merged, commentsCount, closed);
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

  // Returns null if the client is properly authenticated, an error message otherwise.
  Future<String> verifyAuthentication() async {
    try {
      final GitHubAuthData authData = await getAuthData();
      if (!authData.scopes.containsAll(['repo', 'delete_repo'])) {
        return 'A valid GitHub token with the "repo" and "delete_repo" scopes is required';
      }
    } on GitHubAuthException catch (e) {
      return 'Failed to authenticate. Reponse was:\n${e.message}';
    }

    return null;
  }

  Future<GitHubAuthData> getAuthData() async {
    final String query = '''
      query {
        viewer {
          name
          login
        }
      }
    ''';

    http.Response response = await executeGraphQLRawResponse(query);

    Set<String> scopes = {};
    if (response.headers.containsKey('x-oauth-scopes')) {
      String scopesString = response.headers['x-oauth-scopes'];
      scopes.addAll(scopesString.split(', '));
    }

    Map<String, dynamic> result = jsonDecode(response.body);

    return GitHubAuthData(
      scopes,
      result['data']['viewer']['name'],
      result['data']['viewer']['login'],
    );
  }

  void forkRepository(String owner, String repository) async {
    // Forking is not supported by the GitHub GraphQl v3 API.
    // Using the v3 REST API.
    Uri uri = Uri.https('api.github.com', '/repos/$owner/$repository/forks');

    http.Response response = await http.post(uri,
      headers: {
        'Authorization': 'token $_authToken',
      },
    );

    if (response.statusCode != 202) {
      throw Exception('Failed posting request to GitHub response was: ${response.body}\nUri was: $uri');
    }
  }

  void deleteRepository(String owner, String repository) async {
    // Forking is not supported by the GitHub GraphQl v3 API.
    // Using the v3 REST API.
    Uri uri = Uri.https('api.github.com', '/repos/$owner/$repository');

    http.Response response = await http.delete(uri,
      headers: {
        'Authorization': 'token $_authToken',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed posting request to GitHub response was: ${response.body}\nUri was: $uri');
    }
  }

  dynamic executeGraphQL(String query) async {
    http.Response response = await executeGraphQLRawResponse(query);

    return jsonDecode(response.body);
  }

  Future<http.Response> executeGraphQLRawResponse(String query) async {
    final String command = jsonEncode({
      'query': query,
    });

    http.Response response = await http.post(GitHubEndPoint,
      body: command,
      headers: {
        'Authorization': 'bearer $_authToken',
      },
    );

    if (response.statusCode == 401) { // Unauthorized
      Map<String, dynamic> body = jsonDecode(response.body);

      throw GitHubAuthException(
          body.containsKey('message') ? body['message'] : 'GitHub authentication failed'
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Failed posting query to GitHub response was: ${response.body}\ncommand was: $command');
    }

    return response;
  }
}

class GitHubAuthException implements Exception {
  GitHubAuthException(this.message);

  final String message;

  @override
  String toString() {
    return 'GitHubAuthException{message: $message}';
  }
}


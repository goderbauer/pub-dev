// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test/test.dart';

import 'package:pub_dev/search/mem_index.dart';
import 'package:pub_dev/search/result_combiner.dart';
import 'package:pub_dev/search/search_service.dart';

void main() {
  group('ResultCombiner', () {
    final primaryIndex = InMemoryPackageIndex();
    final dartSdkIndex = InMemoryPackageIndex.sdk(
        urlPrefix: 'https://api.dartlang.org/stable/2.0.0');
    final combiner = SearchResultCombiner(
        primaryIndex: primaryIndex, dartSdkIndex: dartSdkIndex);

    setUpAll(() async {
      await primaryIndex.addPackage(PackageDocument(
        package: 'stringutils',
        version: '1.0.0',
        description: 'many utils utils',
        readme: 'Many useful string methods like substring.',
        popularity: 0.4,
        grantedPoints: 110,
        maxPoints: 110,
        uploaderEmails: ['foo@example.com'],
      ));
      await dartSdkIndex.addPackage(PackageDocument(
        package: 'dart:core',
        description: 'Dart core utils',
        apiDocPages: [
          ApiDocPage(
            relativePath: 'dart-core/String-class.html',
            symbols: ['String', 'substring', 'stringutils'],
          )
        ],
      ));

      await primaryIndex.markReady();
      await dartSdkIndex.markReady();
    });

    test('non-text ranking', () async {
      final results = await combiner
          .search(ServiceSearchQuery.parse(order: SearchOrder.popularity));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'packages': [
          {'package': 'stringutils', 'score': 0.4},
        ],
        'sdkLibraryHits': [],
        'packageHits': [
          {'package': 'stringutils', 'score': 0.4},
        ],
      });
    });

    test('no actual text query', () async {
      final results = await combiner
          .search(ServiceSearchQuery.parse(query: 'email:foo@example.com'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'packages': [
          {'package': 'stringutils', 'score': closeTo(0.8, 0.01)},
        ],
        'sdkLibraryHits': [],
        'packageHits': [
          {'package': 'stringutils', 'score': closeTo(0.8, 0.01)},
        ],
      });
    });

    test('search: substring', () async {
      final results =
          await combiner.search(ServiceSearchQuery.parse(query: 'substring'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'packages': [
          {
            'package': 'dart:core',
            'score': closeTo(0.69, 0.01),
            'url':
                'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html',
            'description': 'Dart core utils',
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String-class.html',
                'url':
                    'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html'
              },
            ],
          },
          {'package': 'stringutils', 'score': closeTo(0.59, 0.01)},
        ],
        'sdkLibraryHits': [
          {
            'sdk': 'dart',
            'library': 'dart:core',
            'description': 'Dart core utils',
            'url':
                'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html',
            'score': closeTo(0.69, 0.01),
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String-class.html',
                'url':
                    'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html'
              }
            ]
          }
        ],
        'packageHits': [
          {'package': 'stringutils', 'score': closeTo(0.59, 0.01)}
        ],
      });
    });

    test('exact name match: stringutils', () async {
      final results =
          await combiner.search(ServiceSearchQuery.parse(query: 'stringutils'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'packages': [
          {'package': 'stringutils', 'score': closeTo(0.80, 0.01)},
          {
            'package': 'dart:core',
            'score': closeTo(0.69, 0.01),
            'url':
                'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html',
            'description': 'Dart core utils',
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String-class.html',
                'url':
                    'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html'
              },
            ],
          },
        ],
        'highlightedHit': {'package': 'stringutils'},
        'sdkLibraryHits': [
          {
            'sdk': 'dart',
            'library': 'dart:core',
            'description': 'Dart core utils',
            'url':
                'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html',
            'score': closeTo(0.69, 0.01),
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String-class.html',
                'url':
                    'https://api.dartlang.org/stable/2.0.0/dart-core/String-class.html'
              }
            ]
          }
        ],
        'packageHits': [],
      });
    });
  });
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageDocument _$PackageDocumentFromJson(Map<String, dynamic> json) {
  return PackageDocument(
    package: json['package'] as String,
    version: json['version'] as String,
    description: json['description'] as String,
    created: json['created'] == null
        ? null
        : DateTime.parse(json['created'] as String),
    updated: json['updated'] == null
        ? null
        : DateTime.parse(json['updated'] as String),
    readme: json['readme'] as String,
    tags: (json['tags'] as List)?.map((e) => e as String)?.toList(),
    popularity: (json['popularity'] as num)?.toDouble(),
    likeCount: json['likeCount'] as int,
    grantedPoints: json['grantedPoints'] as int,
    maxPoints: json['maxPoints'] as int,
    dependencies: (json['dependencies'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
    publisherId: json['publisherId'] as String,
    uploaderEmails:
        (json['uploaderEmails'] as List)?.map((e) => e as String)?.toList(),
    apiDocPages: (json['apiDocPages'] as List)
        ?.map((e) =>
            e == null ? null : ApiDocPage.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    timestamp: json['timestamp'] == null
        ? null
        : DateTime.parse(json['timestamp'] as String),
  );
}

Map<String, dynamic> _$PackageDocumentToJson(PackageDocument instance) =>
    <String, dynamic>{
      'package': instance.package,
      'version': instance.version,
      'description': instance.description,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'readme': instance.readme,
      'tags': instance.tags,
      'popularity': instance.popularity,
      'likeCount': instance.likeCount,
      'grantedPoints': instance.grantedPoints,
      'maxPoints': instance.maxPoints,
      'dependencies': instance.dependencies,
      'publisherId': instance.publisherId,
      'uploaderEmails': instance.uploaderEmails,
      'apiDocPages': instance.apiDocPages,
      'timestamp': instance.timestamp?.toIso8601String(),
    };

ApiDocPage _$ApiDocPageFromJson(Map<String, dynamic> json) {
  return ApiDocPage(
    relativePath: json['relativePath'] as String,
    symbols: (json['symbols'] as List)?.map((e) => e as String)?.toList(),
    textBlocks: (json['textBlocks'] as List)?.map((e) => e as String)?.toList(),
  );
}

Map<String, dynamic> _$ApiDocPageToJson(ApiDocPage instance) =>
    <String, dynamic>{
      'relativePath': instance.relativePath,
      'symbols': instance.symbols,
      'textBlocks': instance.textBlocks,
    };

PackageSearchResult _$PackageSearchResultFromJson(Map<String, dynamic> json) {
  return PackageSearchResult(
    timestamp: json['timestamp'] == null
        ? null
        : DateTime.parse(json['timestamp'] as String),
    totalCount: json['totalCount'] as int,
    packages: (json['packages'] as List)
        ?.map((e) =>
            e == null ? null : PackageScore.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    highlightedHit: json['highlightedHit'] == null
        ? null
        : PackageHit.fromJson(json['highlightedHit'] as Map<String, dynamic>),
    sdkLibraryHits: (json['sdkLibraryHits'] as List)
        ?.map((e) => e == null
            ? null
            : SdkLibraryHit.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    packageHits: (json['packageHits'] as List)
        ?.map((e) =>
            e == null ? null : PackageHit.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    message: json['message'] as String,
  );
}

Map<String, dynamic> _$PackageSearchResultToJson(PackageSearchResult instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('timestamp', instance.timestamp?.toIso8601String());
  writeNotNull('totalCount', instance.totalCount);
  writeNotNull('packages', instance.packages);
  writeNotNull('highlightedHit', instance.highlightedHit);
  writeNotNull('sdkLibraryHits', instance.sdkLibraryHits);
  writeNotNull('packageHits', instance.packageHits);
  writeNotNull('message', instance.message);
  return val;
}

PackageScore _$PackageScoreFromJson(Map<String, dynamic> json) {
  return PackageScore(
    package: json['package'] as String,
    score: (json['score'] as num)?.toDouble(),
    url: json['url'] as String,
    version: json['version'] as String,
    description: json['description'] as String,
    apiPages: (json['apiPages'] as List)
        ?.map((e) =>
            e == null ? null : ApiPageRef.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$PackageScoreToJson(PackageScore instance) {
  final val = <String, dynamic>{
    'package': instance.package,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('score', instance.score);
  writeNotNull('url', instance.url);
  writeNotNull('version', instance.version);
  writeNotNull('description', instance.description);
  writeNotNull('apiPages', instance.apiPages);
  return val;
}

SdkLibraryHit _$SdkLibraryHitFromJson(Map<String, dynamic> json) {
  return SdkLibraryHit(
    sdk: json['sdk'] as String,
    version: json['version'] as String,
    library: json['library'] as String,
    description: json['description'] as String,
    url: json['url'] as String,
    score: (json['score'] as num)?.toDouble(),
    apiPages: (json['apiPages'] as List)
        ?.map((e) =>
            e == null ? null : ApiPageRef.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$SdkLibraryHitToJson(SdkLibraryHit instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('sdk', instance.sdk);
  writeNotNull('version', instance.version);
  writeNotNull('library', instance.library);
  writeNotNull('description', instance.description);
  writeNotNull('url', instance.url);
  writeNotNull('score', instance.score);
  writeNotNull('apiPages', instance.apiPages);
  return val;
}

PackageHit _$PackageHitFromJson(Map<String, dynamic> json) {
  return PackageHit(
    package: json['package'] as String,
    score: (json['score'] as num)?.toDouble(),
    apiPages: (json['apiPages'] as List)
        ?.map((e) =>
            e == null ? null : ApiPageRef.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$PackageHitToJson(PackageHit instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('package', instance.package);
  writeNotNull('score', instance.score);
  writeNotNull('apiPages', instance.apiPages);
  return val;
}

ApiPageRef _$ApiPageRefFromJson(Map<String, dynamic> json) {
  return ApiPageRef(
    title: json['title'] as String,
    path: json['path'] as String,
    url: json['url'] as String,
  );
}

Map<String, dynamic> _$ApiPageRefToJson(ApiPageRef instance) {
  final val = <String, dynamic>{
    'title': instance.title,
    'path': instance.path,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('url', instance.url);
  return val;
}

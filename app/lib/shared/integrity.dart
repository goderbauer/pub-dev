// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';
import 'package:pool/pool.dart';

import '../account/models.dart';
import '../package/models.dart';
import '../publisher/models.dart';
import '../shared/datastore.dart';
import '../shared/tags.dart' show allowedTagPrefixes;

import 'email.dart' show looksLikeEmail;

final _logger = Logger('integrity.check');

/// Checks the integrity of the datastore.
class IntegrityChecker {
  final DatastoreDB _db;
  final int _concurrency;
  final _problems = <String>[];

  final _userToOauth = <String, String>{};
  final _oauthToUser = <String, String>{};
  final _emailToUser = <String, List<String>>{};
  final _deletedUsers = <String>{};
  final _invalidUsers = <String>{};
  final _userToLikes = <String, List<String>>{};
  final _packages = <String>{};
  final _packageReplacedBys = <String, String>{};
  final _packagesWithVersion = <String>{};
  final _moderatedPackages = <String>{};
  final _publishers = <String>{};
  final _publishersAbandoned = <String>{};
  int _packageChecked = 0;
  int _versionChecked = 0;

  IntegrityChecker(this._db, {int concurrency})
      : _concurrency = concurrency ?? 1;

  /// Runs integrity checks, and reports the list of problems.
  Future<List<String>> check() async {
    await _checkUsers();
    await _checkOAuthUserIDs();
    await _checkPublishers();
    await _checkPublisherMembers();
    await _checkPackages();
    await _checkVersions();
    await _checkLikes();
    await _checkModeratedPackages();
    return _problems;
  }

  Future<void> _checkUsers() async {
    _logger.info('Scanning Users...');
    await for (User user in _db.query<User>().run()) {
      _userToOauth[user.userId] = user.oauthUserId;
      if (user.email == null ||
          user.email.isEmpty ||
          !looksLikeEmail(user.email)) {
        _problems.add('User(${user.userId}) has invalid email: ${user.email}');
        _invalidUsers.add(user.userId);
      }
      if (user.email != null && user.email.isNotEmpty) {
        _emailToUser.putIfAbsent(user.email, () => []).add(user.userId);
      }
      if (user.isDeleted == null || user.isDeleted is! bool) {
        _problems.add(
            'User(${user.userId}) has a `isDeleted` property which is not a bool.');
      }
      if (user.isBlocked == null || user.isBlocked is! bool) {
        _problems.add(
            'User(${user.userId}) has a `isBlocked` property which is not a bool.');
      }
      if (user.isDeleted) {
        _deletedUsers.add(user.userId);
        if (user.oauthUserId != null) {
          _problems.add(
              'User(${user.userId}) is deleted, but oauthUserId is still set.');
        }
        if (user.created != null) {
          _problems.add(
              'User(${user.userId}) is deleted, but created time is still set.');
        }
      }
    }
    int badEmailToUserMappingCount = 0;
    _emailToUser.forEach((email, userIds) {
      if (userIds.length > 1) {
        badEmailToUserMappingCount++;
        _problems.add(
            'Email address $email is present at ${userIds.length} User: ${userIds.join(', ')}');
      }
    });
    if (badEmailToUserMappingCount > 0) {
      _problems.add(
          '$badEmailToUserMappingCount email addresses have more than one User entity.');
    }
  }

  Future<void> _checkOAuthUserIDs() async {
    _logger.info('Scanning OAuthUserIDs...');
    await for (OAuthUserID mapping in _db.query<OAuthUserID>().run()) {
      if (mapping.userIdKey == null || mapping.userId == null) {
        _problems
            .add('OAuthUserID(${mapping.oauthUserId}) has invalid userId.');
      }
      _oauthToUser[mapping.oauthUserId] = mapping.userId;
    }

    for (String userId in _userToOauth.keys) {
      final oauthUserId = _userToOauth[userId];
      // Migrated users without login are OK.
      if (oauthUserId == null) {
        continue;
      }
      final pointer = _oauthToUser[oauthUserId];
      if (pointer == null) {
        _problems.add(
            'User($userId) points to OAuthUserID($oauthUserId) but has no mapping.');
      } else if (pointer != userId) {
        _problems.add(
            'User($userId) points to OAuthUserID($oauthUserId) but it points to a different one ($pointer).');
      }
    }

    for (String oauthUserId in _oauthToUser.keys) {
      final userId = _oauthToUser[oauthUserId];
      if (userId == null) {
        _problems.add('OAuthUserID($oauthUserId) has no user.');
      }
      final pointer = _userToOauth[userId];
      if (pointer == null) {
        _problems.add(
            'User($userId) is mapped from OAuthUserID($oauthUserId), but does not have it set.');
      } else if (pointer != oauthUserId) {
        _problems.add(
            'User($userId) is mapped from OAuthUserID($oauthUserId), but points to a different one ($pointer).');
      }
    }
  }

  Future<void> _checkPublishers() async {
    _logger.info('Scanning Publishers...');
    await for (final p in _db.query<Publisher>().run()) {
      _publishers.add(p.publisherId);
      final members =
          await _db.query<PublisherMember>(ancestorKey: p.key).run().toList();
      if (p.isAbandoned) {
        _publishersAbandoned.add(p.publisherId);
        if (members.isNotEmpty) {
          _problems.add('Publisher(${p.publisherId}) is marked as abandoned, '
              'but has members (first: ${members.first.userId}).');
        }
        if (members.isEmpty && p.contactEmail != null) {
          _problems.add(
              'Publisher(${p.publisherId}) is marked as abandoned, has no members, '
              'but still has contact email (${p.contactEmail}).');
        }
      } else {
        if (members.isEmpty) {
          _problems.add(
              'Publisher(${p.publisherId}) is not marked as abandoned, but has no members.');
        }
      }
    }
  }

  Future<void> _checkPublisherMembers() async {
    _logger.info('Scanning PublisherMembers...');
    await for (final pm in _db.query<PublisherMember>().run()) {
      if (pm.id != pm.userId) {
        _problems.add(
            'PublisherMember(${pm.id}) has bad userId value: ${pm.userId}.');
      }
      if (!_publishers.contains(pm.publisherId)) {
        _problems.add(
            'PublisherMember(${pm.userId}) references a non-existing publisher: ${pm.publisherId}.');
      }
      if (_deletedUsers.contains(pm.userId)) {
        _problems.add(
            'PublisherMember(${pm.publisherId} / ${pm.userId}) references a deleted User.');
      }
      if (!_userToOauth.containsKey(pm.userId)) {
        _problems.add(
            'PublisherMember(${pm.publisherId} / ${pm.userId}) references a non-existing User.');
      }
    }
  }

  Future<void> _checkPackages() async {
    _logger.info('Scanning Packages...');
    final pool = Pool(_concurrency);
    final futures = <Future>[];
    await for (Package p in _db.query<Package>().run()) {
      final f = pool.withResource(() => _checkPackage(p));
      futures.add(f);
    }
    await Future.wait(futures);
    await pool.close();

    for (final r in _packageReplacedBys.entries) {
      if (!_packages.contains(r.value)) {
        _problems.add(
            'Package(${r.key}) has a `replacedBy` property with missing package ("${r.value}").');
      }
    }
  }

  Future<void> _checkPackage(Package p) async {
    _packages.add(p.name);
    if (p.replacedBy != null) {
      _packageReplacedBys[p.name] = p.replacedBy;

      if (!p.isDiscontinued) {
        _problems.add(
            'Package(${p.name}) has a `replacedBy` property without being `isDiscontinued`.');
      }
    }
    // empty uploaders
    if (p.uploaders == null || p.uploaders.isEmpty) {
      // no publisher
      if (p.publisherId == null && !p.isDiscontinued) {
        _problems.add(
            'Package(${p.name}) has no uploaders, must be marked discontinued.');
      }

      if (p.publisherId != null &&
          _publishersAbandoned.contains(p.publisherId) &&
          !p.isDiscontinued) {
        _problems.add(
            'Package(${p.name}) has an anandoned publisher, must be marked discontinued.');
      }
    }
    if (p.assignedTags == null || p.assignedTags is! List<String>) {
      _problems.add(
          'Package(${p.name}) has an `assignedTags` property which is not a list.');
    }
    final assignedTags = p.assignedTags ?? <String>[];
    for (final tag in assignedTags) {
      if (!allowedTagPrefixes.any(tag.startsWith)) {
        _problems.add(
            'Package(${p.name}) have assigned tag `$tag` in `assignedTags` '
            'property, which is not allowed.');
      }
    }
    if (assignedTags.length != assignedTags.toSet().length) {
      _problems.add(
          'Package(${p.name}) has an `assignedTags` property which contains duplicates.');
    }
    if (p.likes == null || p.likes is! int || p.likes < 0) {
      _problems.add(
          'Package(${p.name}) has a `likes` property which is not a non-negative integer.');
    }
    if (p.isDiscontinued == null || p.isDiscontinued is! bool) {
      _problems.add(
          'Package(${p.name}) has a `isDiscontinued` property which is not a bool.');
    }
    if (p.isUnlisted == null || p.isUnlisted is! bool) {
      _problems.add(
          'Package(${p.name}) has a `isUnlisted` property which is not a bool.');
    }
    if (p.isWithheld == null || p.isWithheld is! bool) {
      _problems.add(
          'Package(${p.name}) has a `isWithheld` property which is not a bool.');
    }
    for (String userId in p.uploaders) {
      if (!_userToOauth.containsKey(userId)) {
        _problems.add('Package(${p.name}) has uploader without User: $userId');
      }
      if (_invalidUsers.contains(userId)) {
        _problems.add('Package(${p.name}) has invalid uploader: User($userId)');
      }
    }
    final versionKeys = <Key>{};
    final qualifiedVersionKeys = <QualifiedVersionKey>{};
    await for (PackageVersion pv
        in _db.query<PackageVersion>(ancestorKey: p.key).run()) {
      versionKeys.add(pv.key);
      qualifiedVersionKeys.add(pv.qualifiedVersionKey);
      if (pv.uploader == null) {
        _problems.add(
            'PackageVersion(${pv.package} ${pv.version}) has no uploader.');
      }
      if (!_userToOauth.containsKey(pv.uploader)) {
        _problems.add(
            'PackageVersion(${pv.package} ${pv.version}) has uploader without User: ${pv.uploader}');
      }
      if (_invalidUsers.contains(pv.uploader)) {
        _problems.add(
            'PackageVersion(${pv.package} ${pv.version}) has invalid uploader: User(${pv.uploader})');
      }
    }
    if (p.lastVersionPublished == null) {
      _problems.add(
          'Package(${p.name}) has a `lastVersionPublished` property which is null.');
    }
    if (p.latestVersionKey == null) {
      _problems.add(
          'Package(${p.name}) has a `latestVersionKey` property which is null.');
    } else if (!versionKeys.contains(p.latestVersionKey)) {
      _problems.add(
          'Package(${p.name}) has missing latestVersionKey: ${p.latestVersionKey.id}');
    }
    if (p.latestPrereleaseVersionKey == null) {
      _problems.add(
          'Package(${p.name}) has a `latestPrereleaseVersionKey` property which is null.');
    } else if (!versionKeys.contains(p.latestPrereleaseVersionKey)) {
      _problems.add(
          'Package(${p.name}) has missing latestPrereleaseVersionKey: ${p.latestPrereleaseVersionKey.id}');
    }

    // Checking if PackageVersionInfo is referenced by a PackageVersion entity.
    final pviQuery = _db.query<PackageVersionInfo>()
      ..filter('package =', p.name);
    final pviKeys = <QualifiedVersionKey>{};
    final referencedAssetIds = <String>[];
    await for (PackageVersionInfo pvi in pviQuery.run()) {
      final key = pvi.qualifiedVersionKey;
      pviKeys.add(key);
      if (!qualifiedVersionKeys.contains(key)) {
        _problems.add('PackageVersionInfo($key) has no PackageVersion.');
      }
      if (pvi.versionCreated == null) {
        _problems.add(
            'PackageVersionInfo($key) has a `versionCreated` property which is null.');
      }
      if (pvi.updated == null) {
        _problems.add(
            'PackageVersionInfo($key) has a `updated` property which is null.');
      }
      if (pvi.libraryCount == null) {
        _problems.add(
            'PackageVersionInfo($key) has a `libraryCount` property which is null.');
      }
      if (pvi.assets != null) {
        for (final kind in pvi.assets) {
          referencedAssetIds.add(key.assetId(kind));
        }
      }
    }
    for (QualifiedVersionKey key in qualifiedVersionKeys) {
      if (!pviKeys.contains(key)) {
        _problems.add('PackageVersion($key) has no PackageVersionInfo.');
      }
    }

    // Checking if PackageVersionAsset is referenced by a PackageVersion entity.
    final pvaQuery = _db.query<PackageVersionAsset>()
      ..filter('package =', p.name);
    final foundAssetIds = <String>{};
    await for (PackageVersionAsset pva in pvaQuery.run()) {
      final key = pva.qualifiedVersionKey;
      if (pva.id !=
          Uri(pathSegments: [pva.package, pva.version, pva.kind]).path) {
        _problems.add('PackageVersionAsset(${pva.id}) uses old id format.');
        continue;
      }
      if (!qualifiedVersionKeys.contains(key)) {
        _problems.add('PackageVersionAsset(${pva.id}) has no PackageVersion.');
      }
      foundAssetIds.add(pva.assetId);
      // check if PackageVersionAsset is referenced in PackageVersionInfo
      if (!referencedAssetIds.contains(pva.assetId)) {
        _problems.add(
            'PackageVersionAsset(${pva.id}) is not referenced from PackageVersionInfo.');
      }
    }

    // check if all of PackageVersionInfo.assets exist
    for (final id in referencedAssetIds) {
      if (!foundAssetIds.contains(id)) {
        _problems.add(
            'PackageVersionAsset($id) is referenced from PackageVersionInfo but does not exist.');
      }
    }

    _packageChecked++;
    if (_packageChecked % 200 == 0) {
      _logger.info('  .. $_packageChecked done (${p.name})');
    }
  }

  Future<void> _checkVersions() async {
    _logger.info('Scanning PackageVersions...');
    await for (PackageVersion pv in _db.query<PackageVersion>().run()) {
      _checkPackageVersion(pv);
    }

    _packages
        .where((package) => !_packagesWithVersion.contains(package))
        .forEach((package) {
      _problems.add('Package ($package) has no version.');
    });
    _packagesWithVersion
        .where((package) => !_packages.contains(package))
        .forEach((package) {
      _problems.add('Package ($package) is missing.');
    });
  }

  void _checkPackageVersion(PackageVersion pv) {
    _packagesWithVersion.add(pv.package);

    if (pv.uploader == null) {
      _problems
          .add('PackageVersion(${pv.qualifiedVersionKey}) has no uploader.');
    }

    // Sanity checks for the `created` property
    if (pv.created == null) {
      _problems.add(
          'PackageVersion(${pv.qualifiedVersionKey}) has no `created` property.');
    } else if (pv.created.isAfter(DateTime.now().add(Duration(minutes: 15)))) {
      // Can't be published in the future (+15 min to allow for clock drift)
      _problems.add(
          'PackageVersion(${pv.qualifiedVersionKey}) has `created` > now().');
    } else if (pv.created.isBefore(DateTime(2011))) {
      // Can't be published before Dart was published in 2011
      _problems.add(
          'PackageVersion(${pv.qualifiedVersionKey}) has `created` < 2011.');
    }

    _versionChecked++;
    if (_versionChecked % 5000 == 0) {
      _logger.info('  .. $_versionChecked done (${pv.qualifiedVersionKey})');
    }
  }

  Future<void> _checkLikes() async {
    _logger.info('Scanning Likes...');

    await for (Like like in _db.query<Like>().run()) {
      if (like.packageName == null) {
        _problems.add(
            'Like entity for user ${like.userId} and ${like.package} has a '
            '`packageName` property which is not at string ');
      } else if (like.packageName != like.package) {
        _problems.add('Like entity for user ${like.userId} and ${like.package}'
            ' has a `packageName` property which is not the same as `package`/id');
      }

      _userToLikes.update(like.userId, (l) => l..add(like.package),
          ifAbsent: () => <String>[]);
    }

    _userToLikes.keys
        .where((user) =>
            (!_userToOauth.keys.contains(user) || _deletedUsers.contains(user)))
        .forEach((user) {
      _problems.add('Like entity with nonexisting or deleted user $user');
    });

    _userToLikes.keys.forEach((user) {
      _userToLikes[user]
          .where((String package) => !_packages.contains(package))
          .forEach((package) {
        _problems.add('User $user likes missing package $package');
      });
    });
  }

  Future<void> _checkModeratedPackages() async {
    _logger.info('Scanning ModeratedPackages...');

    await for (ModeratedPackage pkg in _db.query<ModeratedPackage>().run()) {
      _moderatedPackages.add(pkg.name);
    }

    _moderatedPackages
        .where((package) => _packages.contains(package))
        .forEach((pkg) {
      _problems.add('Moderated package:$pkg also present in active packages');
    });
  }
}

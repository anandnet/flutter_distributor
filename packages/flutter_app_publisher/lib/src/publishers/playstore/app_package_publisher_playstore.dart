import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_publisher/src/api/app_package_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/playstore/publish_playstore_config.dart';
import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis_auth/auth_io.dart';

class AppPackagePublisherPlayStore extends AppPackagePublisher {
  @override
  String get name => 'playstore';

  @override
  List<String> get supportedPlatforms => ['android'];

  @override
  Future<PublishResult> publish(
    FileSystemEntity fileSystemEntity, {
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
    PublishProgressCallback? onPublishProgress,
  }) async {
    File file = fileSystemEntity as File;
    PublishPlayStoreConfig publishConfig = PublishPlayStoreConfig.parse(
      environment,
      publishArguments,
    );

    String jsonString = File(publishConfig.credentialsFile).readAsStringSync();
    ServiceAccountCredentials serviceAccountCredentials =
        ServiceAccountCredentials.fromJson(json.decode(jsonString));

    final client = await clientViaServiceAccount(
      serviceAccountCredentials,
      [
        AndroidPublisherApi.androidpublisherScope,
      ],
    );

    final AndroidPublisherApi publisherApi = AndroidPublisherApi(client);

    AppEdit appEdit = await publisherApi.edits.insert(
      AppEdit(),
      publishConfig.packageName,
    );
    Media uploadMedia = Media(file.openRead(), file.lengthSync());

    await publisherApi.edits.bundles.upload(
      publishConfig.packageName,
      appEdit.id!,
      uploadMedia: uploadMedia,
    );

    if (publishConfig.track != null) {
      //must update track before edit commit.
      await publisherApi.edits.tracks.update(
        Track(track: publishConfig.track),
        publishConfig.packageName,
        appEdit.id!,
        publishConfig.track!,
      );
    }

    await publisherApi.edits.commit(
      publishConfig.packageName,
      appEdit.id!,
    );

    return PublishResult(
      url: '',
    );
  }
}

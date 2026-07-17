import '../core/algorithm_registry.dart';
import '../core/profile.dart';

// The order is part of keyboard navigation and the visual progress rail.
enum WizardStep {
  language,
  source,
  details,
  algorithms,
  exclusions,
  output,
  review,
}

class WizardDraft {
  WizardDraft({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  String? locale;
  SourceType? sourceType;
  String profileName = '';
  String profileId = '';
  String root = '';
  String host = '';
  String user = '';
  String port = '22';
  String identityFile = '';
  SshAuthMethod sshAuthMethod = SshAuthMethod.password;
  SshHostKeyPolicy sshHostKeyPolicy = SshHostKeyPolicy.trustOnFirstUse;
  String hostKeyType = '';
  String hostKeyFingerprint = '';
  int connectTimeoutSeconds = 15;
  int keepAliveSeconds = 10;
  String container = '';
  String image = '';
  String service = '';
  String composeFile = '';
  String dockerContext = '';
  String projectKind = 'generic';
  final Set<String> algorithmIds = <String>{};
  final List<CustomHashAlgorithm> customAlgorithms = <CustomHashAlgorithm>[];
  final Set<String> excludePatterns = <String>{};
  bool canonicalJson = false;
  bool compatibilityText = false;
  bool zipPackage = false;
  bool metadataReport = false;
  bool requireZipPassword = true;
  String outputDirectory = '';
  SymlinkPolicy symlinkPolicy = SymlinkPolicy.skip;
  bool includeHiddenFiles = true;
  bool capturePermissions = true;
  bool captureModificationTimes = true;
  bool failOnReadError = true;
  int workerCount = 4;

  List<String> validateStep(WizardStep step) {
    switch (step) {
      case WizardStep.language:
        return locale == null
            ? <String>['Select a language.']
            : const <String>[];
      case WizardStep.source:
        return sourceType == null
            ? <String>['Select a source.']
            : const <String>[];
      case WizardStep.details:
        return _sourceConfig().validate()
          ..addAll(profileName.trim().isEmpty
              ? <String>['Profile name is required.']
              : const <String>[])
          ..addAll(RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(profileId)
              ? const <String>[]
              : <String>['Profile ID is invalid.']);
      case WizardStep.algorithms:
        return algorithmIds.isEmpty
            ? <String>['Select at least one algorithm.']
            : const <String>[];
      case WizardStep.exclusions:
        return excludePatterns.any((pattern) => pattern.trim().isEmpty)
            ? <String>['Empty exclusion patterns are not allowed.']
            : const <String>[];
      case WizardStep.output:
        final output = _outputConfig();
        return output.validate();
      case WizardStep.review:
        try {
          return toProfile().validate();
        } on FormatException catch (error) {
          return <String>[error.message];
        }
    }
  }

  bool canContinue(WizardStep step) => validateStep(step).isEmpty;

  CentraProfile toProfile() {
    if (locale == null || sourceType == null) {
      throw const FormatException('Language and source are required.');
    }
    final now = _clock().toUtc();
    return CentraProfile(
      id: profileId,
      name: profileName.trim(),
      locale: locale!,
      source: _sourceConfig(),
      algorithmIds: algorithmIds.toList(growable: false),
      includePatterns: const <String>['**'],
      excludePatterns: excludePatterns.toList(growable: false)..sort(),
      customAlgorithms:
          List<CustomHashAlgorithm>.unmodifiable(customAlgorithms),
      symlinkPolicy: symlinkPolicy,
      includeHiddenFiles: includeHiddenFiles,
      capturePermissions: capturePermissions,
      captureModificationTimes: captureModificationTimes,
      workerCount: workerCount,
      failOnReadError: failOnReadError,
      output: _outputConfig(),
      projectKind: projectKind,
      createdAt: now,
      updatedAt: now,
    );
  }

  SourceConfig _sourceConfig() => SourceConfig(
        type: sourceType ?? SourceType.local,
        root: root.trim(),
        host: host.trim().isEmpty ? null : host.trim(),
        user: user.trim().isEmpty ? null : user.trim(),
        port: int.tryParse(port) ?? 0,
        identityFile: identityFile.trim().isEmpty ? null : identityFile.trim(),
        sshAuthMethod: sshAuthMethod,
        sshHostKeyPolicy: sshHostKeyPolicy,
        hostKeyType: hostKeyType.trim().isEmpty ? null : hostKeyType.trim(),
        hostKeyFingerprint: hostKeyFingerprint.trim().isEmpty
            ? null
            : hostKeyFingerprint.trim(),
        connectTimeoutSeconds: connectTimeoutSeconds,
        keepAliveSeconds: keepAliveSeconds,
        container: container.trim().isEmpty ? null : container.trim(),
        image: image.trim().isEmpty ? null : image.trim(),
        service: service.trim().isEmpty ? null : service.trim(),
        composeFile: composeFile.trim().isEmpty ? null : composeFile.trim(),
        dockerContext:
            dockerContext.trim().isEmpty ? null : dockerContext.trim(),
      );

  OutputConfig _outputConfig() => OutputConfig(
        directory: outputDirectory.trim(),
        writeCanonicalJson: canonicalJson,
        writeCompatibilityText: compatibilityText,
        createZip: zipPackage,
        requireZipPassword: zipPackage && requireZipPassword,
        includeMetadataReport: metadataReport,
      );
}

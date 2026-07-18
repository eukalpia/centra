import 'package:cinder/cinder.dart';

import '../core/docker_browser.dart';
import '../core/profile.dart';
import '../core/profile_editor.dart';
import '../core/ssh_connection.dart';
import 'docker_source_picker.dart';
import 'folder_picker.dart';
import 'ssh_connection_library.dart';

class SourceChangePanel extends StatelessWidget {
  const SourceChangePanel({
    super.key,
    required this.profile,
    required this.locale,
    required this.onSelected,
    required this.onCancel,
  });

  final CentraProfile profile;
  final String locale;
  final ValueChanged<(CentraProfile, SshConnectionSecrets?)> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => switch (profile.source.type) {
        SourceType.local => FolderPicker(
            initialPath: profile.source.root,
            locale: locale,
            onSelected: (path) => onSelected((
              updateProfile(
                profile,
                source: updateSourceConfig(profile.source, root: path),
              ),
              null,
            )),
            onCancel: onCancel,
          ),
        SourceType.ssh => SshConnectionLibrary(
            locale: locale,
            initialHost: profile.source.host ?? '',
            initialPort: profile.source.port,
            initialUser: profile.source.user ?? '',
            initialPath: profile.source.root,
            initialAuthMethod: profile.source.sshAuthMethod,
            initialIdentityFile: profile.source.identityFile,
            initialFingerprint: profile.source.hostKeyFingerprint,
            initialConnectTimeoutSeconds:
                profile.source.connectTimeoutSeconds,
            initialKeepAliveSeconds: profile.source.keepAliveSeconds,
            onSelected: (selection) => onSelected((
              updateProfile(
                profile,
                source: SourceConfig(
                  type: SourceType.ssh,
                  root: selection.path,
                  host: selection.host,
                  user: selection.user,
                  port: selection.port,
                  identityFile: selection.identityFile,
                  sshAuthMethod: selection.authMethod,
                  sshHostKeyPolicy: SshHostKeyPolicy.pinned,
                  hostKeyType: selection.hostKeyType,
                  hostKeyFingerprint: selection.hostKeyFingerprint,
                  connectTimeoutSeconds: selection.connectTimeoutSeconds,
                  keepAliveSeconds: selection.keepAliveSeconds,
                  sshConnectionId: selection.connectionId,
                  sshConnectionName: selection.connectionName,
                ),
              ),
              selection.secrets,
            )),
            onCancel: onCancel,
          ),
        SourceType.dockerContainer ||
        SourceType.dockerImage ||
        SourceType.dockerCompose =>
          DockerSourcePicker(
            sourceType: profile.source.type,
            locale: locale,
            dockerContext: profile.source.dockerContext,
            composeFile: profile.source.composeFile,
            initialResource: _dockerResource(profile.source),
            initialPath: profile.source.root,
            onSelected: (selection) => onSelected((
              updateProfile(
                profile,
                source: SourceConfig(
                  type: profile.source.type,
                  root: selection.path,
                  container: profile.source.type == SourceType.dockerContainer
                      ? selection.resource.reference
                      : null,
                  image: profile.source.type == SourceType.dockerImage
                      ? selection.resource.reference
                      : null,
                  service: profile.source.type == SourceType.dockerCompose
                      ? selection.resource.reference
                      : null,
                  composeFile: profile.source.composeFile,
                  dockerContext: profile.source.dockerContext,
                ),
              ),
              null,
            )),
            onCancel: onCancel,
          ),
      };

  String? _dockerResource(SourceConfig source) => switch (source.type) {
        SourceType.dockerContainer => source.container,
        SourceType.dockerImage => source.image,
        SourceType.dockerCompose => source.service,
        _ => null,
      };
}

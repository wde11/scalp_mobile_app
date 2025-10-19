//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

<<<<<<< Updated upstream
import file_selector_macos
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
=======
import firebase_auth
import firebase_core
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FLTFirebaseAuthPlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseAuthPlugin"))
  FLTFirebaseCorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseCorePlugin"))
>>>>>>> Stashed changes
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}

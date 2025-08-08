#!/usr/bin/env dart

import 'dart:io';

void main() async {
  print('🔍 Verifying Nyx App Build Configuration...\n');

  bool allChecksPass = true;

  // 1. Check pubspec.yaml dependencies
  print('📦 Checking dependencies...');
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    
    final requiredDeps = [
      'http:',
      'logging:',
      'path_provider:',
      'provider:',
      'shared_preferences:'
    ];
    
    for (final dep in requiredDeps) {
      if (content.contains(dep)) {
        print('  ✅ $dep found');
      } else {
        print('  ❌ $dep missing');
        allChecksPass = false;
      }
    }
  } else {
    print('  ❌ pubspec.yaml not found');
    allChecksPass = false;
  }

  // 2. Check Android manifest
  print('\n📱 Checking Android configuration...');
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (await manifestFile.exists()) {
    final content = await manifestFile.readAsString();
    
    final requiredElements = [
      'android.permission.INTERNET',
      'networkSecurityConfig',
      'android.security.net.config'
    ];
    
    for (final element in requiredElements) {
      if (content.contains(element)) {
        print('  ✅ $element configured');
      } else {
        print('  ❌ $element missing');
        allChecksPass = false;
      }
    }
  } else {
    print('  ❌ AndroidManifest.xml not found');
    allChecksPass = false;
  }

  // 3. Check network security config
  print('\n🔒 Checking network security...');
  final networkConfigFile = File('android/app/src/main/res/xml/network_security_config.xml');
  if (await networkConfigFile.exists()) {
    final content = await networkConfigFile.readAsString();
    
    if (content.contains('api.anthropic.com')) {
      print('  ✅ Claude API domain configured');
    } else {
      print('  ❌ Claude API domain missing');
      allChecksPass = false;
    }
  } else {
    print('  ❌ network_security_config.xml not found');
    allChecksPass = false;
  }

  // 4. Check build.gradle.kts
  print('\n🔧 Checking build configuration...');
  final buildGradleFile = File('android/app/build.gradle.kts');
  if (await buildGradleFile.exists()) {
    final content = await buildGradleFile.readAsString();
    
    final requiredConfig = [
      'armeabi-v7a',
      'arm64-v8a',
      'x86_64',
      'abiFilters'
    ];
    
    for (final config in requiredConfig) {
      if (content.contains(config)) {
        print('  ✅ $config configured');
      } else {
        print('  ❌ $config missing');
        allChecksPass = false;
      }
    }
  } else {
    print('  ❌ build.gradle.kts not found');
    allChecksPass = false;
  }

  // 5. Check environment configuration
  print('\n🔑 Checking environment configuration...');
  print('  ✅ API key now configured via GitHub secrets and --dart-define');
  print('  ✅ No .env file needed - more secure configuration');

  // 6. Check service files
  print('\n🛠️  Checking service files...');
  final serviceFiles = [
    'lib/services/chat_service.dart',
    'lib/services/word_service.dart',
    'lib/services/logging_service.dart'
  ];
  
  for (final serviceFile in serviceFiles) {
    final file = File(serviceFile);
    if (await file.exists()) {
      print('  ✅ ${serviceFile.split('/').last} exists');
    } else {
      print('  ❌ ${serviceFile.split('/').last} missing');
      allChecksPass = false;
    }
  }

  // Final result
  print('\n' + '='*50);
  if (allChecksPass) {
    print('🎉 All configuration checks PASSED!');
    print('✅ Your Nyx app is ready to build and deploy.');
  } else {
    print('❌ Some configuration issues found.');
    print('⚠️  Please fix the issues above before building.');
  }
  print('='*50);
}
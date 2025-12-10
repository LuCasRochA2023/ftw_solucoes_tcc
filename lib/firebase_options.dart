import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux is not supported yet.',
        );
      default:
        throw UnsupportedError(
          'Unknown platform $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIR6uPgC_kq_0CHLonol_RvWrDoUqMibQ',
    appId: '1:578219383620:web:5c7b07e5eb53dbf9021511',
    messagingSenderId: '578219383620',
    projectId: 'ftw-solucoes',
    authDomain: 'ftw-solucoes.firebaseapp.com',
    databaseURL: 'https://ftw-solucoes-default-rtdb.firebaseio.com',
    storageBucket: 'ftw-solucoes.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBtPiwQ3Oob7tydv5p9SM8ztJZfBXAQ7B0',
    appId: '1:578219383620:android:0b8fe7a568684cbd021511',
    messagingSenderId: '578219383620',
    projectId: 'ftw-solucoes',
    databaseURL: 'https://ftw-solucoes-default-rtdb.firebaseio.com',
    storageBucket: 'ftw-solucoes.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCL5up8hkdlFmcnKpXk6gnYg7Em4hDy9FA',
    appId: '1:578219383620:ios:f946fd727bd51a87021511',
    messagingSenderId: '578219383620',
    projectId: 'ftw-solucoes',
    databaseURL: 'https://ftw-solucoes-default-rtdb.firebaseio.com',
    storageBucket: 'ftw-solucoes.firebasestorage.app',
    iosBundleId: 'com.example.ftwSolucoes',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCL5up8hkdlFmcnKpXk6gnYg7Em4hDy9FA',
    appId: '1:578219383620:ios:f946fd727bd51a87021511',
    messagingSenderId: '578219383620',
    projectId: 'ftw-solucoes',
    databaseURL: 'https://ftw-solucoes-default-rtdb.firebaseio.com',
    storageBucket: 'ftw-solucoes.firebasestorage.app',
    iosBundleId: 'com.example.ftwSolucoes',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIR6uPgC_kq_0CHLonol_RvWrDoUqMibQ',
    appId: '1:578219383620:web:b1a96d92fb858e72021511',
    messagingSenderId: '578219383620',
    projectId: 'ftw-solucoes',
    authDomain: 'ftw-solucoes.firebaseapp.com',
    databaseURL: 'https://ftw-solucoes-default-rtdb.firebaseio.com',
    storageBucket: 'ftw-solucoes.firebasestorage.app',
  );
}

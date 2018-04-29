Whisper Browser on iOS
===========================

Whisper Browser is an application to demonstrate how to use Whisper portofrwarding over whisper netowrk. It show you can Apps on Android/iOS to access Http services inside NAT.

## Whisper network types

Two types of whisper network would be supprted:

- Managed whisper network
- Decentralzied whisper network

## Build from source

You should get source code from the following repository on github.com:

```
https://github.com/stiartsly/WhisperBrowser-iOS.git
```
Then open this xcode project with Apple xcode to build it.

## Build dependencies

Before buiding whisper demo, you have to download and build the following dependencies:

- ManagedWhisper.framework (vanilla)
- Bugly
- QRCode

As to whisper ios sdk, you need to get source from

```
https://github.com/stiartsly/whisper-ios.git
```
and after building, copy (or replace) it's ditributions 'ManagedWhisper' to top directory of project.

## Deploy && Run

Run on Phone or Simulator with iOS version 9.0 or higher.

## License

Whisper Browser project source code files are made available under the MIT License.
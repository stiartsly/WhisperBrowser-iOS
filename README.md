Whisper Browser Run on iOS
======================

Whisper Browser is an exemplary app to demonstrate how to use whisper portofrwarding over whisper network. It shows that you can conduct this app to access or browse http service behind the router.

## Whisper network types

Two types of whisper network would be supported:

- Managed whisper network (or centralized whisper network)
- Decentralized whisper network

## Build from source

Get source code from github.com with following repository:

```
https://github.com/stiartsly/WhisperBrowser-iOS.git
```
Then open this project with Apple Xcode to build distribution.

## Build dependencies

Before building whisper browser, you have to download and build the following dependencies:

- ManagedWhisper.framework (currently for vanilla)
- Bugly
- QRCode

As to **ManagedWhisper.framework**, you need to get source from

```
https://github.com/stiartsly/whisper-ios.git
```

and build it, then copy (or replace) it's ditribution **ManagedWhisper** to top directory of project.

## Deployment && Run

Run on iOS Phone or Simulator with iOS version **9.0 or higher**.

## License

MIT

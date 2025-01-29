# sayu

`sayu` is a fast and easy to use text-to-speech engine with multiple backends. It currently supports
`piper-tts` models via onnx and plans to support kokoro and concatenative speech synthesis, similar to
MBROLA but with modern features.

# install

```sh
zig build -Doptimize=ReleaseFast
./zig-out/bin/sayu --help
```

Download Zig from here:

[nominated-zig](https://machengine.org/docs/nominated-zig)

sayu uses Zig nominated Mach version `0.14.0-dev.2577+271452d22` which is a pseudo-stable release.

```sh
# linux
wget https://pkg.machengine.org/zig/zig-linux-x86_64-0.14.0-dev.2577+271452d22.tar.xz
# windows
wget.exe https://pkg.machengine.org/zig/zig-windows-x86_64-0.14.0-dev.2577+271452d22.zip
# mac arm
wget https://pkg.machengine.org/zig/zig-macos-aarch64-0.14.0-dev.2577+271452d22.tar.xz
```

Run a naive TTS server:

```sh
sayu serve
curl --http0.9 localhost:8080 --data '{"text": "Hello world, how are you doing?"}' --output - | aplay -r 22050 -c 1 -f S16_LE -t raw
```

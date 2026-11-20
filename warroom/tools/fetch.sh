#!/bin/sh
# Downloads the pinned Tailwind CLI and daisyUI into warroom/.bin/ and checks each file's SHA-256.
set -eu

TAILWIND=v4.3.4
DAISY=v5.7.50

case "$(uname -s)-$(uname -m)" in
Darwin-arm64) TW_FILE=tailwindcss-macos-arm64 TW_SHA=a516a11b439bfbb5ecd4a2d13b75e6cdcc284dc710aed8731e31d2e5c03895a4 ;;
Linux-x86_64) TW_FILE=tailwindcss-linux-x64 TW_SHA=149a8ece5b855587a9c10de6da9dcbcfad0e47c4ed5dca219f721b3eae39d817 ;;
Linux-aarch64 | Linux-arm64) TW_FILE=tailwindcss-linux-arm64 TW_SHA=f6d7baae1d350ed3a2defe98d0b5cc58e37400c0173b2e38d42f690ccc4bbfe1 ;;
*)
	echo "fetch.sh: no pinned Tailwind CLI for $(uname -s)-$(uname -m)" >&2
	exit 1
	;;
esac

DAISY_SHA=d69de07c7463bb1f41548e2688f88ee105cdadf9779fce5b3c47b3bfaa6be472
DAISY_THEME_SHA=e48a35d8326d650181ca600560e8520cf6b44cf9242bbd9d45825607e641f251

cd "$(dirname "$0")/.."
mkdir -p .bin

# fetch URL DEST SHA256: skips a file that is already there and matches.
fetch() {
	url=$1 dest=$2 want=$3
	if [ -f "$dest" ] && [ "$(shasum -a 256 "$dest" | cut -d' ' -f1)" = "$want" ]; then
		return 0
	fi
	curl -fsSL "$url" -o "$dest.part"
	got=$(shasum -a 256 "$dest.part" | cut -d' ' -f1)
	if [ "$got" != "$want" ]; then
		rm -f "$dest.part"
		echo "fetch.sh: $url has SHA-256 $got, expected $want" >&2
		exit 1
	fi
	mv "$dest.part" "$dest"
}

fetch "https://github.com/tailwindlabs/tailwindcss/releases/download/$TAILWIND/$TW_FILE" .bin/tailwindcss "$TW_SHA"
chmod +x .bin/tailwindcss
fetch "https://github.com/saadeghi/daisyui/releases/download/$DAISY/daisyui.mjs" .bin/daisyui.mjs "$DAISY_SHA"
fetch "https://github.com/saadeghi/daisyui/releases/download/$DAISY/daisyui-theme.mjs" .bin/daisyui-theme.mjs "$DAISY_THEME_SHA"

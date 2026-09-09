# lidcam

Captures a webcam photo and sends it to Telegram when the laptop wakes from
suspend (lid open). Anti-theft / "who opened my laptop" feature.

## Setup
1. On Telegram, talk to **@BotFather**, create a bot, copy its token.
2. Send any message to your new bot so it can reply to you.
3. Open `https://api.telegram.org/bot<TOKEN>/getUpdates` and copy the numeric
   `chat.id`.
4. Put both into `config` (BOT_TOKEN, CHAT_ID).
5. Test: `./lidcam.sh` — you should get a photo in Telegram.

## Trigger
Installed as a systemd system-sleep hook at
`/usr/lib/systemd/system-sleep/lidcam` which runs `lidcam.sh` on resume.

## Log
See `lidcam.log` in this directory.

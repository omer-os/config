function konto --description "Run the Konto app (desktop w/ hot reload by default)"
    set -l repo ~/projects/konto
    switch "$argv[1]"
        case android
            $repo/gradlew -p $repo :androidApp:assembleDebug
            and adb install -r $repo/androidApp/build/outputs/apk/debug/androidApp-debug.apk
        case cold
            # Plain cold start — use after schema/DI/build-script changes,
            # which hot reload cannot pick up.
            $repo/gradlew -p $repo :composeApp:run
        case '*'
            # Compose Hot Reload: `--auto` recompiles and re-applies the running
            # app on every file save, so edits show up without a restart.
            $repo/gradlew -p $repo :composeApp:hotRunJvm --auto $argv
    end
end

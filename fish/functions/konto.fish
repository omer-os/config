function konto --description "Run the Konto app (desktop by default)"
    set -l repo ~/projects/konto
    switch "$argv[1]"
        case android
            $repo/gradlew -p $repo :androidApp:assembleDebug
            and adb install -r $repo/androidApp/build/outputs/apk/debug/androidApp-debug.apk
        case '*'
            $repo/gradlew -p $repo :composeApp:run
    end
end

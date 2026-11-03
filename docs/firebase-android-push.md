# Firebase Cloud Messaging for Android

Firebase is optional for development. The app catches missing Firebase configuration and continues without push registration; no `google-services.json` is required to compile the unconfigured app.

## Firebase Console setup

1. Create/select the Firebase project that will also be used by the backend Firebase Admin SDK.
2. Enable Firebase Cloud Messaging for the project.
3. Add an Android app with package name `com.cooperativa.app.si2_mobile_app`.
4. Download the generated `google-services.json` and supply it locally/through the Android build secret mechanism at `android/app/google-services.json`. Do not commit it; it is ignored by this repository.
5. Build/run the Android app. The Google Services Gradle plugin is conditionally applied when the JSON file is present. No iOS setup is part of this app integration.

No Firebase private key belongs in the mobile project. The backend must use credentials for the same Firebase project; see `SI2_backend_api/docs/credit-push-notifications.md` for server setup and the scheduled job.

Android 13 and later show the runtime notification permission request. The app creates the `credit_reminders` channel with the system default sound and vibration; users' Android notification/channel settings remain authoritative. Foreground FCM messages update the existing in-app notification tray and display a local Android notification. Background/terminated notifications are displayed by FCM and open the relevant credit schedule when tapped.

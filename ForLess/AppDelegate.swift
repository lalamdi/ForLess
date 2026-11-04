//
//  AppDelegate.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Starts Firebase when the app launches and passes app events
//  (push notifications, links) to Firebase phone sign-in.
//  Firebase phone sign-in needs this in SwiftUI apps.
//

import UIKit
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {

    /// Runs once when the app opens: connects the app to the Firebase project.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }

    /// Gives Firebase the device's push token (used to verify the phone silently).
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    /// Passes Firebase's own notifications to Firebase Auth.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }

    /// Passes links back to Firebase after a web check (reCAPTCHA).
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Auth.auth().canHandle(url)
    }
}

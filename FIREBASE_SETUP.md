# Firebase Setup Guide

The app code is complete. You need to do 3 things in Xcode and the Firebase console before it will build.

---

## 1. Add New Source Files to the Xcode Project

The new Swift files (Models, Services, ViewModels, Views, Utilities) live on disk but aren't in the Xcode project yet.

1. Open `Pera.xcodeproj` in Xcode
2. In the Project Navigator, right-click the **Pera** folder → **Add Files to "Pera"...**
3. Select all five new folders: `Models`, `Services`, `ViewModels`, `Views`, `Utilities`
4. Make sure **"Add to target: Pera"** is checked and **"Create groups"** is selected
5. Click **Add**

You can also delete the CoreData model file from the project: right-click `Pera.xcdatamodeld` → **Delete** → **Move to Trash**

---

## 2. Add Firebase SDK via Swift Package Manager



1. In Xcode, go to **File → Add Package Dependencies**
2. Paste this URL: `https://github.com/firebase/firebase-ios-sdk`
3. Click **Add Package**
4. When prompted to choose products, select **only these three**:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFirestoreSwift`
5. Click **Add Package**

---

## 2. Add GoogleService-Info.plist

1. Go to [console.firebase.google.com](https://console.firebase.google.com) and create a project (or use an existing one)
2. Add an iOS app with bundle ID: **`com.griffin-network.Pera`**
3. Download `GoogleService-Info.plist`
4. Drag it into the **Pera/** folder in Xcode (make sure "Add to target: Pera" is checked)

---

## 3. Enable Firebase services in the console

### Authentication
- Firebase console → Authentication → Get Started
- Enable **Email/Password** sign-in method

### Firestore
- Firebase console → Firestore Database → Create Database
- Start in **test mode** for now (you can tighten rules later)
- Recommended security rules for production:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 4. Required Firestore Indexes

Firestore will prompt you to create composite indexes the first time queries run. Click the link in the Xcode console output and it will auto-create them. Alternatively, create these manually:

| Collection | Fields | Order |
|---|---|---|
| `transactions` | `date` ASC | Ascending |
| `categories` | `sortOrder` ASC | Ascending |
| `envelopes` | `month` ASC | Ascending |

---

## Done!

Build and run (`⌘R`). The app will show a splash screen while Firebase checks auth state, then route to login or the main dashboard.

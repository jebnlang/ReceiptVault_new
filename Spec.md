# Product Specification Document: ReceiptVault (iOS - Xcode)

## 1. Introduction

* **App Name:** ReceiptVault
* **Target Audience:** Hebrew-speaking freelancers in Israel.
* **App Goal:** To provide a user-friendly mobile application for organizing and managing receipts, automating data extraction, and simplifying expense tracking.
* **Technology Stack:** Swift (for native iOS development), Google Drive API, Google AI Gemini 2.0 Flash API.
* **Language:** Hebrew.
* **Phase:** Phase 1 (Core Functionality – Camera capture, Google Drive storage, OCR data extraction, Google Sheet log).
* **Development Environment:** Xcode

## 2. User Flow

1. **App Launch:** The user taps the ReceiptVault app icon on their iOS device.
2. **Main Screen:** The user is presented with a large, centrally positioned camera icon and the app name in Hebrew: "קופת קבלות."
3. **Camera Access:** The user taps the camera icon, granting the app permission to access the device's camera (using `AVFoundation`).
4. **Receipt Capture:** The user takes a picture of their receipt.
5. **Processing:** The app uploads the image to Google Drive, converts it to a PDF (using a PDFKit or similar), and uses Google AI to extract receipt data.
6. **Google Sheet Update:** The extracted data is added as a new row in the monthly Google Sheet log.
7. **Confirmation:** A brief, user-friendly confirmation message appears (e.g., "הקובץ נשמר בהצלחה!" - "File saved successfully!") using a `UIAlertController` or a custom view.
8. **Return to Main Screen:** The app returns to the main screen with the camera icon, ready for the next receipt.

## 3. User Interface (UI) & User Experience (UX)

* **Language:** All text, buttons, and menus will be in Hebrew.
* **Main Screen:**
  * A large, prominent circular button with a camera icon (📷) created using `UIButton`.
  * The app name "קופת קבלות" in clear, bold Hebrew text at the top using `UILabel`.
  * No additional UI clutter. Minimalistic and intuitive design implemented using UIKit.
* **Confirmation Message:**
  * A subtle notification banner or popup message with Hebrew text (e.g., "הקובץ נשמר בהצלחה!") displayed using `UIAlertController` or a custom view.
  * Option to use custom view for animations or better UX.
* **Layout:** Use `Auto Layout` and `Stack Views` for responsive design across different iOS devices.

## 4. Google Drive Integration

* **Permissions:** The app will request access to the user's Google Drive using Google Sign-In SDK for iOS and Google Drive API.
* **Root Folder:** A folder named "ReceiptVault" (קופת קבלות) will be created in the user's Google Drive root folder.
* **Monthly Subfolders:** Inside the "ReceiptVault" folder, subfolders will be created for each month, formatted as "Month" (e.g., "June" becomes "יוני").
* **File Storage:**
  * **PDF Receipts:** Each captured receipt will be converted to PDF and stored in the corresponding monthly subfolder.
    * Use `PDFKit` or a similar library for PDF generation from images.
  * **Google Sheet Log:** A Google Sheet file (e.g., "יוני 2024 קבלות") will be created in each monthly subfolder, serving as the log for all the month's receipts.

## 5. PDF File Naming Convention

* Format: `שם בית העסק_תאריך` (Business Name_Date)
* Example: `סופר_15062024.pdf` (Supermarket_15062024.pdf)

## 6. Google Sheet Properties

* **Automatic Population:** The Google Sheet will be automatically populated using Google AI (Gemini 2.0 Flash) to extract information from the receipts.
* **Table Columns:**
  * **שם העסק (Business Name):** Text field.
  * **תאריך (Date):** Date field.
  * **כתובת (Address):** Text field.
  * **טלפון (Phone Number):** Text field.
  * **ח.פ (ID Number):** Text field.
  * **מה נרכש (Purchase Description):** Text field.
  * **מחיר סך הכל (Total Price):** Number/Currency field.
  * **מע״מ (VAT):** Number/Currency field.
  * **אמצעי תשלום (Payment Method):** Dropdown/Text field with options like "כרטיס אשראי" (Credit Card), "מזומן" (Cash), "העברה בנקאית" (Bank Transfer), etc. Use `UIPickerView` or a custom dropdown solution.
  * **ארבע ספרות אחרונות של כרטיס האשראי (Last 4 digits of Credit Card):** Number/Text field (Optional, should be masked if possible).
* **Format:** Column headers should be bold. Data should be aligned right-to-left (RTL) - `NSTextAlignment.right`.

## 7. Technical Specification

* **Programming Language:** Swift
* **Google API Integrations:**
  * **Google Drive API:** For file storage, folder creation, and authentication (Use Google Drive SDK for iOS).
  * **Google AI Gemini 2.0 Flash API:** For extracting data from receipts using OCR (Optical Character Recognition) and structured data parsing (Utilize Google AI API Client Library).
  * **Google Sheets API:** For creating and writing data into the monthly Google sheet (Utilize Google Sheets API Client Library for iOS).
* **Authentication:** Google Sign-In for iOS with OAuth 2.0.
* **Error Handling:** Implement robust error handling for network failures, API errors, camera access issues, and file upload issues. Display user-friendly messages in Hebrew. Use `NSError` and proper exception handling.
* **Data Storage:** The app primarily relies on Google Drive storage. Minimal data will be stored locally (e.g., for settings), using `UserDefaults` or Core Data (if needed later).
* **Libraries and Dependencies:**
  * `AVFoundation` for camera access.
  * `PDFKit` or a similar library for PDF generation.
  * `GoogleSignIn` for authentication.
  * `GoogleAPIClientForREST` for accessing the Google Drive API and Google Sheets API.
  * Google AI APIs - Client library for Google AI Platform.
  * Use `URLSession` for network communication.

## 8. Wireframes & User Flow (Simplified)

**(Wireframes will be simple, focusing on the main screen and camera access)**

* **Screen 1 (Main Screen):**
  * App title: "קופת קבלות" (Top center) using `UILabel`
  * Large circular button with camera icon (Center) using `UIButton`.
  * Clean background.
  * Use `Auto Layout` constraints for responsiveness.

* **Screen 2 (Camera):**
  * Camera view (full screen) using `AVCapturePreviewLayer`
  * Shutter button (large, circular) at the bottom center using `UIButton`.

* **Screen 3 (Confirmation):**
  * A brief banner or pop-up on success with "הקובץ נשמר בהצלחה!" using `UIAlertController` or a custom view.

**(User Flow Diagram - Text-based representation)**

1. User Launches App
2. Main Screen Displayed (Camera Icon)
3. User Clicks Camera Icon
4. Request Camera Permission (if not granted) - `AVCaptureDevice.requestAccess(for: .video)`.
5. Camera View Opens - `AVCaptureSession`.
6. User Takes Picture
7. Image Uploaded to Google Drive
8. Image Converted to PDF
9. Google AI Data Extraction
10. Google Sheet Updated
11. Success Notification Displayed
12. Return to Main Screen

## 9. Future Phase Considerations

* Integration with additional APIs (e.g., Israeli VAT calculator API).
* Receipt categorization (by category).
* Expense reporting and analysis.
* Support for multiple user accounts.
* Cloud backup to alternative services.
* Advanced data validation and correction functionality.

## 10. Requirements for Cursor.AI

* **Clarity:** Use clear, well-commented Swift code. Adhere to Apple's Swift API Design Guidelines.
* **Modularity:** Design modular components and use appropriate design patterns for future extensibility.
* **Efficiency:** Prioritize performance for a smooth user experience. Manage resources properly to avoid memory leaks and other issues.
* **Testing:** Thoroughly test the Google Drive integration, the AI API interaction, and the app's functionality on various iOS devices and simulator. Write unit and UI tests.
* **Hebrew Localization:** Ensure correct right-to-left formatting (RTL) in UI design and use appropriate `NSTextAlignment` in `UILabel` or similar elements.
* **Error Handling:** Implement robust error handling to gracefully manage any unforeseen issues. Catch exceptions and present user-friendly messages using `UIAlertController` or custom solutions.
* **UI/UX consistency:** Maintain UI consistency following Apple's Human Interface Guidelines
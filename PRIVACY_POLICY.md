# Privacy Policy — Muallim Carpets (MCQ)

**Last updated:** 3 October 2026
**Effective date:** 3 October 2026

> **Note for the developer:** replace every occurrence of `privacy@muallimcarpets.com` with your real
> contact email before publishing, and replace "Muallim Carpets" with the exact App Store name
> you submit.

---

## 1. Who we are

Muallim Carpets (the "MCQ" app) is a business management application used to manage carpet
inventory, sales, expenses, customers, suppliers and staff for a carpet retailer.

The operator of this application ("we", "us", "our") is **Muallim Carpets**.
If you have any questions about this policy or our handling of your data, contact us at
**privacy@muallimcarpets.com**.

## 2. Scope of this policy

This policy explains what information the MCQ app collects, why it collects it, how it is used
and stored, who it is shared with, and what choices you have.

The app is used by authorised staff members (administrators and managers) of the retail business.
Because the app is a record-keeping tool for a business, staff users may enter information about
**other people** — such as the business's customers and suppliers. This policy covers that
information as well, and explains the responsibilities of the staff member who enters it.

## 3. Information we collect

### 3.1 Account and login information (our staff users)

To create and maintain user accounts, we collect:

- **Full name**
- **Email address**
- **Phone number** (optional)
- **Password** — stored only as a one-way salted hash (bcrypt). We never see or store your
  plaintext password.
- **Role and assigned shop** (administrator or manager) — assigned by an administrator

There is **no public sign-up** in the app. Accounts are created by an administrator.

### 3.2 Business records entered into the app

Staff users enter business data in order to run the business. This may include personal
information about the business's customers and suppliers:

- **Customer records:** name, phone number, email address, postal address, city, notes, account
  balance and payment history
- **Supplier records:** name, phone number, email address, address, city, notes, balance and
  payment history
- **Sales and invoices:** invoice number, customer name, customer phone number, products sold,
  prices, discounts, totals, amounts paid, amounts due, profit, and a manual payment-method label
  (for example cash, bank transfer, EasyPaisa, JazzCash, or credit)
- **Expenses:** category, amount, description
- **Inventory:** product names, SKU, barcode, brand, stock quantities, and product/stock
  photographs taken or selected with the camera or photo library
- **Audit log:** which user performed which action, when, and the changes made

### 3.3 Device and technical information

To keep the app secure and to investigate problems, our server records:

- **IP address** of the request
- **Device platform** (Android or iOS)
- **App version**
- **Device user-agent** string
- **Timestamp** of actions and logins

### 3.4 Push notification token

If you enable notifications, the app registers a **Firebase Cloud Messaging (FCM) device token**
with our server so we can deliver alerts to your device. If you log out, the stored token is
removed from your account.

## 4. Information we do NOT collect

The app does **not** collect or store:

- Precise or coarse geolocation
- Health or fitness information
- Sensitive information (such as religious or ethnic origin)
- Contacts from your device
- Microphone or audio recordings
- Photos or videos except images you deliberately attach to a product or stock record
- Advertising data
- Payment card numbers, CVV, or bank account credentials — the app has no payment processing
  functionality and records only a manual payment-method label
- There is **no in-app purchase**, no subscription, and no digital content purchase in this app

## 5. How we use information

We use the information described above only for the following purposes:

1. **To operate the app** — creating accounts, signing you in, and managing your sessions.
2. **To run the business** — recording inventory, sales, invoices, expenses, customer and
   supplier accounts, and balances.
3. **To send receipts** — if staff enter a customer's phone number when creating a sale, the app
   can send that customer a PDF receipt through **WhatsApp (Meta WhatsApp Business Cloud API)**.
4. **To send business alerts** — low-stock warnings, new-sale alerts, expense alerts and other
   operational notifications, via push notification and an in-app notification inbox.
5. **To send reports** — daily summary reports (sales, expenses, stock) are emailed to the
   business owner's designated email address.
6. **Security and integrity** — maintaining an audit trail of who changed what and when, preventing
   fraud, rate-limiting and blocking abusive requests, and securing the service.
7. **Export** — generating reports and spreadsheet (CSV) exports of sales and audit data.

We do **not** use your data for advertising, and we do **not** sell or rent your personal
information to anyone.

## 6. Permissions the app requests

| Permission | Why it is needed |
|---|---|
| **Camera** | Scan product barcodes, and photograph products and stock items. |
| **Photo Library** | Select existing images of products or stock, and select an image to scan a barcode from. |
| **Notifications** | Deliver business alerts such as low stock, new sales and expense alerts. |

The app does not request location, contacts, microphone, or broad file-access permissions.

## 7. How information is shared

We share information only with the following service providers, and only as much as is necessary to
provide the app:

| Provider | Purpose | What is shared |
|---|---|---|
| **Firebase Cloud Messaging (Google)** | Push notifications | Device push token and delivery metadata |
| **MongoDB Atlas (MongoDB Inc.)** | Database hosting | All application data stored in our database |
| **Our web server (`carpetapi.interacts.uk`)** | App backend / API | All app data, over HTTPS (TLS) |
| **Meta Platforms (WhatsApp Business Cloud API)** | Sending sale receipts to customers | Customer name, phone number, and the receipt contents |
| **Gmail / SMTP mail service** | Sending daily business report emails | Report contents, including sales and stock figures and staff names |

We do **not** sell, rent, or trade your personal information. We do not share it for cross-app
advertising or tracking. We may disclose information if required by law, or as part of a merger or
sale of the business, in which case we will notify affected users.

## 8. Data retention

- Account and business records are retained for as long as the account remains active and as long
  as the business requires the records for accounting and legal purposes.
- Audit log entries are retained for the period required for security and legal compliance.
- Push notification tokens are removed from your account when you log out or disable
  notifications.
- Deleted records may remain in backups for a limited period before being overwritten.
- Where required by law (for example tax and accounting rules), records are retained for the
  mandatory period even after deletion from the app.

## 9. How we protect information

- All data is transmitted over **HTTPS (TLS)**.
- Passwords are hashed with **bcrypt** and are never stored or transmitted in plaintext.
- Authentication uses signed, time-limited **JWT** tokens.
- The server applies rate limiting, security headers, and role-based access control so that each
  staff member can only access the shops they are assigned to.
- Passwords, tokens, and database credentials are never exposed to the mobile app.

No system is 100% secure, but we use industry-standard practices to protect your data.

## 10. Your rights and choices

Depending on where you live, you may have rights to access, correct, export, or delete the
personal information we hold about you. Staff users can:

- **View and edit** their own name, email, phone number, and notification preference from the app's
  Profile / Settings screen.
- **Change their password** from the Settings screen.
- **Delete their own customer, supplier, and sales records** they created, where the business's
  retention rules allow.
- **Disable notifications** at any time from your device settings or the app's Settings screen.
- **Log out** at any time, which also removes the stored push notification token.

To request access to, correction of, or deletion of your personal information, or to object to a
particular use of it, email **privacy@muallimcarpets.com**. We will respond within a reasonable
time. If you are a customer or supplier of the business and want your records removed, you can ask
the business directly, because the business that entered your details is the party that controls
them.

**Children's privacy.** The app is a business tool and is not directed at children. We do not
knowingly collect personal information from anyone under the age of 16. If you believe a child has
provided us with personal information, contact us at **privacy@muallimcarpets.com** and we will
delete it.

## 11. International transfers

Our server and database providers may process data outside your country of residence. Where data is
transferred internationally, we use appropriate safeguards such as standard contractual clauses.

## 12. Changes to this policy

We may update this policy from time to time. When we make a material change, we will update the
"Last updated" date at the top of this page and, where appropriate, notify you inside the app
before the change takes effect.

## 13. Contact us

If you have questions, complaints, or requests regarding this policy or our privacy practices:

**Email:** privacy@muallimcarpets.com

---

## Appendix A — App Store Privacy Nutrition Label (App Store Connect answers)

Use these answers for **App Privacy** in App Store Connect.

**Data collected (linked to user identity):**

| Data type | Collected? | Purpose | Tracking? |
|---|---|---|---|
| Contact Info — Name | Yes | App Functionality | No |
| Contact Info — Email Address | Yes | App Functionality | No |
| Contact Info — Phone Number | Yes | App Functionality | No |
| Identifiers — User ID | Yes | App Functionality | No |
| Identifiers — Device ID (push token) | Yes | App Functionality | No |
| User Content — Photos or Videos (product photos) | Yes | App Functionality | No |
| Purchases — Purchase History (in-app business sales records only) | Yes | App Functionality | No |
| Usage Data — Product Interaction (in-app audit log) | Yes | App Functionality | No |
| Diagnostics — Other Diagnostic Data (IP, device platform, app version) | Yes | App Functionality | No |

**Data NOT collected** (leave unselected): Precise Location · Coarse Location · Health & Fitness ·
Financial Info (card numbers, bank account) · Sensitive Info · Contacts · Browsing History ·
Search History · User ID advertising · Advertising Data · Other Usage Data · Other Purpose Data.

**Tracking domain:** answer **"No"** — the app does not track users across apps or websites, does
not use IDFA/IDFV, and contains no advertising SDK.

**Third-party SDKs:** Firebase Core and Firebase Cloud Messaging only.

**Account deletion:** App Store Connect may ask whether the app supports account deletion. Note
that in this app, **accounts are created by an administrator** — there is no self-service deletion
screen. Answering is still required; explain that deletion is requested from the administrator, or
add an admin-initiated delete action if you want to be able to claim "yes".
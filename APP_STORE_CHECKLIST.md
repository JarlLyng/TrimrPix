# App Store Udgivelses Checkliste

## ✅ Hvad der allerede er på plads

### Projekt Konfiguration
- ✅ **App Version**: 1.0 (MARKETING_VERSION)
- ✅ **Build Number**: 1 (CURRENT_PROJECT_VERSION)
- ✅ **Bundle Identifier**: `com.iamjarl.trimrpix.TrimrPix`
- ✅ **App Display Name**: "TrimrPix - Modern image optimization tool"
- ✅ **App Category**: Graphics & Design (`public.app-category.graphics-design`)
- ✅ **App Icon**: Komplet icon set i Assets.xcassets  
  - **TestFlight/App Store:** 1024×1024-ikonet (`AppIcon~ios-marketing.png`) må **ikke** have alphakanal (transparens). Hvis ikonet vises som placeholder i TestFlight, flad ikonet i Preview (Baggrund → hvid) og eksporter som PNG uden transparens, erstat filen og byg igen.
- ✅ **Sandboxing**: Aktiveret (ENABLE_APP_SANDBOX = YES)
- ✅ **Hardened Runtime**: Aktiveret (ENABLE_HARDENED_RUNTIME = YES)
- ✅ **User Selected Files**: Konfigureret (readwrite)
- ✅ **macOS Deployment Target**: 15.2+

### Kode Kvalitet
- ✅ **Arkitektur**: MVVM med protocol-oriented design
- ✅ **Error Handling**: Centraliseret error handling
- ✅ **Logging**: Struktureret logging system
- ✅ **Dokumentation**: Omfattende dokumentation
- ✅ **Code Style**: Konsistent kodestil

### Funktioner
- ✅ **Image Compression**: JPEG, PNG, GIF, WebP, AVIF support
- ✅ **Drag & Drop**: Fungerer korrekt
- ✅ **Watch Folder**: Implementeret
- ✅ **Settings**: Persistent settings

---

## ❌ Hvad der mangler eller skal rettes

### 1. Code Signing Konfiguration ✅ KLAR

- **DEVELOPMENT_TEAM**: `KDWZ3WNLDK` (sat på projekt og TrimrPix-target)
- **CODE_SIGN_STYLE**: Automatic
- **TrimrPix-target**: Signing & Capabilities konfigureret
- **Test-targets**: Arver samme team (vigtigt for Xcode Cloud)

### 2. Entitlements Fil ✅ KLAR

`TrimrPix.entitlements` indeholder **kun**:
- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write`

**Vigtigt:** Inkluder **ikke** `com.apple.security.files.downloads.read-write` (hverken true eller false). Apple afviser ved 2.4.5(i) hvis den er med – fjern nøglen helt. User-selected er nok til filadgang via dialog og drag & drop.

### 3. Copyright Information ✅ KLAR

- `INFOPLIST_KEY_NSHumanReadableCopyright` = "Copyright © 2025 IAMJARL. All rights reserved."

### 4. App Store Connect Konfiguration (KRITISK)

**Hvad der skal gøres:**

1. **Opret App i App Store Connect:**
   - Log ind på [App Store Connect](https://appstoreconnect.apple.com)
   - Gå til "My Apps" → "+" → "New App"
   - Vælg platform: macOS
   - Navn: TrimrPix
   - Primært sprog: English (eller Dansk)
   - Bundle ID: `com.iamjarl.trimrpix.TrimrPix`
   - SKU: `trimrpix-001` (eller lignende unikt ID)

2. **App Information:**
   - **Name**: TrimrPix
   - **Subtitle**: Modern image optimization tool
   - **Category**: Graphics & Design
   - **Privacy Policy URL**: `https://trimrpix.iamjarl.com/privacy.html`
   - **Support URL**: `https://trimrpix.iamjarl.com/support.html`
   - **Marketing URL**: `https://trimrpix.iamjarl.com/`

3. **Pricing and Availability:**
   - Vælg pris (gratis eller betalt)
   - Vælg tilgængelige lande

4. **App Privacy:**
   - **Data Collection**: Nej (appen samler ikke data)
   - **Tracking**: Nej
   - **Privacy Policy**: Påkrævet (se nedenfor)

### 5. Privacy Policy (PÅKRÆVET)

**Status:** ✅ På plads på marketingsitet.

Privacy policy er på marketingsitet (GitHub Pages, CNAME `trimrpix.iamjarl.com`) som `privacy.html`.

**Brug disse URLs i App Store Connect:**
- **Privacy Policy URL**: `https://trimrpix.iamjarl.com/privacy.html`
- **Support URL**: `https://trimrpix.iamjarl.com/support.html`

Der er nu også et link til Privacy Policy i footeren på forsiden.

**Eksempel Privacy Policy:**
```
# Privacy Policy

TrimrPix does not collect, store, or transmit any personal data. 
All image processing is performed locally on your device.

## Data Collection
- No data is collected
- No analytics or tracking
- No network requests
- All processing is local

## File Access
TrimrPix only accesses files that you explicitly select or drop into the app.
Files are processed locally and never leave your device.

Last updated: [Date]
```

### 6. App Store Metadata (PÅKRÆVET)

**Hvad der skal uploades:**

1. **Screenshots:**
   - Minimum 1 screenshot (1280 x 800 pixels eller større)
   - Anbefalet: 3-5 screenshots
   - Du har allerede `Screenshots/app_screenshot.png`

2. **App Description:**
   - Kort beskrivelse (op til 4000 tegn)
   - Kan bruge tekst fra README.md

3. **Keywords:**
   - Op til 100 tegn
   - Eksempel: "image,optimization,compression,jpeg,png,webp,avif"

4. **Promotional Text:**
   - Op til 170 tegn (valgfrit)
   - Eksempel: "Optimize your images with high-quality compression. Support for JPEG, PNG, GIF, WebP, and AVIF."

5. **What's New:**
   - Release notes for første version
   - Eksempel: "Initial release of TrimrPix - a modern image optimization tool for macOS."

### 7. Build og Upload (KRITISK)

**Process:**

1. **Archive i Xcode:**
   ```bash
   # I Xcode:
   Product → Archive
   ```

2. **Distribute App:**
   - Vælg "App Store Connect"
   - Vælg "Upload"
   - Xcode vil automatisk:
     - Validere build
     - Upload til App Store Connect
     - Vente på processing (15-30 minutter)

3. **Eller via Command Line:**
   ```bash
   # Build archive
   xcodebuild -project TrimrPix.xcodeproj \
             -scheme TrimrPix \
             -configuration Release \
             -archivePath ./TrimrPix.xcarchive \
             archive
   
   # Export for App Store
   xcodebuild -exportArchive \
             -archivePath ./TrimrPix.xcarchive \
             -exportPath ./export \
             -exportOptionsPlist ExportOptions.plist
   ```

### 8. Notarization (AUTOMATISK)

**Godt nyt:**
- Notarization sker automatisk når du uploader til App Store Connect
- Du behøver ikke manuelt notarize

### 9. TestFlight (ANBEFALET)

**Hvad der skal gøres:**

1. **Upload build til TestFlight:**
   - Efter upload til App Store Connect
   - Gå til "TestFlight" tab
   - Tilføj interne testers (op til 100)
   - Test appen grundigt

2. **External Testing (valgfrit):**
   - Tilføj eksterne testers (op til 10.000)
   - Kræver App Review først

### 10. App Review Submission (KRITISK)

**Når alt er klar:**

1. **Gå til "App Store" tab i App Store Connect**
2. **Vælg build** du vil udgive
3. **Udfyld alle felter:**
   - Screenshots
   - Description
   - Keywords
   - Support URL
   - Privacy Policy URL
4. **Submit for Review**
5. **Vent på review** (typisk 24-48 timer)

---

## 📋 Pre-Submission Checklist

Før du submitter til App Review, tjek:

- [x] Code signing er konfigureret korrekt
- [x] Entitlements fil er korrekt konfigureret
- [x] Copyright information er tilføjet
- [x] App fungerer korrekt (testet grundigt)
- [x] Alle features virker som forventet
- [x] Ingen crashes eller memory leaks
- [x] Privacy policy URL er tilgængelig (`https://trimrpix.iamjarl.com/privacy.html`)
- [x] App Store metadata er udfyldt
- [x] Screenshots er uploadet
- [x] Support URL virker
- [x] Marketing URL virker (hvis tilføjet)
- [ ] Build er uploadet og processing er færdig (Xcode Cloud eller manuel Archive)
- [x] TestFlight testing er gennemført (anbefalet)

**Xcode Cloud:** Sørg for at workflow er knyttet til samme Apple Developer Team (KDWZ3WNLDK). Ved "Start Build" bygges og signes appen i skyen; vælg "Distribute App" → App Store Connect for upload.

---

## ✅ Guideline 2.4.5(i) – Unødvendigt indhold

For at undgå afvisning under **Performance - Unnecessary or extraneous content**:

- **Preview Content** er fjernet fra app-mappen. Mappen "Preview Content" (kun brugt af Xcode til SwiftUI-previews) blev inkluderet i bundlen via filsystem-synkronisering og har været årsag til afvisning. Den er nu slettet, så bundlen kun indeholder nødvendige ressourcer (Assets.car, AppIcon.icns).
- Sørg for at **ingen** dokumenter (README, PRIVACY, LICENSE), konfigfiler, eller kildekode fra projektroden kopieres med i app-targetet. Kun indholdet i mappen `TrimrPix/` (undtagen Preview Content) må inkluderes.
- Ved nye assets: tilføj kun billeder/lyde, der bruges i appen; fjern ubrugte fra Assets.xcassets.

---

## 🚨 Almindelige Fejl at Undgå

1. **Code Signing Fejl:**
   - Sørg for at DEVELOPMENT_TEAM er sat korrekt
   - Brug "Automatic" signing hvis muligt

2. **Entitlements Fejl:**
   - Sørg for at entitlements fil matcher appens funktionalitet
   - User-selected files entitlement er påkrævet for file access

3. **Privacy Policy:**
   - App Store afviser apps uden privacy policy URL
   - Selvom appen ikke samler data, skal URL være tilgængelig

4. **Screenshots:**
   - Minimum 1 screenshot påkrævet
   - Screenshots skal være i korrekt størrelse

5. **Build Processing:**
   - Vent på at build er færdig med processing før submission
   - Processing tager typisk 15-30 minutter

---

## 📞 Support

Hvis du støder på problemer:

- **Apple Developer Support**: [developer.apple.com/support](https://developer.apple.com/support)
- **App Store Review Guidelines**: [developer.apple.com/app-store/review/guidelines](https://developer.apple.com/app-store/review/guidelines)
- **App Store Connect Help**: [help.apple.com/app-store-connect](https://help.apple.com/app-store-connect)

---

**Opdateret**: 26. februar 2025

